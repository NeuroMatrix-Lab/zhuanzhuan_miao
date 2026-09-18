# 打包说明

CI 产出物（`Build Installers` workflow）：

| 平台 | 格式 | 产物名 |
|------|------|--------|
| Windows | MSI (WiX) | `ZhuanzhuanMiao-1.0.0-windows-x64.msi` |
| macOS | DMG | `ZhuanzhuanMiao-1.0.0-macos-universal.dmg` |
| Android | APK | `ZhuanzhuanMiao-1.0.0-android-universal.apk` |
| Linux | RPM | `ZhuanzhuanMiao-1.0.0-linux-x86_64.rpm` |

- iOS **不在** CI 范围内。
- 产物在 Actions → 对应 job → Artifacts 下载。
- 桌面/开始菜单快捷方式、RPM 桌面入口图标使用 `assets/images/logo.png`（应用内 logo）。

触发方式：push 到 `master` / `dev` / `feature/*`，或在 Actions 页手动 `workflow_dispatch`。
