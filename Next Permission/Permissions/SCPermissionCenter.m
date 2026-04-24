#import "SCPermissionCenter.h"

#import <AVFoundation/AVFoundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import <CoreLocation/CoreLocation.h>
#import <Network/Network.h>
#import <NetworkExtension/NetworkExtension.h>
#import <Photos/Photos.h>
#import <dns_sd.h>

static NSString * const SCPermissionErrorDomain = @"com.nextpermission.permission";
static NSInteger const SCPermissionErrorLocalNetworkBusy = 7001;
static NSInteger const SCPermissionErrorLocalNetworkTimeout = 7002;
static NSInteger const SCPermissionErrorLocalNetworkMissingConfig = 7003;

NSString *NSStringFromSCPermissionType(SCPermissionType type) {
    switch (type) {
        case SCPermissionTypePhotoRead: return @"photoRead";
        case SCPermissionTypePhotoAdd: return @"photoAdd";
        case SCPermissionTypeCamera: return @"camera";
        case SCPermissionTypeLocationWhenInUse: return @"locationWhenInUse";
        case SCPermissionTypeLocationAlways: return @"locationAlways";
        case SCPermissionTypeLocationFullAccuracy: return @"locationFullAccuracy";
        case SCPermissionTypeBluetooth: return @"bluetooth";
        case SCPermissionTypeLocalNetwork: return @"localNetwork";
    }
    return @"unknown";
}

NSString *NSStringFromSCPermissionState(SCPermissionState state) {
    switch (state) {
        case SCPermissionStateUnknown: return @"unknown";
        case SCPermissionStateNotDetermined: return @"notDetermined";
        case SCPermissionStateAuthorized: return @"authorized";
        case SCPermissionStateLimited: return @"limited";
        case SCPermissionStateDenied: return @"denied";
        case SCPermissionStateRestricted: return @"restricted";
        case SCPermissionStateUnsupported: return @"unsupported";
    }
    return @"unknown";
}

NSString *NSStringFromSCCapabilityType(SCCapabilityType type) {
    switch (type) {
        case SCCapabilityTypeFileExternalAccess: return @"fileExternalAccess";
        case SCCapabilityTypeWiFiState: return @"wifiState";
        case SCCapabilityTypeCellularState: return @"cellularState";
        case SCCapabilityTypeNetworkPath: return @"networkPath";
        case SCCapabilityTypeWiFiJoin: return @"wifiJoin";
    }
    return @"unknown";
}

NSString *NSStringFromSCCapabilityState(SCCapabilityState state) {
    switch (state) {
        case SCCapabilityStateUnavailable: return @"unavailable";
        case SCCapabilityStateAvailable: return @"available";
        case SCCapabilityStateNeedUserAction: return @"needUserAction";
        case SCCapabilityStateUnknown: return @"unknown";
    }
    return @"unknown";
}

NSNotificationName const SCNetworkPathCapabilityDidChangeNotification = @"SCNetworkPathCapabilityDidChangeNotification";

@protocol SCPermissionProvider <NSObject>
@property (nonatomic, assign, readonly) SCPermissionType type;
- (SCPermissionState)currentState;
- (BOOL)canRequest;
- (void)requestWithCompletion:(void(^)(SCPermissionState state, NSError * _Nullable error))completion;
@end

@interface SCBasePermissionProvider : NSObject <SCPermissionProvider>
@property (nonatomic, assign, readwrite) SCPermissionType type;
@end

@implementation SCBasePermissionProvider
- (SCPermissionState)currentState { return SCPermissionStateUnsupported; }
- (BOOL)canRequest { return [self currentState] == SCPermissionStateNotDetermined; }
- (void)requestWithCompletion:(void(^)(SCPermissionState state, NSError * _Nullable error))completion {
    if (completion) {
        completion([self currentState], nil);
    }
}
@end

@interface SCPhotoPermissionProvider : SCBasePermissionProvider
@end

@implementation SCPhotoPermissionProvider
- (SCPermissionState)currentState {
    if (self.type == SCPermissionTypePhotoAdd) {
        if (@available(iOS 14.0, *)) {
            return [self stateFromPhotoStatus:[PHPhotoLibrary authorizationStatusForAccessLevel:PHAccessLevelAddOnly]];
        }
        return [self stateFromLegacyStatus:[PHPhotoLibrary authorizationStatus]];
    }
    if (@available(iOS 14.0, *)) {
        return [self stateFromPhotoStatus:[PHPhotoLibrary authorizationStatusForAccessLevel:PHAccessLevelReadWrite]];
    }
    return [self stateFromLegacyStatus:[PHPhotoLibrary authorizationStatus]];
}

- (SCPermissionState)stateFromPhotoStatus:(PHAuthorizationStatus)status API_AVAILABLE(ios(14.0)) {
    switch (status) {
        case PHAuthorizationStatusNotDetermined: return SCPermissionStateNotDetermined;
        case PHAuthorizationStatusRestricted: return SCPermissionStateRestricted;
        case PHAuthorizationStatusDenied: return SCPermissionStateDenied;
        case PHAuthorizationStatusAuthorized: return SCPermissionStateAuthorized;
        case PHAuthorizationStatusLimited: return SCPermissionStateLimited;
    }
    return SCPermissionStateUnknown;
}

- (SCPermissionState)stateFromLegacyStatus:(PHAuthorizationStatus)status {
    switch (status) {
        case PHAuthorizationStatusNotDetermined: return SCPermissionStateNotDetermined;
        case PHAuthorizationStatusRestricted: return SCPermissionStateRestricted;
        case PHAuthorizationStatusDenied: return SCPermissionStateDenied;
        case PHAuthorizationStatusAuthorized: return SCPermissionStateAuthorized;
        case PHAuthorizationStatusLimited: return SCPermissionStateLimited;
    }
    return SCPermissionStateUnknown;
}

- (void)requestWithCompletion:(void(^)(SCPermissionState state, NSError * _Nullable error))completion {
    if (@available(iOS 14.0, *)) {
        PHAccessLevel accessLevel = self.type == SCPermissionTypePhotoAdd ? PHAccessLevelAddOnly : PHAccessLevelReadWrite;
        [PHPhotoLibrary requestAuthorizationForAccessLevel:accessLevel handler:^(PHAuthorizationStatus status) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) {
                    completion([self stateFromPhotoStatus:status], nil);
                }
            });
        }];
        return;
    }

    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion([self stateFromLegacyStatus:status], nil);
            }
        });
    }];
}
@end

@interface SCCameraPermissionProvider : SCBasePermissionProvider
@end

@implementation SCCameraPermissionProvider
- (SCPermissionState)currentState {
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    switch (status) {
        case AVAuthorizationStatusNotDetermined: return SCPermissionStateNotDetermined;
        case AVAuthorizationStatusRestricted: return SCPermissionStateRestricted;
        case AVAuthorizationStatusDenied: return SCPermissionStateDenied;
        case AVAuthorizationStatusAuthorized: return SCPermissionStateAuthorized;
    }
    return SCPermissionStateUnknown;
}

- (void)requestWithCompletion:(void(^)(SCPermissionState state, NSError * _Nullable error))completion {
    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(granted ? SCPermissionStateAuthorized : [self currentState], nil);
            }
        });
    }];
}
@end

@interface SCLocationPermissionProvider : SCBasePermissionProvider <CLLocationManagerDelegate>
@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, copy) void(^completion)(SCPermissionState state, NSError * _Nullable error);
@end

@implementation SCLocationPermissionProvider
- (instancetype)init {
    self = [super init];
    if (self) {
        _locationManager = [[CLLocationManager alloc] init];
        _locationManager.delegate = self;
    }
    return self;
}

- (SCPermissionState)currentState {
    if (self.type == SCPermissionTypeLocationFullAccuracy) {
        if (@available(iOS 14.0, *)) {
            CLAuthorizationStatus status = self.locationManager.authorizationStatus;
            if (status == kCLAuthorizationStatusAuthorizedAlways || status == kCLAuthorizationStatusAuthorizedWhenInUse) {
                return self.locationManager.accuracyAuthorization == CLAccuracyAuthorizationFullAccuracy ? SCPermissionStateAuthorized : SCPermissionStateLimited;
            }
            return [self stateFromAuthorizationStatus:status];
        }
        return SCPermissionStateUnsupported;
    }

    CLAuthorizationStatus status;
    if (@available(iOS 14.0, *)) {
        status = self.locationManager.authorizationStatus;
    } else {
        status = [CLLocationManager authorizationStatus];
    }
    if (self.type == SCPermissionTypeLocationAlways && status == kCLAuthorizationStatusAuthorizedWhenInUse) {
        return SCPermissionStateLimited;
    }
    return [self stateFromAuthorizationStatus:status];
}

- (SCPermissionState)stateFromAuthorizationStatus:(CLAuthorizationStatus)status {
    switch (status) {
        case kCLAuthorizationStatusNotDetermined: return SCPermissionStateNotDetermined;
        case kCLAuthorizationStatusRestricted: return SCPermissionStateRestricted;
        case kCLAuthorizationStatusDenied: return SCPermissionStateDenied;
        case kCLAuthorizationStatusAuthorizedWhenInUse: return SCPermissionStateAuthorized;
        case kCLAuthorizationStatusAuthorizedAlways: return SCPermissionStateAuthorized;
    }
    return SCPermissionStateUnknown;
}

- (void)requestWithCompletion:(void(^)(SCPermissionState state, NSError * _Nullable error))completion {
    self.completion = completion;
    if (self.type == SCPermissionTypeLocationAlways) {
        [self.locationManager requestAlwaysAuthorization];
        return;
    }
    if (self.type == SCPermissionTypeLocationFullAccuracy) {
        if (@available(iOS 14.0, *)) {
            if (self.locationManager.accuracyAuthorization == CLAccuracyAuthorizationReducedAccuracy) {
                [self.locationManager requestTemporaryFullAccuracyAuthorizationWithPurposeKey:@"CameraConnectionAccuracy" completion:^(NSError * _Nullable error) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (self.completion) {
                            self.completion([self currentState], error);
                            self.completion = nil;
                        }
                    });
                }];
                return;
            }
            if (self.completion) {
                self.completion([self currentState], nil);
                self.completion = nil;
            }
            return;
        }
        if (self.completion) {
            self.completion(SCPermissionStateUnsupported, nil);
            self.completion = nil;
        }
        return;
    }
    [self.locationManager requestWhenInUseAuthorization];
}

- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager API_AVAILABLE(ios(14.0)) {
    [self finishIfNeeded];
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    [self finishIfNeeded];
}

- (void)finishIfNeeded {
    if (!self.completion) {
        return;
    }
    SCPermissionState state = [self currentState];
    if (state == SCPermissionStateNotDetermined) {
        return;
    }
    void(^completion)(SCPermissionState state, NSError * _Nullable error) = self.completion;
    self.completion = nil;
    completion(state, nil);
}
@end

@interface SCBluetoothPermissionProvider : SCBasePermissionProvider <CBCentralManagerDelegate>
@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic, copy) void(^completion)(SCPermissionState state, NSError * _Nullable error);
@end

@implementation SCBluetoothPermissionProvider
- (instancetype)init {
    self = [super init];
    if (self) {
        _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil options:@{CBCentralManagerOptionShowPowerAlertKey: @NO}];
    }
    return self;
}

- (SCPermissionState)currentState {
    if (@available(iOS 13.0, *)) {
        switch (CBManager.authorization) {
            case CBManagerAuthorizationNotDetermined: return SCPermissionStateNotDetermined;
            case CBManagerAuthorizationRestricted: return SCPermissionStateRestricted;
            case CBManagerAuthorizationDenied: return SCPermissionStateDenied;
            case CBManagerAuthorizationAllowedAlways: return SCPermissionStateAuthorized;
        }
    }
    if (self.centralManager.state == CBManagerStateUnauthorized) {
        return SCPermissionStateDenied;
    }
    return SCPermissionStateAuthorized;
}

- (void)requestWithCompletion:(void(^)(SCPermissionState state, NSError * _Nullable error))completion {
    self.completion = completion;
    self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil options:@{CBCentralManagerOptionShowPowerAlertKey: @YES}];
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    if (!self.completion) {
        return;
    }
    SCPermissionState state = [self currentState];
    if (state == SCPermissionStateNotDetermined) {
        return;
    }
    void(^completion)(SCPermissionState state, NSError * _Nullable error) = self.completion;
    self.completion = nil;
    completion(state, nil);
}
@end

@interface SCLocalNetworkPermissionProvider : SCBasePermissionProvider
@property (nonatomic) nw_browser_t browser;
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) dispatch_source_t timeoutSource;
@property (nonatomic, copy) void(^completion)(SCPermissionState state, NSError * _Nullable error);
@property (nonatomic, assign) SCPermissionState cachedState;
@property (nonatomic, assign) BOOL completed;
@property (nonatomic, assign) BOOL requesting;
@property (nonatomic, strong, nullable) NSError *lastError;
@property (nonatomic, copy) NSString *lastDebugMessage;
@end

@implementation SCLocalNetworkPermissionProvider
- (instancetype)init {
    self = [super init];
    if (self) {
        _cachedState = SCPermissionStateNotDetermined;
        _queue = dispatch_queue_create("com.nextpermission.localnetwork", DISPATCH_QUEUE_SERIAL);
        _lastDebugMessage = @"idle";
    }
    return self;
}

- (SCPermissionState)currentState {
    if (@available(iOS 14.0, *)) {
        return self.cachedState;
    }
    return SCPermissionStateAuthorized;
}

- (void)requestWithCompletion:(void(^)(SCPermissionState state, NSError * _Nullable error))completion {
    if (@available(iOS 14.0, *)) {
        if (self.requesting) {
            NSError *busyError = [NSError errorWithDomain:SCPermissionErrorDomain
                                                     code:SCPermissionErrorLocalNetworkBusy
                                                 userInfo:@{NSLocalizedDescriptionKey: @"Local Network request is already running."}];
            if (completion) {
                completion(self.cachedState, busyError);
            }
            return;
        }
        if (self.browser) {
            nw_browser_cancel(self.browser);
            self.browser = nil;
        }
        self.requesting = YES;
        self.completion = completion;
        self.completed = NO;
        self.lastError = nil;
        self.lastDebugMessage = @"startingBonjourBrowse";
        self.cachedState = SCPermissionStateNotDetermined;
        nw_parameters_t parameters = nw_parameters_create();
        nw_browse_descriptor_t descriptor = nw_browse_descriptor_create_bonjour_service("_nextpermission._tcp", NULL);
        self.browser = nw_browser_create(descriptor, parameters);
        __weak typeof(self) weakSelf = self;
        nw_browser_set_state_changed_handler(self.browser, ^(nw_browser_state_t state, nw_error_t  _Nullable error) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            if (strongSelf.completed && state != nw_browser_state_cancelled) {
                return;
            }
            switch (state) {
                case nw_browser_state_ready:
                    strongSelf.lastDebugMessage = @"bonjourBrowseReady";
                    [strongSelf finishWithState:SCPermissionStateAuthorized error:nil];
                    break;
                case nw_browser_state_failed:
                    [strongSelf handleBrowserError:error fallbackMessage:@"bonjourBrowseFailed"];
                    break;
                case nw_browser_state_waiting:
                    [strongSelf updateWaitingStateWithError:error];
                    break;
                case nw_browser_state_cancelled:
                    strongSelf.lastDebugMessage = @"bonjourBrowseCancelled";
                    break;
                default:
                    strongSelf.lastDebugMessage = @"bonjourBrowsePreparing";
                    break;
            }
        });
        nw_browser_set_queue(self.browser, self.queue);
        nw_browser_start(self.browser);
        [self startTimeout];
        return;
    }
    if (completion) {
        completion(SCPermissionStateAuthorized, nil);
    }
}

- (void)startTimeout API_AVAILABLE(ios(14.0)) {
    self.timeoutSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.queue);
    dispatch_source_set_timer(self.timeoutSource, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(8.0 * NSEC_PER_SEC)), DISPATCH_TIME_FOREVER, (uint64_t)(0.1 * NSEC_PER_SEC));
    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(self.timeoutSource, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf.completed) {
            return;
        }
        NSError *timeoutError = [NSError errorWithDomain:SCPermissionErrorDomain
                                                    code:SCPermissionErrorLocalNetworkTimeout
                                                userInfo:@{NSLocalizedDescriptionKey: @"Timed out while waiting for the Local Network permission result."}];
        strongSelf.lastError = timeoutError;
        strongSelf.lastDebugMessage = @"timedOutWaitingForPromptResult";
        [strongSelf cancelRequestKeepingState:SCPermissionStateDenied error:timeoutError];
    });
    dispatch_resume(self.timeoutSource);
}

- (void)handleBrowserError:(nw_error_t)error fallbackMessage:(NSString *)fallbackMessage API_AVAILABLE(ios(14.0)) {
    NSError *nsError = error ? (__bridge_transfer NSError *)nw_error_copy_cf_error(error) : nil;
    SCPermissionState mappedState = [self permissionStateForLocalNetworkError:nsError];
    self.lastError = nsError;
    self.lastDebugMessage = [NSString stringWithFormat:@"%@ (%@)", fallbackMessage, [self debugDescriptionForError:nsError]];
    [self finishWithState:mappedState error:nsError];
}

- (void)updateWaitingStateWithError:(nw_error_t)error API_AVAILABLE(ios(14.0)) {
    NSError *nsError = error ? (__bridge_transfer NSError *)nw_error_copy_cf_error(error) : nil;
    self.lastError = nsError;
    SCPermissionState mappedState = [self permissionStateForLocalNetworkError:nsError];
    self.cachedState = mappedState;
    self.lastDebugMessage = [NSString stringWithFormat:@"bonjourBrowseWaiting (%@)", [self debugDescriptionForError:nsError]];
    if (mappedState == SCPermissionStateDenied) {
        [self finishWithState:SCPermissionStateDenied error:nsError];
    }
}

- (SCPermissionState)permissionStateForLocalNetworkError:(NSError *)error {
    if (!error) {
        return SCPermissionStateDenied;
    }
    if (error.code == kDNSServiceErr_PolicyDenied || error.code == -65570) {
        return SCPermissionStateDenied;
    }
    if ([error.domain isEqualToString:NSPOSIXErrorDomain]) {
        if (error.code == EACCES || error.code == EPERM) {
            return SCPermissionStateDenied;
        }
        if (error.code == ENETDOWN || error.code == ENETUNREACH || error.code == EHOSTUNREACH) {
            return SCPermissionStateNotDetermined;
        }
    }
    if ([error.domain isEqualToString:NSNetServicesErrorDomain]) {
        return SCPermissionStateDenied;
    }
    return SCPermissionStateDenied;
}

- (NSString *)debugDescriptionForError:(NSError *)error {
    if (!error) {
        return @"noError";
    }
    return [NSString stringWithFormat:@"%@/%ld %@", error.domain, (long)error.code, error.localizedDescription ?: @""];
}

- (void)cancelRequestKeepingState:(SCPermissionState)state error:(NSError * _Nullable)error {
    self.requesting = NO;
    self.cachedState = state;
    [self scheduleBrowserCancel];
    if (self.timeoutSource) {
        dispatch_source_cancel(self.timeoutSource);
        self.timeoutSource = nil;
    }
    if (!self.completion) {
        return;
    }
    void(^completion)(SCPermissionState state, NSError * _Nullable error) = self.completion;
    self.completion = nil;
    dispatch_async(dispatch_get_main_queue(), ^{
        completion(state, error);
    });
}

- (void)finishWithState:(SCPermissionState)state error:(NSError * _Nullable)error {
    self.completed = YES;
    self.requesting = NO;
    self.cachedState = state;
    self.lastError = error;
    [self scheduleBrowserCancel];
    if (self.timeoutSource) {
        dispatch_source_cancel(self.timeoutSource);
        self.timeoutSource = nil;
    }
    if (!self.completion) {
        return;
    }
    void(^completion)(SCPermissionState state, NSError * _Nullable error) = self.completion;
    self.completion = nil;
    dispatch_async(dispatch_get_main_queue(), ^{
        completion(state, error);
    });
}

- (void)scheduleBrowserCancel {
    nw_browser_t browser = self.browser;
    if (!browser) {
        return;
    }
    self.browser = nil;
    dispatch_async(self.queue, ^{
        nw_browser_cancel(browser);
    });
}
@end

@interface SCFileAccessCapabilityProvider ()
@property (nonatomic, assign, readwrite) SCCapabilityType type;
@property (nonatomic, strong, readwrite, nullable) NSURL *directoryURL;
@property (nonatomic, assign) BOOL accessing;
@end

@implementation SCFileAccessCapabilityProvider
static NSString * const SCFileAccessBookmarkDefaultsKey = @"SCFileAccessBookmarkDefaultsKey";

- (instancetype)init {
    self = [super init];
    if (self) {
        _type = SCCapabilityTypeFileExternalAccess;
        [self restorePersistedAccess];
    }
    return self;
}

- (SCCapabilityState)currentState {
    return self.directoryURL ? SCCapabilityStateAvailable : SCCapabilityStateNeedUserAction;
}

- (BOOL)restorePersistedAccess {
    NSData *bookmarkData = [NSUserDefaults.standardUserDefaults objectForKey:SCFileAccessBookmarkDefaultsKey];
    if (!bookmarkData) {
        self.directoryURL = nil;
        return NO;
    }
    BOOL stale = NO;
    NSError *error = nil;
    NSURL *url = [NSURL URLByResolvingBookmarkData:bookmarkData options:0 relativeToURL:nil bookmarkDataIsStale:&stale error:&error];
    if (!url || error) {
        [self clearPersistedAccess];
        return NO;
    }
    self.directoryURL = url;
    if (stale) {
        [self persistAccessToURL:url error:nil];
    }
    return YES;
}

- (BOOL)persistAccessToURL:(NSURL *)url error:(NSError * _Nullable __autoreleasing *)error {
    NSData *bookmarkData = [url bookmarkDataWithOptions:0 includingResourceValuesForKeys:nil relativeToURL:nil error:error];
    if (!bookmarkData) {
        return NO;
    }
    [NSUserDefaults.standardUserDefaults setObject:bookmarkData forKey:SCFileAccessBookmarkDefaultsKey];
    self.directoryURL = url;
    return YES;
}

- (void)clearPersistedAccess {
    if (self.accessing) {
        [self stopAccessing];
    }
    self.directoryURL = nil;
    [NSUserDefaults.standardUserDefaults removeObjectForKey:SCFileAccessBookmarkDefaultsKey];
}

- (BOOL)startAccessing {
    if (!self.directoryURL || self.accessing) {
        return self.accessing;
    }
    self.accessing = [self.directoryURL startAccessingSecurityScopedResource];
    return self.accessing;
}

- (void)stopAccessing {
    if (!self.directoryURL || !self.accessing) {
        return;
    }
    [self.directoryURL stopAccessingSecurityScopedResource];
    self.accessing = NO;
}
@end

@interface SCNetworkPathCapabilityProvider ()
@property (nonatomic, assign, readwrite) SCCapabilityType type;
@property (nonatomic, assign, readwrite, getter=isMonitoring) BOOL monitoring;
@property (nonatomic, assign, readwrite) BOOL reachable;
@property (nonatomic, assign, readwrite) BOOL usingWiFi;
@property (nonatomic, assign, readwrite) BOOL usingCellular;
@property (nonatomic, assign, readwrite) BOOL expensive;
@property (nonatomic, assign, readwrite) BOOL constrained;
@property (nonatomic) nw_path_monitor_t monitor;
@property (nonatomic, strong) dispatch_queue_t monitorQueue;
@end

@implementation SCNetworkPathCapabilityProvider
- (instancetype)init {
    self = [super init];
    if (self) {
        _type = SCCapabilityTypeNetworkPath;
        _monitorQueue = dispatch_queue_create("com.nextpermission.networkpath", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (SCCapabilityState)currentState {
    return self.reachable ? SCCapabilityStateAvailable : SCCapabilityStateUnavailable;
}

- (void)startMonitoring {
    if (self.monitoring) {
        return;
    }
    self.monitor = nw_path_monitor_create();
    __weak typeof(self) weakSelf = self;
    nw_path_monitor_set_update_handler(self.monitor, ^(nw_path_t  _Nonnull path) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        strongSelf.reachable = nw_path_get_status(path) == nw_path_status_satisfied;
        strongSelf.usingWiFi = nw_path_uses_interface_type(path, nw_interface_type_wifi);
        strongSelf.usingCellular = nw_path_uses_interface_type(path, nw_interface_type_cellular);
        strongSelf.expensive = nw_path_is_expensive(path);
        if (@available(iOS 13.0, *)) {
            strongSelf.constrained = nw_path_is_constrained(path);
        } else {
            strongSelf.constrained = NO;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [NSNotificationCenter.defaultCenter postNotificationName:SCNetworkPathCapabilityDidChangeNotification object:strongSelf];
        });
    });
    nw_path_monitor_set_queue(self.monitor, self.monitorQueue);
    nw_path_monitor_start(self.monitor);
    self.monitoring = YES;
}

- (void)stopMonitoring {
    if (!self.monitoring || !self.monitor) {
        return;
    }
    nw_path_monitor_cancel(self.monitor);
    self.monitor = nil;
    self.monitoring = NO;
}
@end

@interface SCWiFiJoinCapabilityProvider ()
@property (nonatomic, assign, readwrite) SCCapabilityType type;
@end

@implementation SCWiFiJoinCapabilityProvider
- (instancetype)init {
    self = [super init];
    if (self) {
        _type = SCCapabilityTypeWiFiJoin;
    }
    return self;
}

- (SCCapabilityState)currentState {
    return SCCapabilityStateNeedUserAction;
}

- (void)joinWiFiWithSSID:(NSString *)SSID passphrase:(NSString *)passphrase isWEP:(BOOL)isWEP completion:(void(^)(SCCapabilityState state, NSError * _Nullable error))completion {
    NEHotspotConfiguration *configuration = nil;
    if (passphrase.length > 0) {
        configuration = [[NEHotspotConfiguration alloc] initWithSSID:SSID passphrase:passphrase isWEP:isWEP];
    } else {
        configuration = [[NEHotspotConfiguration alloc] initWithSSID:SSID];
    }
    configuration.joinOnce = YES;
    [NEHotspotConfigurationManager.sharedManager applyConfiguration:configuration completionHandler:^(NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(error ? SCCapabilityStateNeedUserAction : SCCapabilityStateAvailable, error);
            }
        });
    }];
}
@end

@interface SCPermissionCenter ()
@property (nonatomic, strong) NSDictionary<NSNumber *, id<SCPermissionProvider>> *providers;
@property (nonatomic, strong) NSMutableArray<dispatch_block_t> *pendingRequests;
@property (nonatomic, assign) BOOL performingRequest;
@property (nonatomic, strong, readwrite) SCFileAccessCapabilityProvider *fileAccessProvider;
@property (nonatomic, strong, readwrite) SCNetworkPathCapabilityProvider *networkPathProvider;
@property (nonatomic, strong, readwrite) SCWiFiJoinCapabilityProvider *wifiJoinProvider;
@property (nonatomic, strong) SCLocalNetworkPermissionProvider *localNetworkProvider;
@end

@implementation SCPermissionCenter
+ (instancetype)sharedCenter {
    static SCPermissionCenter *center;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        center = [[SCPermissionCenter alloc] init];
    });
    return center;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _pendingRequests = [NSMutableArray array];
        _providers = [self buildProviders];
        _fileAccessProvider = [[SCFileAccessCapabilityProvider alloc] init];
        _networkPathProvider = [[SCNetworkPathCapabilityProvider alloc] init];
        _wifiJoinProvider = [[SCWiFiJoinCapabilityProvider alloc] init];
    }
    return self;
}

- (NSDictionary<NSNumber *, id<SCPermissionProvider>> *)buildProviders {
    NSMutableDictionary<NSNumber *, id<SCPermissionProvider>> *providers = [NSMutableDictionary dictionary];
    providers[@(SCPermissionTypePhotoRead)] = [self providerOfClass:SCPhotoPermissionProvider.class type:SCPermissionTypePhotoRead];
    providers[@(SCPermissionTypePhotoAdd)] = [self providerOfClass:SCPhotoPermissionProvider.class type:SCPermissionTypePhotoAdd];
    providers[@(SCPermissionTypeCamera)] = [self providerOfClass:SCCameraPermissionProvider.class type:SCPermissionTypeCamera];
    providers[@(SCPermissionTypeLocationWhenInUse)] = [self providerOfClass:SCLocationPermissionProvider.class type:SCPermissionTypeLocationWhenInUse];
    providers[@(SCPermissionTypeLocationAlways)] = [self providerOfClass:SCLocationPermissionProvider.class type:SCPermissionTypeLocationAlways];
    providers[@(SCPermissionTypeLocationFullAccuracy)] = [self providerOfClass:SCLocationPermissionProvider.class type:SCPermissionTypeLocationFullAccuracy];
    providers[@(SCPermissionTypeBluetooth)] = [self providerOfClass:SCBluetoothPermissionProvider.class type:SCPermissionTypeBluetooth];
    self.localNetworkProvider = (SCLocalNetworkPermissionProvider *)[self providerOfClass:SCLocalNetworkPermissionProvider.class type:SCPermissionTypeLocalNetwork];
    providers[@(SCPermissionTypeLocalNetwork)] = self.localNetworkProvider;
    return [providers copy];
}

- (SCBasePermissionProvider *)providerOfClass:(Class)providerClass type:(SCPermissionType)type {
    SCBasePermissionProvider *provider = [[providerClass alloc] init];
    provider.type = type;
    return provider;
}

- (SCPermissionState)stateForType:(SCPermissionType)type {
    id<SCPermissionProvider> provider = self.providers[@(type)];
    return provider ? [provider currentState] : SCPermissionStateUnsupported;
}

- (BOOL)isAuthorizedForType:(SCPermissionType)type {
    SCPermissionState state = [self stateForType:type];
    return state == SCPermissionStateAuthorized || state == SCPermissionStateLimited;
}

- (BOOL)isPermanentlyDeniedForType:(SCPermissionType)type {
    id<SCPermissionProvider> provider = self.providers[@(type)];
    if (!provider) {
        return NO;
    }
    SCPermissionState state = [provider currentState];
    return state == SCPermissionStateDenied && ![provider canRequest];
}

- (void)requestPermission:(SCPermissionType)type completion:(void(^)(SCPermissionState state))completion {
    id<SCPermissionProvider> provider = self.providers[@(type)];
    if (!provider) {
        if (completion) {
            completion(SCPermissionStateUnsupported);
        }
        return;
    }
    __weak typeof(self) weakSelf = self;
    dispatch_block_t requestBlock = ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [provider requestWithCompletion:^(SCPermissionState state, NSError * _Nullable error) {
            (void)error;
            if (completion) {
                completion(state);
            }
            strongSelf.performingRequest = NO;
            [strongSelf drainNextRequest];
        }];
    };
    [self.pendingRequests addObject:[requestBlock copy]];
    [self drainNextRequest];
}

- (void)requestPermissions:(NSArray<NSNumber *> *)types completion:(void(^)(NSDictionary<NSNumber *, NSNumber *> *results))completion {
    NSMutableDictionary<NSNumber *, NSNumber *> *results = [NSMutableDictionary dictionary];
    [self requestPermissionAtIndex:0 types:types results:results completion:completion];
}

- (void)requestPermissionAtIndex:(NSUInteger)index types:(NSArray<NSNumber *> *)types results:(NSMutableDictionary<NSNumber *, NSNumber *> *)results completion:(void(^)(NSDictionary<NSNumber *, NSNumber *> *results))completion {
    if (index >= types.count) {
        if (completion) {
            completion([results copy]);
        }
        return;
    }
    SCPermissionType type = types[index].integerValue;
    [self requestPermission:type completion:^(SCPermissionState state) {
        results[@(type)] = @(state);
        [self requestPermissionAtIndex:index + 1 types:types results:results completion:completion];
    }];
}

- (void)drainNextRequest {
    if (self.performingRequest || self.pendingRequests.count == 0) {
        return;
    }
    self.performingRequest = YES;
    dispatch_block_t block = self.pendingRequests.firstObject;
    [self.pendingRequests removeObjectAtIndex:0];
    block();
}

- (void)openAppSettings {
    NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
    if (!url) {
        return;
    }
    UIApplication *application = UIApplication.sharedApplication;
    if ([application canOpenURL:url]) {
        [application openURL:url options:@{} completionHandler:nil];
    }
}

- (void)openInAppPermissionGuideForType:(SCPermissionType)type from:(UIViewController *)viewController {
    NSString *appName = NSBundle.mainBundle.infoDictionary[@"CFBundleDisplayName"] ?: NSBundle.mainBundle.infoDictionary[@"CFBundleName"];
    NSString *message = [NSString stringWithFormat:@"请在“设置 -> %@”中开启 %@ 权限。", appName, NSStringFromSCPermissionType(type)];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"需要系统授权" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"去设置" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [self openAppSettings];
    }]];
    [viewController presentViewController:alert animated:YES completion:nil];
}

- (NSError *)lastLocalNetworkError {
    return self.localNetworkProvider.lastError;
}

- (NSString *)localNetworkDebugSummary {
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    [parts addObject:[NSString stringWithFormat:@"state=%@", NSStringFromSCPermissionState(self.localNetworkProvider.cachedState)]];
    [parts addObject:[NSString stringWithFormat:@"requesting=%@", self.localNetworkProvider.requesting ? @"YES" : @"NO"]];
    [parts addObject:[NSString stringWithFormat:@"completed=%@", self.localNetworkProvider.completed ? @"YES" : @"NO"]];
    [parts addObject:[NSString stringWithFormat:@"event=%@", self.localNetworkProvider.lastDebugMessage ?: @"unknown"]];
    if (!NSBundle.mainBundle.infoDictionary[@"NSLocalNetworkUsageDescription"]) {
        NSError *configError = [NSError errorWithDomain:SCPermissionErrorDomain
                                                   code:SCPermissionErrorLocalNetworkMissingConfig
                                               userInfo:@{NSLocalizedDescriptionKey: @"NSLocalNetworkUsageDescription is missing."}];
        self.localNetworkProvider.lastError = configError;
        [parts addObject:@"config=missing NSLocalNetworkUsageDescription"];
    }
    NSArray *bonjourServices = NSBundle.mainBundle.infoDictionary[@"NSBonjourServices"];
    if (bonjourServices.count == 0) {
        [parts addObject:@"config=missing NSBonjourServices"];
    }
    if (self.localNetworkProvider.lastError) {
        [parts addObject:[NSString stringWithFormat:@"error=%@", [self.localNetworkProvider debugDescriptionForError:self.localNetworkProvider.lastError]]];
    }
    return [parts componentsJoinedByString:@", "];
}
@end
