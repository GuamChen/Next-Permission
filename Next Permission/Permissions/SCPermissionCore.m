#import "SCPermissionCore.h"
#import "SCPermissionCenter.h"
#import <CoreLocation/CoreLocation.h>

NSErrorDomain const SCPermissionCoreErrorDomain = @"com.nextpermission.core";

typedef NS_ENUM(NSInteger, SCPermissionCoreErrorCode) {
    SCPermissionCoreErrorConfiguration = 1,
    SCPermissionCoreErrorLocationRequiresAuthorization = 2
};

NSString *NSStringFromSCLocationAuthorizationScope(SCLocationAuthorizationScope scope) {
    switch (scope) {
        case SCLocationAuthorizationScopeNotDetermined: return @"notDetermined";
        case SCLocationAuthorizationScopeWhenInUse: return @"whenInUse";
        case SCLocationAuthorizationScopeAlways: return @"always";
        case SCLocationAuthorizationScopeDenied: return @"denied";
        case SCLocationAuthorizationScopeRestricted: return @"restricted";
        case SCLocationAuthorizationScopeUnsupported: return @"unsupported";
    }
}

NSString *NSStringFromSCLocationAccuracy(SCLocationAccuracy accuracy) {
    switch (accuracy) {
        case SCLocationAccuracyNotApplicable: return @"notApplicable";
        case SCLocationAccuracyFull: return @"full";
        case SCLocationAccuracyReduced: return @"reduced";
    }
}

@implementation SCPermissionRequest
+ (instancetype)requestWithType:(SCPermissionType)type {
    SCPermissionRequest *request = [[self alloc] init];
    request->_type = type;
    return request;
}
+ (instancetype)locationWhenInUseRequest { return [self requestWithType:SCPermissionTypeLocationWhenInUse]; }
+ (instancetype)locationAlwaysRequest { return [self requestWithType:SCPermissionTypeLocationAlways]; }
+ (instancetype)microphoneRequest { return [self requestWithType:SCPermissionTypeMicrophone]; }
+ (instancetype)temporaryFullAccuracyRequestWithPurposeKey:(NSString *)purposeKey {
    SCPermissionRequest *request = [self requestWithType:SCPermissionTypeLocationFullAccuracy];
    request->_temporaryFullAccuracyPurposeKey = [purposeKey copy];
    return request;
}
- (id)copyWithZone:(NSZone *)zone { return self; }
@end

@interface SCPermissionResult ()
- (instancetype)initWithRequest:(SCPermissionRequest *)request state:(SCPermissionState)state scope:(SCLocationAuthorizationScope)scope accuracy:(SCLocationAccuracy)accuracy error:(NSError *)error;
@end

@implementation SCPermissionResult
- (instancetype)initWithRequest:(SCPermissionRequest *)request state:(SCPermissionState)state scope:(SCLocationAuthorizationScope)scope accuracy:(SCLocationAccuracy)accuracy error:(NSError *)error {
    self = [super init];
    if (self) { _request = request; _state = state; _locationScope = scope; _locationAccuracy = accuracy; _error = error; }
    return self;
}
+ (instancetype)resultWithRequest:(SCPermissionRequest *)request state:(SCPermissionState)state error:(NSError *)error {
    return [[self alloc] initWithRequest:request state:state scope:SCLocationAuthorizationScopeUnsupported accuracy:SCLocationAccuracyNotApplicable error:error];
}
+ (instancetype)locationResultWithRequest:(SCPermissionRequest *)request state:(SCPermissionState)state scope:(SCLocationAuthorizationScope)scope accuracy:(SCLocationAccuracy)accuracy error:(NSError *)error {
    return [[self alloc] initWithRequest:request state:state scope:scope accuracy:accuracy error:error];
}
@end

@implementation SCPermissionConfigurationReport
+ (instancetype)reportForBundle:(NSBundle *)bundle requests:(NSArray<SCPermissionRequest *> *)requests {
    NSMutableOrderedSet<NSString *> *missing = [NSMutableOrderedSet orderedSet];
    NSDictionary *info = bundle.infoDictionary ?: @{};
    for (SCPermissionRequest *request in requests) {
        NSString *key = nil;
        switch (request.type) {
            case SCPermissionTypeCamera: key = @"NSCameraUsageDescription"; break;
            case SCPermissionTypeMicrophone: key = @"NSMicrophoneUsageDescription"; break;
            case SCPermissionTypePhotoRead: key = @"NSPhotoLibraryUsageDescription"; break;
            case SCPermissionTypePhotoAdd: key = @"NSPhotoLibraryAddUsageDescription"; break;
            case SCPermissionTypeBluetooth: key = @"NSBluetoothAlwaysUsageDescription"; break;
            case SCPermissionTypeLocationWhenInUse: key = @"NSLocationWhenInUseUsageDescription"; break;
            case SCPermissionTypeLocationAlways: key = @"NSLocationAlwaysAndWhenInUseUsageDescription"; break;
            case SCPermissionTypeLocalNetwork:
                key = @"NSLocalNetworkUsageDescription";
                if (![info[@"NSBonjourServices"] isKindOfClass:NSArray.class] || [info[@"NSBonjourServices"] count] == 0) [missing addObject:@"NSBonjourServices"];
                break;
            case SCPermissionTypeLocationFullAccuracy: {
                NSString *purpose = request.temporaryFullAccuracyPurposeKey;
                NSDictionary *purposes = info[@"NSLocationTemporaryUsageDescriptionDictionary"];
                if (purpose.length == 0 || ![purposes[purpose] isKindOfClass:NSString.class] || [purposes[purpose] length] == 0) [missing addObject:@"NSLocationTemporaryUsageDescriptionDictionary.<purposeKey>"];
                break;
            }
        }
        if (key && ![info[key] isKindOfClass:NSString.class]) [missing addObject:key];
    }
    SCPermissionConfigurationReport *report = [[self alloc] init];
    report->_missingInfoPlistKeys = missing.array;
    report->_isValid = missing.count == 0;
    return report;
}
@end

@interface SCLocationRequestOperation : NSObject <CLLocationManagerDelegate>
@property (nonatomic, strong) CLLocationManager *manager;
@property (nonatomic, strong) SCPermissionRequest *request;
@property (nonatomic, copy) void (^completion)(SCPermissionResult *result);
@end

@implementation SCLocationRequestOperation
- (instancetype)initWithRequest:(SCPermissionRequest *)request completion:(void (^)(SCPermissionResult *))completion {
    self = [super init];
    if (self) { _request = request; _completion = completion; _manager = [[CLLocationManager alloc] init]; _manager.delegate = self; }
    return self;
}
- (SCLocationAuthorizationScope)scope {
    switch (self.manager.authorizationStatus) {
        case kCLAuthorizationStatusNotDetermined: return SCLocationAuthorizationScopeNotDetermined;
        case kCLAuthorizationStatusAuthorizedWhenInUse: return SCLocationAuthorizationScopeWhenInUse;
        case kCLAuthorizationStatusAuthorizedAlways: return SCLocationAuthorizationScopeAlways;
        case kCLAuthorizationStatusDenied: return SCLocationAuthorizationScopeDenied;
        case kCLAuthorizationStatusRestricted: return SCLocationAuthorizationScopeRestricted;
    }
}
- (SCLocationAccuracy)accuracy {
    return self.manager.accuracyAuthorization == CLAccuracyAuthorizationFullAccuracy ? SCLocationAccuracyFull : SCLocationAccuracyReduced;
}
- (SCPermissionState)stateForScope:(SCLocationAuthorizationScope)scope {
    switch (scope) {
        case SCLocationAuthorizationScopeNotDetermined: return SCPermissionStateNotDetermined;
        case SCLocationAuthorizationScopeDenied: return SCPermissionStateDenied;
        case SCLocationAuthorizationScopeRestricted: return SCPermissionStateRestricted;
        case SCLocationAuthorizationScopeUnsupported: return SCPermissionStateUnsupported;
        default: return SCPermissionStateAuthorized;
    }
}
- (void)start {
    SCLocationAuthorizationScope scope = self.scope;
    if (self.request.type == SCPermissionTypeLocationFullAccuracy) {
        if (scope != SCLocationAuthorizationScopeWhenInUse && scope != SCLocationAuthorizationScopeAlways) {
            NSError *error = [NSError errorWithDomain:SCPermissionCoreErrorDomain code:SCPermissionCoreErrorLocationRequiresAuthorization userInfo:@{NSLocalizedDescriptionKey: @"Temporary full accuracy requires location authorization."}];
            [self finishWithError:error]; return;
        }
        if (self.accuracy == SCLocationAccuracyFull) { [self finishWithError:nil]; return; }
        [self.manager requestTemporaryFullAccuracyAuthorizationWithPurposeKey:self.request.temporaryFullAccuracyPurposeKey completion:^(NSError *error) { [self finishWithError:error]; }];
    } else if (scope == SCLocationAuthorizationScopeNotDetermined) {
        self.request.type == SCPermissionTypeLocationAlways ? [self.manager requestAlwaysAuthorization] : [self.manager requestWhenInUseAuthorization];
    } else { [self finishWithError:nil]; }
}
- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager { if (self.scope != SCLocationAuthorizationScopeNotDetermined) [self finishWithError:nil]; }
- (void)finishWithError:(NSError *)error {
    void (^completion)(SCPermissionResult *) = self.completion; if (!completion) return; self.completion = nil;
    SCLocationAuthorizationScope scope = self.scope;
    completion([SCPermissionResult locationResultWithRequest:self.request state:[self stateForScope:scope] scope:scope accuracy:self.accuracy error:error]);
}
@end

@interface SCPermissionCore ()
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableArray<void (^)(SCPermissionResult *)> *> *waiters;
@property (nonatomic, strong) NSMutableArray<SCPermissionRequest *> *pending;
@property (nonatomic, strong) NSMutableSet<SCLocationRequestOperation *> *locationOperations;
@property (nonatomic) BOOL requesting;
@end

@implementation SCPermissionCore
+ (instancetype)sharedCore { static SCPermissionCore *core; static dispatch_once_t once; dispatch_once(&once, ^{ core = [[self alloc] init]; }); return core; }
- (instancetype)init { self = [super init]; if (self) { _waiters = [NSMutableDictionary dictionary]; _pending = [NSMutableArray array]; _locationOperations = [NSMutableSet set]; } return self; }
- (NSString *)keyForRequest:(SCPermissionRequest *)request { return [NSString stringWithFormat:@"%ld:%@", (long)request.type, request.temporaryFullAccuracyPurposeKey ?: @""]; }
- (SCPermissionConfigurationReport *)configurationReportForRequests:(NSArray<SCPermissionRequest *> *)requests { return [SCPermissionConfigurationReport reportForBundle:NSBundle.mainBundle requests:requests]; }
- (SCPermissionResult *)currentResultForRequest:(SCPermissionRequest *)request {
    if (request.type == SCPermissionTypeLocationWhenInUse || request.type == SCPermissionTypeLocationAlways || request.type == SCPermissionTypeLocationFullAccuracy) {
        SCLocationRequestOperation *operation = [[SCLocationRequestOperation alloc] initWithRequest:request completion:nil];
        SCLocationAuthorizationScope scope = operation.scope;
        return [SCPermissionResult locationResultWithRequest:request state:[operation stateForScope:scope] scope:scope accuracy:operation.accuracy error:nil];
    }
    return [SCPermissionResult resultWithRequest:request state:[SCPermissionCenter.sharedCenter stateForType:request.type] error:nil];
}
- (void)request:(SCPermissionRequest *)request completion:(void (^)(SCPermissionResult *))completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *key = [self keyForRequest:request];
        if (completion) { if (!self.waiters[key]) { self.waiters[key] = [NSMutableArray array]; } [self.waiters[key] addObject:[completion copy]]; }
        if (self.waiters[key].count == 1) { [self.pending addObject:request]; [self drain]; }
    });
}
- (void)drain { if (self.requesting || self.pending.count == 0) return; self.requesting = YES; SCPermissionRequest *request = self.pending.firstObject; [self.pending removeObjectAtIndex:0]; SCPermissionConfigurationReport *report = [self configurationReportForRequests:@[request]]; if (!report.isValid) { NSError *error = [NSError errorWithDomain:SCPermissionCoreErrorDomain code:SCPermissionCoreErrorConfiguration userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Missing Info.plist configuration: %@", [report.missingInfoPlistKeys componentsJoinedByString:@", "]]}]; [self finishRequest:request result:[SCPermissionResult resultWithRequest:request state:SCPermissionStateUnsupported error:error]]; return; }
    if (request.type == SCPermissionTypeLocationWhenInUse || request.type == SCPermissionTypeLocationAlways || request.type == SCPermissionTypeLocationFullAccuracy) { __weak typeof(self) weakSelf = self; SCLocationRequestOperation *operation = [[SCLocationRequestOperation alloc] initWithRequest:request completion:^(SCPermissionResult *result) { __strong typeof(weakSelf) strongSelf = weakSelf; [strongSelf.locationOperations filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(SCLocationRequestOperation *candidate, NSDictionary *_) { return candidate.request != request; }]]; [strongSelf finishRequest:request result:result]; }]; [self.locationOperations addObject:operation]; [operation start]; return; }
    [SCPermissionCenter.sharedCenter requestPermission:request.type completion:^(SCPermissionState state) { [self finishRequest:request result:[SCPermissionResult resultWithRequest:request state:state error:nil]]; }]; }
- (void)finishRequest:(SCPermissionRequest *)request result:(SCPermissionResult *)result { NSString *key = [self keyForRequest:request]; NSArray *waiters = [self.waiters[key] copy]; [self.waiters removeObjectForKey:key]; for (void (^waiter)(SCPermissionResult *) in waiters) waiter(result); self.requesting = NO; [self drain]; }
- (void)requestAll:(NSArray<SCPermissionRequest *> *)requests completion:(void (^)(NSArray<SCPermissionResult *> *))completion { [self requestAll:requests atIndex:0 results:[NSMutableArray array] completion:completion]; }
- (void)requestAll:(NSArray<SCPermissionRequest *> *)requests atIndex:(NSUInteger)index results:(NSMutableArray<SCPermissionResult *> *)results completion:(void (^)(NSArray<SCPermissionResult *> *))completion { if (index == requests.count) { if (completion) completion(results.copy); return; } [self request:requests[index] completion:^(SCPermissionResult *result) { [results addObject:result]; [self requestAll:requests atIndex:index + 1 results:results completion:completion]; }]; }
- (void)openAppSettings { [SCPermissionCenter.sharedCenter openAppSettings]; }
@end
