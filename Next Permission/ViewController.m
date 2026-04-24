//
//  ViewController.m
//  Next Permission
//
//  Created by Gavin on 2026/4/23.
//

#import "ViewController.h"
#import "Permissions/SCPermissionCenter.h"

@interface ViewController ()
@property (nonatomic, strong) UITextView *textView;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Next Permission";
    if (@available(iOS 13.0, *)) {
        self.view.backgroundColor = UIColor.systemBackgroundColor;
    } else {
        self.view.backgroundColor = UIColor.whiteColor;
    }

    [self buildDemoInterface];
    [SCPermissionCenter.sharedCenter.networkPathProvider startMonitoring];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(handleNetworkChange)
                                               name:SCNetworkPathCapabilityDidChangeNotification
                                             object:nil];
    [self refreshSummary];
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)buildDemoInterface {
    UIStackView *stackView = [[UIStackView alloc] init];
    stackView.axis = UILayoutConstraintAxisVertical;
    stackView.spacing = 12.0;
    stackView.translatesAutoresizingMaskIntoConstraints = NO;

    NSArray<NSDictionary<NSString *, id> *> *items = @[
        @{@"title": @"请求相机", @"tag": @(SCPermissionTypeCamera)},
        @{@"title": @"请求相册读取", @"tag": @(SCPermissionTypePhotoRead)},
        @{@"title": @"请求相册保存", @"tag": @(SCPermissionTypePhotoAdd)},
        @{@"title": @"请求定位前台", @"tag": @(SCPermissionTypeLocationWhenInUse)},
        @{@"title": @"请求蓝牙", @"tag": @(SCPermissionTypeBluetooth)},
        @{@"title": @"请求本地网络", @"tag": @(SCPermissionTypeLocalNetwork)}
    ];

    for (NSDictionary<NSString *, id> *item in items) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        [button setTitle:item[@"title"] forState:UIControlStateNormal];
        button.tag = [item[@"tag"] integerValue];
        button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        [button addTarget:self action:@selector(handlePermissionButton:) forControlEvents:UIControlEventTouchUpInside];
        [stackView addArrangedSubview:button];
    }

    UIButton *settingsButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [settingsButton setTitle:@"打开系统设置" forState:UIControlStateNormal];
    settingsButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    [settingsButton addTarget:self action:@selector(handleSettingsButton) forControlEvents:UIControlEventTouchUpInside];
    [stackView addArrangedSubview:settingsButton];

    self.textView = [[UITextView alloc] init];
    self.textView.translatesAutoresizingMaskIntoConstraints = NO;
    self.textView.editable = NO;
    if (@available(iOS 13.0, *)) {
        self.textView.font = [UIFont monospacedSystemFontOfSize:13.0 weight:UIFontWeightRegular];
    } else {
        self.textView.font = [UIFont fontWithName:@"Menlo-Regular" size:13.0] ?: [UIFont systemFontOfSize:13.0];
    }

    [self.view addSubview:stackView];
    [self.view addSubview:self.textView];

    UILayoutGuide *guide = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [stackView.topAnchor constraintEqualToAnchor:guide.topAnchor constant:20.0],
        [stackView.leadingAnchor constraintEqualToAnchor:guide.leadingAnchor constant:20.0],
        [stackView.trailingAnchor constraintEqualToAnchor:guide.trailingAnchor constant:-20.0],
        [self.textView.topAnchor constraintEqualToAnchor:stackView.bottomAnchor constant:16.0],
        [self.textView.leadingAnchor constraintEqualToAnchor:guide.leadingAnchor constant:16.0],
        [self.textView.trailingAnchor constraintEqualToAnchor:guide.trailingAnchor constant:-16.0],
        [self.textView.bottomAnchor constraintEqualToAnchor:guide.bottomAnchor constant:-16.0]
    ]];
}

- (void)handlePermissionButton:(UIButton *)sender {
    SCPermissionType type = (SCPermissionType)sender.tag;
    [SCPermissionCenter.sharedCenter requestPermission:type completion:^(SCPermissionState state) {
        [self refreshSummary];
        if (type == SCPermissionTypeLocalNetwork && state != SCPermissionStateAuthorized) {
            [SCPermissionCenter.sharedCenter openInAppPermissionGuideForType:type from:self];
        }
    }];
}

- (void)handleSettingsButton {
    [SCPermissionCenter.sharedCenter openAppSettings];
}

- (void)handleNetworkChange {
    [self refreshSummary];
}

- (void)refreshSummary {
    SCPermissionCenter *center = SCPermissionCenter.sharedCenter;
    SCNetworkPathCapabilityProvider *networkProvider = center.networkPathProvider;
    NSMutableArray<NSString *> *lines = [NSMutableArray array];

    NSArray<NSNumber *> *permissionTypes = @[
        @(SCPermissionTypeCamera),
        @(SCPermissionTypePhotoRead),
        @(SCPermissionTypePhotoAdd),
        @(SCPermissionTypeLocationWhenInUse),
        @(SCPermissionTypeBluetooth),
        @(SCPermissionTypeLocalNetwork)
    ];

    [lines addObject:@"== Permission States =="];
    for (NSNumber *number in permissionTypes) {
        SCPermissionType type = number.integerValue;
        SCPermissionState state = [center stateForType:type];
        [lines addObject:[NSString stringWithFormat:@"%@: %@", NSStringFromSCPermissionType(type), NSStringFromSCPermissionState(state)]];
    }

    [lines addObject:@""];
    [lines addObject:@"== Capability States =="];
    [lines addObject:[NSString stringWithFormat:@"fileExternalAccess: %@", NSStringFromSCCapabilityState(center.fileAccessProvider.currentState)]];
    [lines addObject:[NSString stringWithFormat:@"networkPath: %@", NSStringFromSCCapabilityState(networkProvider.currentState)]];
    [lines addObject:[NSString stringWithFormat:@"localNetworkProbe: %@", [center localNetworkDebugSummary]]];
    [lines addObject:[NSString stringWithFormat:@"reachable: %@", networkProvider.reachable ? @"YES" : @"NO"]];
    [lines addObject:[NSString stringWithFormat:@"wifi: %@", networkProvider.usingWiFi ? @"YES" : @"NO"]];
    [lines addObject:[NSString stringWithFormat:@"cellular: %@", networkProvider.usingCellular ? @"YES" : @"NO"]];
    [lines addObject:[NSString stringWithFormat:@"expensive: %@", networkProvider.expensive ? @"YES" : @"NO"]];
    [lines addObject:[NSString stringWithFormat:@"constrained: %@", networkProvider.constrained ? @"YES" : @"NO"]];

    self.textView.text = [lines componentsJoinedByString:@"\n"];
}


@end
