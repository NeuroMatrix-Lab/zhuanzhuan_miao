# Flutter-FFmpeg 文件格式转换工具

基于Flutter和FFmpeg开发的跨平台文件格式转换工具，支持在Windows、macOS、Linux、iOS和Android上运行，能够转换各种音视频文件格式。

## 功能特点

- **跨平台支持**：支持Windows、macOS、Linux、iOS和Android
- **多种格式支持**：支持常见的音视频格式转换
- **批量转换**：支持同时转换多个文件
- **实时进度显示**：转换过程中实时显示进度
- **错误处理**：完善的错误处理和日志记录
- **用户友好**：直观的用户界面，操作简单

## 支持的格式

### 视频格式
- MP4
- MKV
- AVI
- MOV
- WMV
- FLV
- WebM

### 音频格式
- MP3
- WAV
- AAC
- FLAC
- OGG
- M4A

## 技术栈

- **前端**：Flutter
- **后端**：Dart + FFmpeg
- **状态管理**：Flutter内置状态管理
- **存储**：文件系统 + SharedPreferences
- **FFmpeg集成**：flutter_ffmpeg插件

## 安装说明

### 前提条件

- Flutter SDK (3.0+)
- 对于Windows：Visual Studio 2019或更高版本（带有"Desktop development with C++"工作负载）
- 对于macOS：Xcode 12或更高版本
- 对于Android：Android Studio
- 对于iOS：Xcode 12或更高版本

### 安装步骤

1. 克隆项目
   ```bash
   git clone https://github.com/yourusername/flutter_ffmpeg_converter.git
   cd flutter_ffmpeg_converter
   ```

2. 安装依赖
   ```bash
   flutter pub get
   ```

3. 运行应用
   ```bash
   flutter run
   ```

## 使用方法

1. 启动应用
2. 点击"Select File"按钮选择单个文件，或点击"Batch Select"按钮选择多个文件
3. 选择目标输出格式
4. 点击"Convert"按钮开始转换
5. 转换完成后，可在历史记录中查看转换结果

## 构建发布版本

### Windows
```bash
flutter build windows
```

### macOS
```bash
flutter build macos
```

### Linux
```bash
flutter build linux
```

### Android
```bash
flutter build apk
```

### iOS
```bash
flutter build ios
```

## 项目结构

```
flutter_ffmpeg_converter/
├── lib/
│   ├── main.dart
│   ├── src/
│   │   ├── models/
│   │   ├── services/
│   │   │   ├── ffmpeg_service.dart
│   │   │   ├── file_service.dart
│   │   │   ├── conversion_service.dart
│   │   │   └── log_service.dart
│   │   ├── ui/
│   │   │   ├── screens/
│   │   │   ├── widgets/
│   │   │   └── themes/
│   │   └── utils/
│   │       └── converter_utils.dart
│   └── assets/
├── test/
├── android/
├── ios/
├── linux/
├── macos/
└── windows/
```

## 贡献

欢迎贡献代码、报告bug或提出新功能建议。请创建issue或提交pull request。

## 许可证

MIT License

## 联系方式

- 项目地址：https://github.com/yourusername/flutter_ffmpeg_converter
- 作者：Your Name
