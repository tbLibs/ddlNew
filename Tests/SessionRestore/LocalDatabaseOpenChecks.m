#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>

static NSString *fixtureRoot;
static NSArray *SnapshotSearchPath(NSSearchPathDirectory directory, NSSearchPathDomainMask domain, BOOL expand) { return @[fixtureRoot]; }
#define NSSearchPathForDirectoriesInDomains SnapshotSearchPath
#define CIMLog(...)
static NSString *const NoaChatDBName = @"NoaChatDB_V1.sqlite";
static BOOL allowsOpen = YES;
@interface WCTDatabase : NSObject
@property NSInteger tag;
- (instancetype)initWithPath:(NSString *)path;
- (void)setCipherKey:(NSData *)key;
- (BOOL)canOpen;
- (void)close;
@end
@implementation WCTDatabase
- (instancetype)initWithPath:(NSString *)path { return [super init]; }
- (void)setCipherKey:(NSData *)key {}
- (BOOL)canOpen { return allowsOpen; }
- (void)close {}
@end
@interface SnapshotDB : NSObject
@property NSString *userID;
@property NSString *userToken;
@property BOOL readingLocalSnapshot;
@property WCTDatabase *noaChatDB;
@property NSMutableSet *checkedTables;
@property dispatch_queue_t cacheQueue;
@property NSInteger tableCreates;
- (BOOL)openLocalSnapshotForUserID:(NSString *)uid;
- (void)closeLocalSnapshot;
- (void)closeDB;
- (BOOL)createTableWithName:(NSString *)name model:(Class)model;
- (BOOL)isTableStateOkWithName:(NSString *)name model:(Class)model;
@end
@implementation SnapshotDB
#include "SnapshotOpen.inc"
- (void)closeDB { [self.noaChatDB close]; }
- (BOOL)createTableWithName:(NSString *)name model:(Class)model { self.tableCreates++; return YES; }
@end
int main(void) {
    @autoreleasepool {
        fixtureRoot = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
        NSString *directory = [fixtureRoot stringByAppendingPathComponent:@"NoaChatSDK/DataBase/A"];
        NSFileManager *fm = NSFileManager.defaultManager;
        [fm createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
        NSString *path = [directory stringByAppendingPathComponent:NoaChatDBName];
        NSData *bytes = [@"existing chat history" dataUsingEncoding:NSUTF8StringEncoding];
        for (NSString *suffix in @[@"", @"-wal", @"-shm"]) [bytes writeToFile:[path stringByAppendingString:suffix] atomically:YES];
        SnapshotDB *db = [SnapshotDB new];
        db.checkedTables = [NSMutableSet new]; db.cacheQueue = dispatch_queue_create("fixture", DISPATCH_QUEUE_CONCURRENT);
        allowsOpen = NO;
        NSCAssert(![db openLocalSnapshotForUserID:@"A"], @"open error must propagate");
        [db closeLocalSnapshot];
        for (NSString *suffix in @[@"", @"-wal", @"-shm"]) NSCAssert([[NSData dataWithContentsOfFile:[path stringByAppendingString:suffix]] isEqual:bytes], @"open failure preserves database, WAL and SHM bytes");
        NSCAssert(db.userID == nil && db.userToken == nil && db.noaChatDB == nil && !db.readingLocalSnapshot, @"cleanup releases all temporary state");
        allowsOpen = YES;
        NSCAssert([db openLocalSnapshotForUserID:@"A"], @"existing database opens");
        [db isTableStateOkWithName:@"missing" model:NSObject.class];
        NSCAssert(db.tableCreates == 0, @"snapshot preview never creates or migrates tables");
        [db closeLocalSnapshot];
        NSCAssert([db openLocalSnapshotForUserID:@"no-cache"] && db.noaChatDB == nil, @"missing cache is an empty snapshot");
        NSCAssert(![fm fileExistsAtPath:[fixtureRoot stringByAppendingPathComponent:@"NoaChatSDK/DataBase/no-cache"]], @"missing cache is not created");
        [db closeLocalSnapshot];
        [fm removeItemAtPath:fixtureRoot error:nil];
        puts("Production local database open checks passed (failure preserves DB/WAL/SHM; no table writes; missing cache stays absent)");
    }
}
