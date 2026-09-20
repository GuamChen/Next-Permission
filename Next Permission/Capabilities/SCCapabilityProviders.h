#import <Foundation/Foundation.h>
#import "../Permissions/SCPermissionTypes.h"

NS_ASSUME_NONNULL_BEGIN

extern NSNotificationName const SCNetworkPathCapabilityDidChangeNotification;

@interface SCFileAccessCapabilityProvider : NSObject
@property (nonatomic, assign, readonly) SCCapabilityType type;
@property (nonatomic, strong, readonly, nullable) NSURL *directoryURL;
- (SCCapabilityState)currentState;
- (BOOL)restorePersistedAccess;
- (BOOL)persistAccessToURL:(NSURL *)url error:(NSError * _Nullable * _Nullable)error;
- (void)clearPersistedAccess;
- (BOOL)startAccessing;
- (void)stopAccessing;
@end

@interface SCNetworkPathCapabilityProvider : NSObject
@property (nonatomic, assign, readonly) SCCapabilityType type;
@property (nonatomic, assign, readonly, getter=isMonitoring) BOOL monitoring;
@property (nonatomic, assign, readonly) BOOL reachable;
@property (nonatomic, assign, readonly) BOOL usingWiFi;
@property (nonatomic, assign, readonly) BOOL usingCellular;
@property (nonatomic, assign, readonly) BOOL expensive;
@property (nonatomic, assign, readonly) BOOL constrained;
- (SCCapabilityState)currentState;
- (void)startMonitoring;
- (void)stopMonitoring;
@end

@interface SCWiFiJoinCapabilityProvider : NSObject
@property (nonatomic, assign, readonly) SCCapabilityType type;
- (SCCapabilityState)currentState;
- (void)joinWiFiWithSSID:(NSString *)SSID passphrase:(nullable NSString *)passphrase isWEP:(BOOL)isWEP completion:(void(^)(SCCapabilityState state, NSError * _Nullable error))completion;
@end

NS_ASSUME_NONNULL_END
