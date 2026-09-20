#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "SCPermissionTypes.h"
#import "../Capabilities/SCCapabilityProviders.h"

NS_ASSUME_NONNULL_BEGIN

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
