# 全平台 FFmpeg 支持 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use compose:subagent (recommended) or compose:execute to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让应用支持 Windows、macOS、Linux、Android、iOS 全平台运行，通过 ffmpeg_kit_flutter 统一 FFmpeg 调用。

**Architecture:** 在现有 FfmpegService 上层抽象 FFmpegBackend 接口，桌面端（Windows）保持 Process.run 实现，其他平台通过 ffmpeg_kit_flutter 调用。UI 层代码无需修改。

**Tech Stack:** Dart, Flutter, ffmpeg_kit_flutter, dart:io Process

## Global Constraints

- Flutter SDK >=3.7.0
- ffmpeg_kit_flutter 最新版
- Windows 使用系统 FFmpeg（需要用户安装）
- 其他平台使用 ffmpeg_kit_flutter 内置 FFmpeg
- UI 层（home_page.dart, converter_page.dart）不修改

---

### Task 1: 添加 ffmpeg_kit_flutter 依赖

**Covers:** 无（基础设施任务）

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: 修改 pubspec.yaml**

在 `dependencies` 部分添加：

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  file_picker: ^11.0.2
  path_provider: ^2.1.0
  desktop_drop: ^0.7.1
  path: ^1.8.0
  ffmpeg_kit_flutter_full: ^6.0.3
```

- [ ] **Step 2: 运行 flutter pub get**

```bash
flutter pub get
```

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "deps: add ffmpeg_kit_flutter"
```

---

### Task 2: 创建 FFmpegBackend 抽象接口

**Covers:** 无（架构任务）

**Files:**
- Create: `lib/services/ffmpeg_backend.dart`

**Interfaces:**
- Produces: `FFmpegBackend` 抽象类，包含 `convert`, `detectHardware`, `getVersion`, `findPath` 方法

- [ ] **Step 1: 创建 FFmpegBackend 抽象类**

```dart
// lib/services/ffmpeg_backend.dart
import '../models/format_info.dart';

abstract class FFmpegBackend {
  Future<String> findPath();
  Future<double> getDuration(String inputPath);
  Future<List<HardwareAccelerator>> detectHardwareAccelerators();
  Future<String> convert(
    String inputPath,
    String outputPath,
    String outputFormat,
    ConversionSettings settings,
    void Function(double progress) onProgress,
    String hardwareDevice,
  );
  Future<String> getVersion();
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/services/ffmpeg_backend.dart
git commit -m "feat: add FFmpegBackend abstract interface"
```

---

### Task 3: 提取桌面端现有实现到 FFmpegBackendDesktop

**Covers:** 无（重构任务）

**Files:**
- Create: `lib/services/ffmpeg_backend_desktop.dart`
- Modify: `lib/services/ffmpeg_service.dart`（保留为入口）

**Interfaces:**
- Produces: `FFmpegBackendDesktop` 实现 `FFmpegBackend`
- Consumes: FFmpegBackend 抽象类

- [ ] **Step 1: 将现有 ffmpeg_service.dart 逻辑移入 FFmpegBackendDesktop**

将 `ffmpeg_service.dart` 中的 `_findFfmpegPath`, `_getDuration`, `detectHardwareAccelerators`, `convert`, `getVersion` 方法复制到新的 `ffmpeg_backend_desktop.dart` 中，实现 FFmpegBackend 接口。

```dart
// lib/services/ffmpeg_backend_desktop.dart
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:path/path.dart' as path;
import '../models/format_info.dart';
import 'ffmpeg_backend.dart';

class FFmpegBackendDesktop implements FFmpegBackend {
  String _ffmpegPath = 'ffmpeg';

  @override
  Future<String> findPath() async {
    // ... 保留原有 _findFfmpegPath 逻辑
  }

  @override
  Future<double> getDuration(String inputPath) async {
    // ... 保留原有 _getDuration 逻辑
  }

  @override
  Future<List<HardwareAccelerator>> detectHardwareAccelerators() async {
    // ... 保留原有 detectHardwareAccelerators 逻辑
  }

  @override
  Future<String> convert(
    String inputPath,
    String outputPath,
    String outputFormat,
    ConversionSettings settings,
    void Function(double progress) onProgress,
    String hardwareDevice,
  ) async {
    // ... 保留原有 convert 逻辑
  }

  @override
  Future<String> getVersion() async {
    // ... 保留原有 getVersion 逻辑
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/services/ffmpeg_backend_desktop.dart
git commit -m "refactor: extract desktop FFmpeg implementation"
```

---

### Task 4: 实现 FFmpegBackendFFmpegKit

**Covers:** 无（新功能任务）

**Files:**
- Create: `lib/services/ffmpeg_backend_ffmpeg_kit.dart`

**Interfaces:**
- Produces: `FFmpegBackendFFmpegKit` 实现 `FFmpegBackend`
- Consumes: ffmpeg_kit_flutter 包

- [ ] **Step 1: 创建 ffmpeg_kit 实现**

```dart
// lib/services/ffmpeg_backend_ffmpeg_kit.dart
import 'dart:async';
import 'dart:io';
import 'package:ffmpeg_kit_flutter_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_full/return_code.dart';
import 'package:ffmpeg_kit_flutter_full/statistics.dart';
import '../models/format_info.dart';
import 'ffmpeg_backend.dart';

class FFmpegBackendFFmpegKit implements FFmpegBackend {
  @override
  Future<String> findPath() async {
    return 'ffmpeg';
  }

  @override
  Future<double> getDuration(String inputPath) async {
    // 使用 ffprobe 获取时长
    final session = await FFmpegKit.execute(
      '-i "$inputPath"',
    );
    final output = await session.getAllLogsAsString();
    final durationRegex = RegExp(r'Duration:\s*(\d+):(\d+):(\d+)\.(\d+)');
    final match = durationRegex.firstMatch(output ?? '');
    if (match != null) {
      int hours = int.parse(match.group(1)!);
      int minutes = int.parse(match.group(2)!);
      int seconds = int.parse(match.group(3)!);
      int centiseconds = int.parse(match.group(4)!);
      return hours * 3600 + minutes * 60 + seconds + centiseconds / 100.0;
    }
    return 0;
  }

  @override
  Future<List<HardwareAccelerator>> detectHardwareAccelerators() async {
    // ffmpeg_kit 默认使用内置编码器，硬件加速有限
    return [HardwareAccelerator(id: 'cpu', name: 'CPU', available: true)];
  }

  @override
  Future<String> convert(
    String inputPath,
    String outputPath,
    String outputFormat,
    ConversionSettings settings,
    void Function(double progress) onProgress,
    String hardwareDevice,
  ) async {
    final duration = await getDuration(inputPath);
    
    List<String> args = ['-i', '"$inputPath"', '-y'];

    // 视频编码
    if (settings.videoBitrate == -1) {
      args.addAll(['-c:v', 'copy']);
    } else {
      String codec = 'lib${settings.videoCodec}';
      args.addAll(['-c:v', codec]);
      if (settings.videoBitrate == 0) {
        if (settings.videoCodec == 'h264') {
          args.addAll(['-preset', 'medium', '-crf', '23']);
        } else if (settings.videoCodec == 'h265') {
          args.addAll(['-preset', 'medium', '-crf', '28']);
        }
      } else {
        args.addAll(['-b:v', '${settings.videoBitrate}k']);
      }
      if (settings.framerate > 0) {
        args.addAll(['-r', '${settings.framerate}']);
      }
      if (settings.resolutionWidth > 0 && settings.resolutionHeight > 0) {
        args.addAll(['-vf', 'scale=${settings.resolutionWidth}:${settings.resolutionHeight}']);
      }
    }

    // 音频编码
    if (settings.audioBitrate == -1) {
      args.addAll(['-c:a', 'copy']);
    } else {
      String codec = settings.audioCodec;
      if (codec == 'mp3') codec = 'libmp3lame';
      args.addAll(['-c:a', codec]);
      if (settings.audioBitrate > 0) {
        args.addAll(['-b:a', '${settings.audioBitrate}k']);
      }
    }

    args.add('"$outputPath"');

    final session = await FFmpegKit.executeWithArguments(args);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      onProgress(100.0);
      return outputPath;
    } else {
      throw Exception('FFmpegKit conversion failed');
    }
  }

  @override
  Future<String> getVersion() async {
    final session = await FFmpegKit.execute('-version');
    final output = await session.getAllLogsAsString();
    return (output ?? '').split('\n').first;
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/services/ffmpeg_backend_ffmpeg_kit.dart
git commit -m "feat: implement FFmpegKit backend for mobile/mac/linux"
```

---

### Task 5: 重构 FfmpegService 使用 Backend 模式

**Covers:** 无（核心重构）

**Files:**
- Modify: `lib/services/ffmpeg_service.dart`

**Interfaces:**
- Consumes: FFmpegBackendDesktop, FFmpegBackendFFmpegKit
- Produces: 重构后的 FfmpegService，对外 API 不变

- [ ] **Step 1: 重写 FfmpegService 委托给 Backend**

```dart
// lib/services/ffmpeg_service.dart
import 'dart:io';
import '../models/format_info.dart';
import 'ffmpeg_backend.dart';
import 'ffmpeg_backend_desktop.dart';
import 'ffmpeg_backend_ffmpeg_kit.dart';

class HardwareAccelerator {
  final String id;
  final String name;
  final bool available;

  HardwareAccelerator({
    required this.id,
    required this.name,
    required this.available,
  });
}

class FfmpegService {
  static FfmpegService? _instance;
  late final FFmpegBackend _backend;
  
  factory FfmpegService() {
    _instance ??= FfmpegService._internal();
    return _instance!;
  }
  
  FfmpegService._internal() {
    if (Platform.isWindows) {
      _backend = FFmpegBackendDesktop();
    } else {
      _backend = FFmpegBackendFFmpegKit();
    }
  }

  Future<String> _findFfmpegPath() => _backend.findPath();
  Future<double> _getDuration(String inputPath) => _backend.getDuration(inputPath);
  Future<List<HardwareAccelerator>> detectHardwareAccelerators() => _backend.detectHardwareAccelerators();
  Future<String> getVersion() => _backend.getVersion();
  
  Future<String> convert(
    String inputPath,
    String outputPath,
    String outputFormat,
    ConversionSettings settings,
    void Function(double progress) onProgress,
    String hardwareDevice,
  ) => _backend.convert(inputPath, outputPath, outputFormat, settings, onProgress, hardwareDevice);
}
```

- [ ] **Step 2: 确保 converter_page.dart 的 HardwareAccelerator 类型一致**

检查 `converter_page.dart` 中使用的 `HardwareAccelerator` 类型来自 `ffmpeg_service.dart`，不需要修改导入。

- [ ] **Step 3: Commit**

```bash
git add lib/services/ffmpeg_service.dart
git commit -m "refactor: FfmpegService delegates to platform backends"
```

---

### Task 6: Android 平台配置

**Covers:** 无（平台配置）

**Files:**
- Modify: `android/app/build.gradle`

- [ ] **Step 1: 配置 Android ABI filters**

在 `android/app/build.gradle` 的 `defaultConfig` 中添加：

```groovy
android {
  defaultConfig {
    ndk {
      abiFilters 'armeabi-v7a', 'arm64-v8a', 'x86', 'x86_64'
    }
  }
}
```

- [ ] **Step 2: 确保 minSdkVersion >= 24**

ffmpeg_kit_flutter 要求 Android minSdkVersion >= 24。

```groovy
defaultConfig {
    minSdkVersion 24
}
```

- [ ] **Step 3: Commit**

```bash
git add android/app/build.gradle
git commit -m "chore: configure Android for ffmpeg_kit"
```

---

### Task 7: iOS 平台配置

**Covers:** 无（平台配置）

**Files:**
- Modify: `ios/Podfile`（如果存在）

- [ ] **Step 1: 确保 Podfile 最低 iOS 版本**

ffmpeg_kit_flutter 要求 iOS >= 13。

```ruby
platform :ios, '13.0'
```

- [ ] **Step 2: Commit**

```bash
git add ios/Podfile
git commit -m "chore: configure iOS for ffmpeg_kit"
```

---

### Task 8: 桌面端保留 drop 支持

**Covers:** 无（条件编译）

**Files:**
- Modify: `lib/pages/home_page.dart`

**Interfaces:**
- Consumes: desktop_drop 包

- [ ] **Step 1: 条件导入 desktop_drop**

在 `home_page.dart` 中将 desktop_drop 导入改为条件导入：

```dart
import 'package:flutter/foundation.dart';
import 'dart:io';

// desktop_drop 只在桌面端可用
import 'package:desktop_drop/desktop_drop.dart' if (dart.library.html) '';
```

在 `build` 方法中，根据平台判断是否使用 DropTarget：

```dart
Widget _buildDropZone(ColorScheme colorScheme) {
  final isDesktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  
  Widget content = MouseRegion(
    cursor: SystemMouseCursors.click,
    child: GestureDetector(
      onTap: _pickFiles,
      child: AnimatedContainer(
        // ... 原有内容
      ),
    ),
  );

  if (isDesktop) {
    return DropTarget(
      onDragDone: (details) {
        setState(() {
          _selectedFiles = details.files
              .map((xFile) => File(xFile.path))
              .where((file) => _isMediaFile(file.path))
              .toList();
        });
        if (_selectedFiles.isNotEmpty) {
          _navigateToConverter();
        }
      },
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      child: content,
    );
  }
  
  return content;
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/pages/home_page.dart
git commit -m "feat: conditional desktop_drop for cross-platform"
```

---

### Task 9: 全平台构建验证

**Covers:** 无（验证任务）

**Files:**
- 无（运行构建命令）

- [ ] **Step 1: Windows 构建**

```bash
flutter build windows
```

- [ ] **Step 2: Android 构建**

```bash
flutter build apk
```

- [ ] **Step 3: iOS 构建**

```bash
flutter build ios
```

- [ ] **Step 4: macOS 构建**

```bash
flutter build macos
```

- [ ] **Step 5: Linux 构建**

```bash
flutter build linux
```

- [ ] **Step 6: Final Commit**

```bash
git add .
git commit -m "chore: verify cross-platform builds"
```
