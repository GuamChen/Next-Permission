# GitHub 发布流程

## 发布前检查

1. 选择并提交许可证。公开仓库在没有许可证时，默认并未授予他人复用代码的权利。
2. 更新 `README.md` 的接入说明与最低 iOS 版本。
3. 在 macOS 上执行：

   ```sh
   sh scripts/verify-package.sh
   xcodebuild test -project 'Next Permission.xcodeproj' \
     -scheme 'Next PermissionTests' \
     -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
     CODE_SIGNING_ALLOWED=NO
   ```

4. 确认 GitHub Actions 的 `iOS library checks` 绿色通过。

## 创建首个版本

使用语义化版本。首次公开版本建议为 `1.0.0`；若 API 仍可能调整，使用 `0.1.0`。

```sh
git checkout main
git pull --ff-only origin main
git tag -a 0.1.0 -m 'SCPermissionKit 0.1.0'
git push origin 0.1.0
```

在 GitHub 的 **Releases → Draft a new release** 中选择该 tag，并使用 `README.md` 的功能摘要填写 release notes。Swift Package Manager 会直接解析 Git tag，不需要上传二进制文件或注册中心。

## 使用方接入

```swift
.package(url: "https://github.com/GuamChen/Next-Permission.git", from: "0.1.0")
```

使用方必须自行配置其 App 的 `Info.plist`；库会通过 `configurationReportForRequests:` 报告缺失的用途说明。
