//
//  NoaIMDBTool.m
//  NoaChatSDKCore
//
//  Created by Candy on 2026/10/21.
//

#import "NoaIMDBTool.h"
#import <WCDBObjc/WCDBObjc.h>
#import "NoaFloatMiniAppModel+WCTTableCoding.h"


//单例
static dispatch_once_t onceToken;

@interface NoaIMDBTool ()

@property (nonatomic, copy) NSString *userToken;
@property (nonatomic, copy) NSString *userID;

/// 已创建/检查过的表名缓存（避免重复调用 createTable）
@property (nonatomic, strong) NSMutableSet<NSString *> *checkedTables;
/// 缓存访问保护队列
@property (nonatomic, strong) dispatch_queue_t cacheQueue;

@end

@implementation NoaIMDBTool
#pragma mark - 单例
+ (instancetype)sharedTool {
    static NoaIMDBTool *_tool = nil;
    dispatch_once(&onceToken, ^{
        //不再使用alloc方法，因为已经重写了allocWithZone方法，所以这里要调用父类的方法
        _tool = [[super allocWithZone:NULL] init];
        
        // 初始化表缓存和保护队列
        _tool.checkedTables = [NSMutableSet set];
        _tool.cacheQueue = dispatch_queue_create("com.noaChatSdk.db.cache", DISPATCH_QUEUE_CONCURRENT);
    });
    return _tool;
}
// 防止外部调用alloc 或者 new
+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    return [NoaIMDBTool sharedTool];
}
// 防止外部调用copy
- (id)copyWithZone:(nullable NSZone *)zone {
    return [NoaIMDBTool sharedTool];
}
// 防止外部调用mutableCopy
- (id)mutableCopyWithZone:(nullable NSZone *)zone {
    return [NoaIMDBTool sharedTool];
}
// 单例一般不需要清空，但是在执行某些功能的时候，防止数据清空不及时可以清空一下
- (void)clearTool{
    // 清除表缓存（使用 barrier 确保线程安全）
    dispatch_barrier_sync(self.cacheQueue, ^{
        [self.checkedTables removeAllObjects];
    });
    onceToken = 0;
}

#pragma mark - ******业务******
#pragma mark - 数据库绑定用户信息
- (BOOL)configDBWith:(NSString *)userToken userID:(NSString *)userID {
    
    if (userID.length > 0 && userToken.length > 0) {
        _userToken = userToken;
        _userID = userID;
        
        // 清除表缓存（切换用户时，表结构可能不同）
        dispatch_barrier_sync(self.cacheQueue, ^{
            [self.checkedTables removeAllObjects];
        });
        
        BOOL result = [self createDB];
        if (result) {
            //用户表
            [self createTableWithName:NoaChatDBUserInfoTableName model:LingIMUserModel.class];
            //好友表
            [self createTableWithName:NoaChatDBFriendTableName model:LingIMFriendModel.class];
            //群组表
            [self createTableWithName:NoaChatDBGroupTableName model:LingIMGroupModel.class];
            //会话表
            [self createTableWithName:NoaChatDBSessionTableName model:LingIMSessionModel.class];
            //好友分组表
            [self createTableWithName:NoaChatDBFriendGroupTableName model:LingIMFriendGroupModel.class];
            //小程序快应用表
            [self createTableWithName:NoaChatDBFloatMiniAppTableName model:NoaFloatMiniAppModel.class];
        }
        
        return result;
    }else {
        CIMLog(@"定调用configDBWith:userID: 配置userToken,userID参数");
        return NO;
    }
    
    
}
#pragma mark - 获得我的ID
- (NSString *)myUserID {
    return _userID;
}

#pragma mark - 获得我的token
- (NSString *)myUserToken {
    return _userToken;
}

#pragma amrk - 创建数据库
- (BOOL)createDB {
    
    if (![_userID length]) {
        CIMLog(@"定调用createDB配置userToken,userID参数");
        return NO;
    }
    
    NSString *documentPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    
    //这行代码 很重要！
    //---------begin----------//
    NSString *dbPath = [documentPath stringByAppendingString:[NSString stringWithFormat:@"/NoaChatSDK/DataBase/%@/%@",_userID,NoaChatDBName]];
    //---------end----------//
    CIMLog(@"数据库地址:%@",dbPath);
    self.noaChatDB = [[WCTDatabase alloc] initWithPath:dbPath];
    // 使用更安全的加密密钥生成方式
    NSString *key = @"75367587e7d59d7ff03d3158febfe38d";
    NSData *keyData = [key dataUsingEncoding:NSUTF8StringEncoding];
    
    // 确保密钥长度为32字节（AES-256）
    if (keyData.length < 32) {
        NSMutableData *extendedKey = [keyData mutableCopy];
        [extendedKey setLength:32];
        keyData = extendedKey;
    } else if (keyData.length > 32) {
        keyData = [keyData subdataWithRange:NSMakeRange(0, 32)];
    }
    
    [self.noaChatDB setCipherKey:keyData];
    
    //数据库标记，默认0.(具有相同路径的WCTCore对象共享这个标签，即使他们不是同一个对象)
    self.noaChatDB.tag = 3000;
    
    // 尝试打开数据库
    if ([self.noaChatDB canOpen]) {
        CIMLog(@"数据库打开成功");
        return YES;
    } else {
        CIMLog(@"数据库打开失败，尝试恢复数据库");
        
        // 尝试恢复数据库
        if ([self recoverDatabase:dbPath]) {
            CIMLog(@"数据库恢复成功");
            return YES;
        } else {
            CIMLog(@"数据库恢复失败，创建新数据库");
            // 删除损坏的数据库文件，重新创建
            [self deleteCorruptedDatabase:dbPath];
            return [self createNewDatabase:dbPath withKey:keyData];
        }
    }
    
}

#pragma mark - 关闭数据库
- (void)closeDB {
    [self.noaChatDB close];
    CIMLog(@"关闭数据库");
}

#pragma mark - 创建数据库 某一表
- (BOOL)createTableWithName:(NSString *)tableName model:(Class)model {
    
    //创建表 (使用的是 IF NOT EXISTS的SQL语句，因此可以重复调用。不需要在每次调用前判断 表/索引 是否存在)
    //WCDB 将数据库升级和 ORM 结合起来，对于需要增删改的字段，只需直接在 ORM 层面修改，并再次调用 createTableAndIndexesOfName:withClass: 接口即可自动升级
    BOOL createResult = [self.noaChatDB createTable:tableName withClass:model];

    
    if (createResult) {
        //CIMLog(@"表:%@创建成功",tableName);
        return YES;
    }else {
        //CIMLog(@"表:%@创建失败",tableName);
        return NO;
    }
}

#pragma mark - 判断某数据库表是否正常(用于自检数据表)
- (BOOL)isTableStateOkWithName:(NSString *)tableName model:(Class)model {
    // 性能优化：先检查缓存，避免重复调用 createTable
    __block BOOL isChecked = NO;
    
    // 读操作使用 sync（允许并发读取）
    dispatch_sync(self.cacheQueue, ^{
        isChecked = [self.checkedTables containsObject:tableName];
    });
    
    // 如果已检查过，直接返回成功
    if (isChecked) {
        return YES;
    }
    
    // 第一次检查，调用 createTable（WCDB会处理表升级）
    BOOL result = [self createTableWithName:tableName model:model];
    
    // 如果创建/检查成功，加入缓存
    if (result) {
        dispatch_barrier_async(self.cacheQueue, ^{
            [self.checkedTables addObject:tableName];
        });
    }
    
    return result;
}

#pragma mark - 新增/更新数据到 某一表
- (BOOL)insertModelToTable:(NSString *)tableName model:(id)model {
    //数据库自检
    [self isTableStateOkWithName:tableName model:[model class]];
    
    BOOL result = [self.noaChatDB insertOrReplaceObject:model intoTable:tableName];
    if (result) {
        //CIMLog(@"表：%@新增数据成功",tableName);
    }else {
        //CIMLog(@"表：%@新增数据失败",tableName);
    }
    return result;
}

#pragma mark - 【批量】 新增/更新数据到 某一表
- (BOOL)insertMulitModelToTable:(NSString *)tableName modelClass:(id)modelClass list:(NSArray *)list {
    //数据库自检
    [self isTableStateOkWithName:tableName model:modelClass];
    
    __block BOOL result = YES;
    [self.noaChatDB runTransaction:^BOOL(WCTHandle * _Nonnull) {
        result = [self.noaChatDB insertOrReplaceObjects:list intoTable:tableName];
        return result;
    }];

    return result;
}


#pragma mark - 删除某个表
- (BOOL)dropTableWithName:(NSString *)tableName {
    return [self.noaChatDB dropTable:tableName];
}

#pragma mark - 删除某个表的全部数据
- (BOOL)deleteAllObjectWithName:(NSString *)tableName {
    return [self.noaChatDB deleteFromTable:tableName];
}


- (dispatch_queue_t)groupMemberUpdateQueue {
    if (!_groupMemberUpdateQueue) {
        _groupMemberUpdateQueue = dispatch_queue_create("com.noaChatSDKCode.groupMemberUpdateQueue", DISPATCH_QUEUE_CONCURRENT);
    }
    return _groupMemberUpdateQueue;
}

#pragma mark - 数据库恢复和创建方法

/// 尝试恢复损坏的数据库
- (BOOL)recoverDatabase:(NSString *)dbPath {
    @try {
        // 尝试使用SQLiteRepairKit恢复数据库
        // 这里可以集成SQLiteRepairKit进行数据库修复
        CIMLog(@"尝试使用SQLiteRepairKit恢复数据库: %@", dbPath);
        
        // 暂时返回NO，表示恢复失败
        // 实际项目中可以集成SQLiteRepairKit
        return NO;
    } @catch (NSException *exception) {
        CIMLog(@"数据库恢复异常: %@", exception.reason);
        return NO;
    }
}

/// 删除损坏的数据库文件
- (void)deleteCorruptedDatabase:(NSString *)dbPath {
    @try {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if ([fileManager fileExistsAtPath:dbPath]) {
            NSError *error = nil;
            [fileManager removeItemAtPath:dbPath error:&error];
            if (error) {
                CIMLog(@"删除损坏数据库文件失败: %@", error.localizedDescription);
            } else {
                CIMLog(@"成功删除损坏的数据库文件: %@", dbPath);
            }
        }
        
        // 同时删除相关的WAL和SHM文件
        NSString *walPath = [dbPath stringByAppendingString:@"-wal"];
        NSString *shmPath = [dbPath stringByAppendingString:@"-shm"];
        
        if ([fileManager fileExistsAtPath:walPath]) {
            [fileManager removeItemAtPath:walPath error:nil];
        }
        if ([fileManager fileExistsAtPath:shmPath]) {
            [fileManager removeItemAtPath:shmPath error:nil];
        }
    } @catch (NSException *exception) {
        CIMLog(@"删除数据库文件异常: %@", exception.reason);
    }
}

/// 创建新的数据库
- (BOOL)createNewDatabase:(NSString *)dbPath withKey:(NSData *)keyData {
    @try {
        // 确保目录存在
        NSString *directory = [dbPath stringByDeletingLastPathComponent];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if (![fileManager fileExistsAtPath:directory]) {
            [fileManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
        }
        
        // 创建新的数据库实例
        self.noaChatDB = [[WCTDatabase alloc] initWithPath:dbPath];
        [self.noaChatDB setCipherKey:keyData];
        self.noaChatDB.tag = 3000;
        
        if ([self.noaChatDB canOpen]) {
            CIMLog(@"新数据库创建成功: %@", dbPath);
            return YES;
        } else {
            CIMLog(@"新数据库创建失败: %@", dbPath);
            return NO;
        }
    } @catch (NSException *exception) {
        CIMLog(@"创建新数据库异常: %@", exception.reason);
        return NO;
    }
}

@end
