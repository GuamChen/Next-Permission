#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SCPermissionType) {
    SCPermissionTypePhotoRead = 0,
    SCPermissionTypePhotoAdd,
    SCPermissionTypeCamera,
    SCPermissionTypeLocationWhenInUse,
    SCPermissionTypeLocationAlways,
    SCPermissionTypeLocationFullAccuracy,
    SCPermissionTypeBluetooth,
    SCPermissionTypeLocalNetwork,
    SCPermissionTypeMicrophone
};

typedef NS_ENUM(NSInteger, SCPermissionState) {
    SCPermissionStateUnknown = 0,
    SCPermissionStateNotDetermined,
    SCPermissionStateAuthorized,
    SCPermissionStateLimited,
    SCPermissionStateDenied,
    SCPermissionStateRestricted,
    SCPermissionStateUnsupported
};

typedef NS_ENUM(NSInteger, SCCapabilityType) {
    SCCapabilityTypeFileExternalAccess = 0,
    SCCapabilityTypeWiFiState,
    SCCapabilityTypeCellularState,
    SCCapabilityTypeNetworkPath,
    SCCapabilityTypeWiFiJoin
};

typedef NS_ENUM(NSInteger, SCCapabilityState) {
    SCCapabilityStateUnavailable = 0,
    SCCapabilityStateAvailable,
    SCCapabilityStateNeedUserAction,
    SCCapabilityStateUnknown
};

FOUNDATION_EXPORT NSString *NSStringFromSCPermissionType(SCPermissionType type);
FOUNDATION_EXPORT NSString *NSStringFromSCPermissionState(SCPermissionState state);
FOUNDATION_EXPORT NSString *NSStringFromSCCapabilityType(SCCapabilityType type);
FOUNDATION_EXPORT NSString *NSStringFromSCCapabilityState(SCCapabilityState state);

NS_ASSUME_NONNULL_END
