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
  // 码率模式: -1=复制源文件, 0=动态码率(VBR), >0=固定码率(kbps)
  static const int bitrateCopy = -1;
  static const int bitrateVBR = 0;

  // 视频设置
  String videoCodec;
  int videoBitrate;
  int framerate;
  int resolutionWidth;
  int resolutionHeight;
  bool hardwareAcceleration;

  // 音频设置
  String audioCodec;
  int audioBitrate;
  int sampleRate;

  ConversionSettings({
    // 视频默认值
    this.videoCodec = 'h264',
    this.videoBitrate = 0, // 默认使用动态码率
    this.framerate = 0, // 默认复制源文件
    this.resolutionWidth = 0, // 默认复制源文件
    this.resolutionHeight = 0,
    this.hardwareAcceleration = true,
    // 音频默认值
    this.audioCodec = 'aac',
    this.audioBitrate = 0, // 默认使用动态码率
    this.sampleRate = 0, // 默认复制源文件
  });

  String get videoBitrateDisplay {
    if (videoBitrate == bitrateCopy) return '复制';
    if (videoBitrate == bitrateVBR) return '动态(VBR)';
    return '$videoBitrate kbps';
  }

  String get framerateDisplay {
    if (framerate == 0) return '复制';
    return '$framerate FPS';
  }

  String get resolutionDisplay {
    if (resolutionWidth == 0 || resolutionHeight == 0) return '复制';
    return '${resolutionHeight}p';
  }

  String get audioBitrateDisplay {
    if (audioBitrate == bitrateCopy) return '复制';
    if (audioBitrate == bitrateVBR) return '动态(VBR)';
    return '$audioBitrate kbps';
  }

  String get sampleRateDisplay {
    if (sampleRate == 0) return '复制';
    return '$sampleRate Hz';
  }
}
