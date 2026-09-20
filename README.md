# Next Permission

可直接复制到 Objective-C iOS 项目的权限工具模块，最低支持 iOS 14。

## 模块边界

- `Permissions/SCPermissionCore`：系统授权的唯一新入口。
- `Permissions/SCPermissionCenter`：旧版兼容层；新业务不应继续以它建模定位。
- `Capabilities/SCCapabilityProviders`：文件书签、网络路径和 Wi-Fi 加入。这些不是系统授权，和 Permission Core 分开使用。

## 最小接入

```objc
#import "SCPermissionCore.h"

SCPermissionRequest *request = [SCPermissionRequest locationWhenInUseRequest];
[[SCPermissionCore sharedCore] request:request completion:^(SCPermissionResult *result) {
    if (result.state == SCPermissionStateAuthorized) {
        // result.locationScope: whenInUse / always
        // result.locationAccuracy: full / reduced
    }
}];
```

所有 completion 在主线程执行。同一个请求尚未完成时，Core 会合并多个调用者；不同请求按顺序发起，避免系统弹窗重叠。

## 定位

定位结果同时包含授权范围和精确度：

| 目标 | 请求 | 结果重点 |
| --- | --- | --- |
| 前台定位 | `locationWhenInUseRequest` | `locationScope` |
| 始终定位 | `locationAlwaysRequest` | iOS 可能先只给前台；以实际 `locationScope` 为准 |
| 临时完整精度 | `temporaryFullAccuracyRequestWithPurposeKey:` | 需要已有定位授权及有效 purpose key |

不要把“始终定位”和“完整精度”当作普通独立权限：前者是授权范围升级，后者依附于已有定位授权。

## Info.plist 与预检

请求前可检查配置：

```objc
SCPermissionConfigurationReport *report =
  [[SCPermissionCore sharedCore] configurationReportForRequests:@[
    [SCPermissionRequest requestWithType:SCPermissionTypeCamera],
    [SCPermissionRequest microphoneRequest]
  ]];
NSAssert(report.isValid, @"%@", report.missingInfoPlistKeys);
```

核心会安全返回配置错误，不会仅因缺失用途说明而继续请求。按使用场景配置：

- 相机：`NSCameraUsageDescription`
- 麦克风：`NSMicrophoneUsageDescription`
- 相册读取／保存：`NSPhotoLibraryUsageDescription`／`NSPhotoLibraryAddUsageDescription`
- 蓝牙：`NSBluetoothAlwaysUsageDescription`
- 前台／始终定位：`NSLocationWhenInUseUsageDescription`／`NSLocationAlwaysAndWhenInUseUsageDescription`
- 临时完整精度：`NSLocationTemporaryUsageDescriptionDictionary.<purposeKey>`
- 本地网络：`NSLocalNetworkUsageDescription` 与至少一个 `NSBonjourServices`

## 设置页与本地网络

权限被拒绝后，以业务解释提示用户，再调用 `openAppSettings`；不要在启动时无上下文跳转设置页。本地网络没有可靠的独立查询 API，结果来自 Bonjour 探测：网络不可达和超时不等于用户拒绝授权。

## 真机验证清单

1. 在干净安装上逐项首次请求；确认用途说明与业务动作匹配。
2. 拒绝后在系统设置中恢复授权，回到 App 后重新查询。
3. 将“精确位置”关闭，确认结果仍为授权但 `locationAccuracy` 为 `reduced`；再请求临时完整精度。
4. 请求始终定位时，接受系统可能先返回 `whenInUse` 的实际状态。
5. 分别在可达与不可达局域网下验证 Bonjour 探测结果，确认不把超时显示为“已拒绝”。
