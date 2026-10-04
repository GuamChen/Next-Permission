#import "SCPermissionTypes.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SCLocationAuthorizationScope) {
    SCLocationAuthorizationScopeNotDetermined,
    SCLocationAuthorizationScopeWhenInUse,
    SCLocationAuthorizationScopeAlways,
    SCLocationAuthorizationScopeDenied,
    SCLocationAuthorizationScopeRestricted,
    SCLocationAuthorizationScopeUnsupported
};

typedef NS_ENUM(NSInteger, SCLocationAccuracy) {
    SCLocationAccuracyNotApplicable,
    SCLocationAccuracyFull,
    SCLocationAccuracyReduced
};

@interface SCPermissionRequest : NSObject <NSCopying>
@property(nonatomic, readonly) SCPermissionType type;
@property(nonatomic, copy, readonly, nullable)
    NSString *temporaryFullAccuracyPurposeKey;
+ (instancetype)requestWithType:(SCPermissionType)type;
+ (instancetype)locationWhenInUseRequest;
+ (instancetype)locationAlwaysRequest;
+ (instancetype)temporaryFullAccuracyRequestWithPurposeKey:
    (NSString *)purposeKey;
+ (instancetype)microphoneRequest;
@end

@interface SCPermissionResult : NSObject
@property(nonatomic, readonly) SCPermissionRequest *request;
@property(nonatomic, readonly) SCPermissionState state;
@property(nonatomic, readonly) SCLocationAuthorizationScope locationScope;
@property(nonatomic, readonly) SCLocationAccuracy locationAccuracy;
@property(nonatomic, strong, readonly, nullable) NSError *error;
+ (instancetype)resultWithRequest:(SCPermissionRequest *)request
                            state:(SCPermissionState)state
                            error:(nullable NSError *)error;
+ (instancetype)locationResultWithRequest:(SCPermissionRequest *)request
                                    state:(SCPermissionState)state
                                    scope:(SCLocationAuthorizationScope)scope
                                 accuracy:(SCLocationAccuracy)accuracy
                                    error:(nullable NSError *)error;
@end

@interface SCPermissionConfigurationReport : NSObject
@property(nonatomic, readonly) NSArray<NSString *> *missingInfoPlistKeys;
@property(nonatomic, readonly) BOOL isValid;
+ (instancetype)reportForBundle:(NSBundle *)bundle
                       requests:(NSArray<SCPermissionRequest *> *)requests;
@end

@interface SCPermissionCore : NSObject
+ (instancetype)sharedCore;
- (SCPermissionResult *)currentResultForRequest:(SCPermissionRequest *)request;
- (SCPermissionConfigurationReport *)configurationReportForRequests:
    (NSArray<SCPermissionRequest *> *)requests;
- (void)request:(SCPermissionRequest *)request
     completion:(void (^)(SCPermissionResult *result))completion;
- (void)requestAll:(NSArray<SCPermissionRequest *> *)requests
        completion:(void (^)(NSArray<SCPermissionResult *> *results))completion;
 
@end

FOUNDATION_EXPORT NSString *
NSStringFromSCLocationAuthorizationScope(SCLocationAuthorizationScope scope);
FOUNDATION_EXPORT NSString *
NSStringFromSCLocationAccuracy(SCLocationAccuracy accuracy);
FOUNDATION_EXPORT NSErrorDomain const SCPermissionCoreErrorDomain;

NS_ASSUME_NONNULL_END
