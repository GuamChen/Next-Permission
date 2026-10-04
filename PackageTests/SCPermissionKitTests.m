#import <XCTest/XCTest.h>
@import SCPermissionKit;

@interface SCPermissionKitTests : XCTestCase
@end

@implementation SCPermissionKitTests

- (void)testPublicModuleExportsLocationResultModel {
    SCPermissionResult *result = [SCPermissionResult
        locationResultWithRequest:[SCPermissionRequest locationWhenInUseRequest]
                         state:SCPermissionStateAuthorized
                         scope:SCLocationAuthorizationScopeWhenInUse
                      accuracy:SCLocationAccuracyReduced
                         error:nil];

    XCTAssertEqual(result.locationScope, SCLocationAuthorizationScopeWhenInUse);
    XCTAssertEqual(result.locationAccuracy, SCLocationAccuracyReduced);
}

@end
