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
