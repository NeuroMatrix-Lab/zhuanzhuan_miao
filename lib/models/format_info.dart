class FormatInfo {
  final String format;
  final String name;
  final bool isVideo;

  const FormatInfo({
    required this.format,
    required this.name,
    required this.isVideo,
  });
}

class ConversionSettings {
  /// -1 = 复制源流，0 = 动态码率，>0 = 固定码率 kbps
  static const int bitrateCopy = -1;
  static const int bitrateVBR = 0;

  String videoCodec;
  int videoBitrate;
  int framerate;
  int resolutionWidth;
  int resolutionHeight;
  bool hardwareAcceleration;

  String audioCodec;
  int audioBitrate;
  int sampleRate;

  ConversionSettings({
    this.videoCodec = 'h264',
    this.videoBitrate = bitrateVBR,
    this.framerate = 0,
    this.resolutionWidth = 0,
    this.resolutionHeight = 0,
    this.hardwareAcceleration = true,
    this.audioCodec = 'aac',
    this.audioBitrate = bitrateVBR,
    this.sampleRate = 0,
  });
}
