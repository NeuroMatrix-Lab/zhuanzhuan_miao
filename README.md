<p align="center">
  <h1 align="center">🐾 转转喵 zhuanzhuan_miao</h1>
  <p align="center">基于 Flutter + ffmpeg_kit 的跨平台音视频格式转换工具</p>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.7+-02569B?logo=flutter" alt="Flutter">
  <img src="https://img.shields.io/badge/FFmpegKit-powered-green" alt="FFmpegKit">
  <img src="https://img.shields.io/badge/Platform-Windows%20%7C%20macOS%20%7C%20Linux%20%7C%20Android%20%7C%20iOS-brightgreen" alt="Platform">
  <img src="https://img.shields.io/badge/License-GPL--3.0-blue" alt="License">
</p>

---

## ✨ 功能特点

- 🎬 **全格式覆盖** — 支持 MP4、MKV、AVI、MOV、WebM、GIF、MP3、WAV、AAC、FLAC、OGG 等主流音视频格式
- 🧰 **全平台统一** — Android / iOS / Windows / macOS / Linux 使用同一套 `ffmpeg_kit_flutter_new`
- 🚀 **硬件加速** — 运行时检测可用编码器（如 Apple VideoToolbox / NVENC 等）
- 📂 **拖放操作** — 桌面端支持直接拖放文件，移动端支持多选
- 🔄 **批量转换** — 一次选择多个文件，一键全部转换
- ⚙️ **专业参数** — 支持自定义视频编码、码率、帧率、分辨率，音频编码、码率、采样率
- 🌓 **主题切换** — 跟随系统的深色/浅色主题
- 📊 **实时进度** — 转换过程中实时显示进度百分比

## 🎛️ 转换设置

### 视频

| 参数 | 选项 |
|------|------|
| 编码器 | H.264 / H.265 / VP9 / AV1 |
| 码率模式 | 复制源流 / 动态码率 (VBR, CRF) / 固定码率 (CBR) |
| 帧率 | 复制源帧率 / 自定义 FPS |
| 分辨率 | 复制源分辨率 / 自定义（如 1080p、720p） |
| 硬件加速 | CPU / 平台可用硬件编码器（自动检测） |

### 音频

| 参数 | 选项 |
|------|------|
| 编码器 | AAC / MP3 / Opus / FLAC / PCM |
| 码率 | 复制源码率 / 动态码率 / 固定码率 (kbps) |
| 采样率 | 复制源采样率 / 自定义 (Hz) |

## 📦 安装

### 环境要求

- Flutter SDK ≥ 3.7.0
- Dart SDK ≥ 3.7.0
- 不需要系统预装 FFmpeg（由 `ffmpeg_kit_flutter_new` 内置）
- Linux 构建额外依赖：`libjson-glib-dev`

### 开发运行

```bash
git clone https://github.com/NeuroMatrix-Lab/zhuanzhuan_miao.git
cd zhuanzhuan_miao
flutter pub get
flutter run
```

### 构建发布版

```bash
# Windows
flutter build windows

# macOS
flutter build macos

# Linux
flutter build linux

# Android
flutter build apk

# iOS
flutter build ios
```

## 📁 项目结构

```
zhuanzhuan_miao/
├── lib/
│   ├── main.dart              # 应用入口
│   ├── models/
│   │   └── format_info.dart   # 格式定义 & 转换参数模型
│   ├── pages/
│   │   ├── home_page.dart     # 首页（文件选择/拖放）
│   │   └── converter_page.dart # 转换页（参数配置 & 进度）
│   └── services/
│       ├── ffmpeg_service.dart     # FFmpegKit 统一调用
│       └── conversion_service.dart # 转换格式列表
├── android/
├── ios/
├── linux/
├── macos/
├── windows/
└── .github/workflows/
    └── build.yml              # CI/CD 构建
```

## 🔧 技术栈

- **UI**: Flutter + Material 3
- **转码**: [ffmpeg_kit_flutter_new](https://pub.dev/packages/ffmpeg_kit_flutter_new)（FFmpeg 8.x，Full+GPL）
- **文件选择**: file_picker
- **拖放支持**: desktop_drop
- **路径管理**: path_provider + path

## ⚖️ 许可证说明

应用依赖 `ffmpeg_kit_flutter_new`（Full + GPL），内含 x264 / x265 等 GPL 组件，因此本项目以 **GPL-3.0** 发布。

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'Add amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 创建 Pull Request

---

<p align="center">Made with ❤️ by <a href="https://github.com/NeuroMatrix-Lab">NeuroMatrix-Lab</a></p>
