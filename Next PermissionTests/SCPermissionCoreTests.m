#import <XCTest/XCTest.h>
#import "SCPermissionCore.h"

@interface SCPermissionCoreTests : XCTestCase
@end

@implementation SCPermissionCoreTests

- (void)testLocationResultRetainsScopeAndAccuracy {
    SCPermissionResult *result = [SCPermissionResult
        locationResultWithRequest:[SCPermissionRequest
                                       locationWhenInUseRequest]
                         state:SCPermissionStateAuthorized
                         scope:SCLocationAuthorizationScopeWhenInUse
                      accuracy:SCLocationAccuracyReduced
                         error:nil];

    XCTAssertEqual(result.state, SCPermissionStateAuthorized);
    XCTAssertEqual(result.locationScope, SCLocationAuthorizationScopeWhenInUse);
    XCTAssertEqual(result.locationAccuracy, SCLocationAccuracyReduced);
}

- (void)testConfigurationReportDetectsMissingMicrophoneDescription {
    SCPermissionConfigurationReport *report =
        [SCPermissionConfigurationReport reportForBundle:[NSBundle bundleForClass:self.class]
                                             requests:@[[SCPermissionRequest microphoneRequest]]];

    XCTAssertFalse(report.isValid);
    XCTAssertTrue([report.missingInfoPlistKeys containsObject:@"NSMicrophoneUsageDescription"]);
}

@end
