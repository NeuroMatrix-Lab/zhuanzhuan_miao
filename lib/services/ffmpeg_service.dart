import '../models/format_info.dart';
import 'ffmpeg_backend.dart';
import 'ffmpeg_backend_desktop.dart' if (dart.library.android) 'ffmpeg_backend_mobile.dart';

export 'ffmpeg_backend.dart' show HardwareAccelerator;

class FfmpegService {
  static FfmpegService? _instance;
  late final FFmpegBackend _backend;

  factory FfmpegService() {
    _instance ??= FfmpegService._internal();
    return _instance!;
  }

  FfmpegService._internal() {
    _backend = FFmpegBackendDesktop();
  }

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
