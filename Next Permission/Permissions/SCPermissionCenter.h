#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "SCPermissionTypes.h"

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
- (void)joinWiFiWithSSID:(NSString *)SSID
              passphrase:(nullable NSString *)passphrase
                   isWEP:(BOOL)isWEP
              completion:(void(^)(SCCapabilityState state, NSError * _Nullable error))completion;

@end

@interface SCPermissionCenter : NSObject

+ (instancetype)sharedCenter;

- (SCPermissionState)stateForType:(SCPermissionType)type;
- (BOOL)isAuthorizedForType:(SCPermissionType)type;
- (BOOL)isPermanentlyDeniedForType:(SCPermissionType)type;

- (void)requestPermission:(SCPermissionType)type
               completion:(void(^)(SCPermissionState state))completion;

- (void)requestPermissions:(NSArray<NSNumber *> *)types
                completion:(void(^)(NSDictionary<NSNumber *, NSNumber *> *results))completion;

- (void)openAppSettings;
- (void)openInAppPermissionGuideForType:(SCPermissionType)type
                                   from:(UIViewController *)viewController;

- (nullable NSError *)lastLocalNetworkError;
- (NSString *)localNetworkDebugSummary;

@property (nonatomic, strong, readonly) SCFileAccessCapabilityProvider *fileAccessProvider;
@property (nonatomic, strong, readonly) SCNetworkPathCapabilityProvider *networkPathProvider;
@property (nonatomic, strong, readonly) SCWiFiJoinCapabilityProvider *wifiJoinProvider;

@end

NS_ASSUME_NONNULL_END
