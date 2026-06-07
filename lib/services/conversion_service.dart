import 'package:path_provider/path_provider.dart';
import '../models/format_info.dart';

// TODO: 替换为 flutter_rust_bridge 生成的 FFI 调用
// import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';

class ConversionService {
  // 获取支持的格式列表
  static List<FormatInfo> getSupportedFormats() {
    // TODO: 从 Rust FFI 获取
    // return get_supported_formats();
    
    return const [
      // 视频格式
      FormatInfo(format: 'mp4', name: 'MP4 Video', is_video: true),
      FormatInfo(format: 'avi', name: 'AVI Video', is_video: true),
      FormatInfo(format: 'mkv', name: 'MKV Video', is_video: true),
      FormatInfo(format: 'webm', name: 'WebM Video', is_video: true),
      FormatInfo(format: 'mov', name: 'MOV Video', is_video: true),
      FormatInfo(format: 'gif', name: 'GIF Animation', is_video: true),
      FormatInfo(format: 'jpg', name: 'JPEG Image', is_video: true),
      FormatInfo(format: 'png', name: 'PNG Image', is_video: true),
      // 音频格式
      FormatInfo(format: 'mp3', name: 'MP3 Audio', is_video: false),
      FormatInfo(format: 'wav', name: 'WAV Audio', is_video: false),
      FormatInfo(format: 'aac', name: 'AAC Audio', is_video: false),
      FormatInfo(format: 'flac', name: 'FLAC Audio', is_video: false),
      FormatInfo(format: 'ogg', name: 'OGG Audio', is_video: false),
    ];
  }

  // 执行转换
  static Future<ConversionResult> convert({
    required String inputPath,
    required String outputFormat,
  }) async {
    try {
      // TODO: 从 Rust FFI 调用
      // final taskId = await convert(inputPath, outputPath, outputFormat);
      
      // 模拟转换
      await Future.delayed(const Duration(seconds: 2));
      
      // 生成输出路径
      final outputPath = await _generateOutputPath(inputPath, outputFormat);
      
      return ConversionResult.success(
        taskId: 'mock-task-id',
        outputPath: outputPath,
      );
    } catch (e) {
      return ConversionResult.failure(error: e.toString());
    }
  }

  // 获取任务状态
  static Future<TaskStatus> getTaskStatus(String taskId) async {
    // TODO: 从 Rust FFI 调用
    // return get_task(taskId);
    
    return TaskStatus(
      id: taskId,
      status: 'Completed',
      progress: 100,
    );
  }

  // 生成输出文件路径
  static Future<String> _generateOutputPath(
    String inputPath,
    String outputFormat,
  ) async {
    final dir = await getApplicationDocumentsDirectory();
    final fileName = inputPath.split('/').last.split('.').first;
    return '${dir.path}/$fileName.$outputFormat';
  }
}

class ConversionResult {
  final bool success;
  final String? taskId;
  final String? outputPath;
  final String? error;

  const ConversionResult._({
    required this.success,
    this.taskId,
    this.outputPath,
    this.error,
  });

  factory ConversionResult.success({
    required String taskId,
    required String outputPath,
  }) {
    return ConversionResult._(
      success: true,
      taskId: taskId,
      outputPath: outputPath,
    );
  }

  factory ConversionResult.failure({required String error}) {
    return ConversionResult._(
      success: false,
      error: error,
    );
  }
}

class TaskStatus {
  final String id;
  final String status;
  final int progress;
  final String? errorMessage;

  const TaskStatus({
    required this.id,
    required this.status,
    required this.progress,
    this.errorMessage,
  });
}
