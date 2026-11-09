#import <Foundation/Foundation.h>

@interface LocalDatabaseStub : NSObject
@property BOOL succeeds;
@property NSInteger opens;
@property NSInteger closes;
@property NSString *uid;
@property NSObject *noaChatDB;
- (BOOL)openLocalSnapshotForUserID:(NSString *)uid;
- (void)closeLocalSnapshot;
@end
@implementation LocalDatabaseStub
- (BOOL)openLocalSnapshotForUserID:(NSString *)uid { self.opens++; self.uid = uid; self.noaChatDB = [NSObject new]; return self.succeeds; }
- (void)closeLocalSnapshot { self.closes++; self.uid = nil; }
@end
static LocalDatabaseStub *database;
#define DBTOOL database
@interface LocalManager : NSObject
@property NSString *userID;
@property NSString *userToken;
- (BOOL)readLocalUserDatabase:(NSString *)uid token:(NSString *)token reader:(void (^)(BOOL))reader;
@end
@implementation LocalManager
#include "LocalDatabase.inc"
@end

int main(void) {
    @autoreleasepool {
        database = [LocalDatabaseStub new]; database.succeeds = YES;
        LocalManager *sdk = [LocalManager new];
        __block NSInteger reads = 0;
        BOOL result = [sdk readLocalUserDatabase:@"A" token:@"fixture" reader:^(BOOL hasCache){
            reads++;
            NSCAssert([sdk.userID isEqualToString:@"A"] && sdk.userToken.length == 0, @"local read has UID but never grants token/auth");
            NSCAssert([database.uid isEqualToString:@"A"], @"correct local database");
        }];
        NSCAssert(result && reads == 1 && database.closes == 1 && sdk.userID == nil, @"read closes temporary database and identity");
        sdk.userID = @"B"; sdk.userToken = @"active";
        NSCAssert(![sdk readLocalUserDatabase:@"A" token:@"fixture" reader:^(BOOL hasCache){ reads++; }], @"active account cannot be replaced");
        NSCAssert(database.opens == 1 && database.closes == 1 && [sdk.userID isEqualToString:@"B"], @"active database untouched");
        sdk.userID = nil; sdk.userToken = nil; database.succeeds = NO;
        NSCAssert(![sdk readLocalUserDatabase:@"A" token:@"fixture" reader:^(BOOL hasCache){ reads++; }], @"open failure surfaced");
        NSCAssert(reads == 1 && sdk.userID == nil && database.closes == 2, @"failed read cleans up");
        database.succeeds = YES;
        @try { [sdk readLocalUserDatabase:@"A" token:@"fixture" reader:^(BOOL hasCache){ @throw [NSException exceptionWithName:@"fixture" reason:nil userInfo:nil]; }]; }
        @catch (NSException *e) { }
        NSCAssert(sdk.userID == nil && database.closes == 3, @"reader exception cleans up");
        NSCAssert(![sdk readLocalUserDatabase:@"" token:@"fixture" reader:^(BOOL hasCache){}] && database.opens == 3, @"invalid identity does not open database");
        puts("Local conversation database checks passed (5 scenarios; network APIs unavailable)");
    }
}
