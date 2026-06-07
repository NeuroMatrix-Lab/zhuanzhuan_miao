import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/format_info.dart';
import '../services/conversion_service.dart';

class ConverterPage extends StatefulWidget {
  final List<File> files;

  const ConverterPage({super.key, required this.files});

  @override
  State<ConverterPage> createState() => _ConverterPageState();
}

class _ConverterPageState extends State<ConverterPage> {
  int _selectedFileIndex = 0;
  String? _selectedFormat;
  bool _isConverting = false;
  final Map<String, double> _fileProgress = {};
  String _outputPath = '';

  late List<FormatInfo> _supportedFormats;
  late ConversionSettings _settings;

  final List<String> _videoCodecs = ['h264', 'h265', 'vp9', 'av1'];
  final List<String> _audioCodecs = ['aac', 'mp3', 'opus', 'flac', 'pcm_s16le'];
  final List<int> _videoBitrates = [-1, 0, 500, 1000, 2000, 3000, 5000, 8000, 10000];
  final List<int> _audioBitrates = [-1, 0, 64, 128, 192, 256, 320];
  final List<int> _framerates = [0, 15, 24, 25, 30, 60];
  final List<String> _resolutions = ['复制', '1080p', '720p', '480p', '360p'];

  // 可用的硬件加速设备列表
  final List<Map<String, String>> _hardwareDevices = [
    {'id': 'nvidia', 'name': 'NVIDIA NVENC', 'icon': 'speed'},
    {'id': 'amd', 'name': 'AMD VCE', 'icon': 'speed'},
    {'id': 'intel', 'name': 'Intel QSV', 'icon': 'speed'},
    {'id': 'cpu', 'name': 'CPU (软件编码)', 'icon': 'computer'},
  ];
  String _selectedHardwareId = 'nvidia';

  @override
  void initState() {
    super.initState();
    _supportedFormats = ConversionService.getSupportedFormats();
    _settings = ConversionSettings();
    for (var file in widget.files) {
      _fileProgress[file.path] = 0.0;
    }
    _generateOutputPath();
    _detectHardwareDevice();
  }

  String get _hardwareDeviceName {
    final device = _hardwareDevices.firstWhere(
      (d) => d['id'] == _selectedHardwareId,
      orElse: () => {'name': 'Unknown'},
    );
    return device['name']!;
  }

  String get _currentHardwareDevice {
    return _settings.hardwareAcceleration ? _hardwareDeviceName : 'CPU';
  }

  Future<void> _detectHardwareDevice() async {
    // TODO: 从 Rust FFI 获取实际硬件检测
    // 目前默认选择 NVIDIA，如果不可用再尝试其他设备
    if (_settings.hardwareAcceleration) {
      setState(() {
        _selectedHardwareId = 'nvidia';
      });
    }
  }

  void _showHardwareSelectionDialog(ColorScheme colorScheme) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('选择硬件加速设备'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: _hardwareDevices.map((device) {
              final isSelected = device['id'] == _selectedHardwareId;
              final isEnabled = _settings.hardwareAcceleration;
              return ListTile(
                leading: Icon(
                  device['icon'] == 'speed' ? Icons.speed : Icons.computer,
                  color: isSelected && isEnabled
                      ? colorScheme.primary
                      : colorScheme.onSurface,
                ),
                title: Text(
                  device['name']!,
                  style: TextStyle(
                    color: isEnabled ? colorScheme.onSurface : colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                subtitle: Text(
                  device['id'] == 'cpu' ? '使用 CPU 进行软件编码' : '使用硬件加速编码',
                  style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
                trailing: isSelected
                    ? Icon(Icons.check, color: colorScheme.primary)
                    : null,
                enabled: isEnabled,
                onTap: isEnabled
                    ? () {
                        setState(() {
                          _selectedHardwareId = device['id']!;
                        });
                        Navigator.pop(context);
                      }
                    : null,
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        title: Text(
          '选择输出格式',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Row(
        children: [
          Expanded(
            flex: 2,
            child: _buildFileList(colorScheme),
          ),
          Container(
            width: 1,
            color: colorScheme.outline,
          ),
          Expanded(
            flex: 5,
            child: _buildRightPanel(colorScheme),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
      floatingActionButton: _buildFloatPanel(colorScheme),
    );
  }

  Widget _buildFileList(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '已选文件',
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: widget.files.length,
              itemBuilder: (context, index) {
                final file = widget.files[index];
                final isSelected = index == _selectedFileIndex;
                final fileName = file.path.split(Platform.pathSeparator).last;
                final extension = fileName.split('.').last.toUpperCase();

                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedFileIndex = index);
                    _generateOutputPath();
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colorScheme.primary.withValues(alpha: 0.2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? colorScheme.primary
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.onSurface.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              extension.length > 3
                                  ? extension.substring(0, 3)
                                  : extension,
                              style: TextStyle(
                                color: isSelected 
                                    ? colorScheme.onPrimary 
                                    : colorScheme.onSurface.withValues(alpha: 0.7),
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fileName,
                                style: TextStyle(
                                  color: isSelected
                                      ? colorScheme.onSurface
                                      : colorScheme.onSurface.withValues(alpha: 0.7),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (_fileProgress[file.path]! > 0 &&
                                  _fileProgress[file.path]! < 100)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: LinearProgressIndicator(
                                    value: _fileProgress[file.path]! / 100,
                                    backgroundColor: colorScheme.onSurface.withValues(alpha: 0.1),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      colorScheme.primary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (_fileProgress[file.path] == 100)
                          Icon(
                            Icons.check_circle,
                            color: colorScheme.primary,
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightPanel(ColorScheme colorScheme) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 硬件设备指示
            _buildHardwareIndicator(colorScheme),
            const SizedBox(height: 16),
            Text(
              '输出格式',
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            _buildFormatGrid(colorScheme),
            const SizedBox(height: 32),
            if (_selectedFormat != null) ...[
              Text(
                '参数配置',
                style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              _buildSettingsPanel(colorScheme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHardwareIndicator(ColorScheme colorScheme) {
    return GestureDetector(
      onTap: () => _showHardwareSelectionDialog(colorScheme),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _settings.hardwareAcceleration ? Icons.speed : Icons.computer,
              size: 16,
              color: _settings.hardwareAcceleration
                  ? colorScheme.primary
                  : colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 8),
            Text(
              '硬件: ',
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize: 13,
              ),
            ),
            Text(
              _currentHardwareDevice,
              style: TextStyle(
                color: _settings.hardwareAcceleration
                    ? colorScheme.primary
                    : colorScheme.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatGrid(ColorScheme colorScheme) {
    final currentFile = widget.files[_selectedFileIndex];
    final currentExtension =
        currentFile.path.split('.').last.toLowerCase();

    // 过滤掉源文件格式，但保留 mp4（允许重新编码为不同编码器的 mp4）
    final filteredFormats = _supportedFormats
        .where((f) => f.format != currentExtension || f.format == 'mp4')
        .toList();

    final videoFormats =
        filteredFormats.where((f) => f.isVideo).toList();
    final audioFormats =
        filteredFormats.where((f) => !f.isVideo).toList();

    return Column(
      children: [
        if (videoFormats.isNotEmpty) ...[
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: videoFormats.map((format) {
              return _buildFormatChip(format, colorScheme);
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],
        if (audioFormats.isNotEmpty) ...[
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: audioFormats.map((format) {
              return _buildFormatChip(format, colorScheme);
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildFormatChip(FormatInfo format, ColorScheme colorScheme) {
    final isSelected = _selectedFormat == format.format;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFormat = format.format;
          _settings = ConversionSettings();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outline,
          ),
        ),
        child: Text(
          '.${format.format}',
          style: TextStyle(
            color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsPanel(ColorScheme colorScheme) {
    final outputIsVideo = _selectedFormat != null &&
        _supportedFormats
            .firstWhere((f) => f.format == _selectedFormat)
            .isVideo;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Column(
        children: [
          if (outputIsVideo) ...[
            Text(
              '视频设置',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            _buildSettingRow(colorScheme, '编码器',
              DropdownButton<String>(
                value: _settings.videoCodec,
                items: _videoCodecs
                    .map((codec) => DropdownMenuItem(
                          value: codec,
                          child: Text(codec.toUpperCase()),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _settings.videoCodec = value);
                  }
                },
                style: TextStyle(color: colorScheme.onSurface),
                dropdownColor: colorScheme.surface,
                underline: Container(),
              ),
            ),
            _buildSettingRow(colorScheme, '视频码率',
              DropdownButton<int>(
                value: _settings.videoBitrate,
                items: _videoBitrates
                    .map((bitrate) => DropdownMenuItem(
                          value: bitrate,
                          child: Text(_getBitrateLabel(bitrate, true)),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _settings.videoBitrate = value);
                  }
                },
                style: TextStyle(color: colorScheme.onSurface),
                dropdownColor: colorScheme.surface,
                underline: Container(),
              ),
            ),
            _buildSettingRow(colorScheme, '帧率',
              DropdownButton<int>(
                value: _settings.framerate,
                items: _framerates
                    .map((fps) => DropdownMenuItem(
                          value: fps,
                          child: Text(fps == 0 ? '复制' : '$fps FPS'),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _settings.framerate = value);
                  }
                },
                style: TextStyle(color: colorScheme.onSurface),
                dropdownColor: colorScheme.surface,
                underline: Container(),
              ),
            ),
            _buildSettingRow(colorScheme, '分辨率',
              DropdownButton<String>(
                value: _getResolutionLabel(),
                items: _resolutions
                    .map((res) => DropdownMenuItem(
                          value: res,
                          child: Text(res),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _setResolution(value));
                  }
                },
                style: TextStyle(color: colorScheme.onSurface),
                dropdownColor: colorScheme.surface,
                underline: Container(),
              ),
            ),
            _buildSettingRow(colorScheme, '硬件加速',
              Switch(
                value: _settings.hardwareAcceleration,
                onChanged: (value) {
                  setState(() {
                    _settings.hardwareAcceleration = value;
                  });
                },
                thumbColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return colorScheme.primary;
                  }
                  return null;
                }),
              ),
            ),
            const SizedBox(height: 20),
          ],
          Text(
            '音频设置',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          _buildSettingRow(colorScheme, '音频编码器',
            DropdownButton<String>(
              value: _settings.audioCodec,
              items: _audioCodecs
                  .map((codec) => DropdownMenuItem(
                        value: codec,
                        child: Text(codec.toUpperCase().replaceAll('_', ' ')),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _settings.audioCodec = value);
                }
              },
              style: TextStyle(color: colorScheme.onSurface),
              dropdownColor: colorScheme.surface,
              underline: Container(),
            ),
          ),
          _buildSettingRow(colorScheme, '音频码率',
            DropdownButton<int>(
              value: _settings.audioBitrate,
              items: _audioBitrates
                  .map((bitrate) => DropdownMenuItem(
                        value: bitrate,
                        child: Text(_getBitrateLabel(bitrate, false)),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _settings.audioBitrate = value);
                }
              },
              style: TextStyle(color: colorScheme.onSurface),
              dropdownColor: colorScheme.surface,
              underline: Container(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingRow(ColorScheme colorScheme, String label, Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          ),
          child,
        ],
      ),
    );
  }

  String _getResolutionLabel() {
    if (_settings.resolutionWidth == 0 || _settings.resolutionHeight == 0) {
      return '复制';
    } else if (_settings.resolutionWidth == 1920 && _settings.resolutionHeight == 1080) {
      return '1080p';
    } else if (_settings.resolutionWidth == 1280 && _settings.resolutionHeight == 720) {
      return '720p';
    } else if (_settings.resolutionWidth == 854 && _settings.resolutionHeight == 480) {
      return '480p';
    } else {
      return '360p';
    }
  }

  void _setResolution(String resolution) {
    switch (resolution) {
      case '复制':
        _settings.resolutionWidth = 0;
        _settings.resolutionHeight = 0;
        break;
      case '1080p':
        _settings.resolutionWidth = 1920;
        _settings.resolutionHeight = 1080;
        break;
      case '720p':
        _settings.resolutionWidth = 1280;
        _settings.resolutionHeight = 720;
        break;
      case '480p':
        _settings.resolutionWidth = 854;
        _settings.resolutionHeight = 480;
        break;
      case '360p':
        _settings.resolutionWidth = 640;
        _settings.resolutionHeight = 360;
        break;
    }
  }

  String _getBitrateLabel(int bitrate, bool isVideo) {
    if (bitrate == ConversionSettings.bitrateCopy) return '复制';
    if (bitrate == ConversionSettings.bitrateVBR) return '动态(VBR)';
    return '$bitrate kbps';
  }

  Widget _buildFloatPanel(ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
        border: Border.all(color: colorScheme.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '输出文件夹:',
                  style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _outputPath.isNotEmpty ? _outputPath : '未设置',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_selectedFormat != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '文件名: ${_getOutputFileName()}',
                    style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _selectOutputPath,
            icon: Icon(Icons.folder_open, size: 20),
            color: colorScheme.onSurface.withValues(alpha: 0.7),
            tooltip: '选择输出文件夹',
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
          ),
          ElevatedButton(
            onPressed: _selectedFormat != null && !_isConverting
                ? _startConversion
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              disabledBackgroundColor: colorScheme.onSurface.withValues(alpha: 0.1),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isConverting
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colorScheme.onPrimary,
                      ),
                    ),
                  )
                : Text(
                    '开始转换',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: colorScheme.onPrimary,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _generateOutputPath() async {
    // 默认输出到用户文档目录
    final dir = await getApplicationDocumentsDirectory();
    setState(() {
      _outputPath = dir.path;
    });
  }

  Future<void> _selectOutputPath() async {
    // 选择输出文件夹
    // file_picker 11.0+ 使用静态方法
    String? selectedDirectory = await FilePicker.getDirectoryPath(
      dialogTitle: '选择输出文件夹',
    );

    if (selectedDirectory != null) {
      setState(() {
        _outputPath = selectedDirectory;
      });
    }
  }

  String _getOutputFileName() {
    // 生成输出文件名
    final currentFile = widget.files[_selectedFileIndex];
    final fileName = currentFile.path.split(Platform.pathSeparator).last;
    final nameWithoutExt = fileName.split('.').first;
    final outputFormat = _selectedFormat ?? 'mp4';
    return '$nameWithoutExt.$outputFormat';
  }

  String _getFullOutputPath() {
    // 获取完整的输出文件路径
    return '$_outputPath${Platform.pathSeparator}${_getOutputFileName()}';
  }

  Future<void> _startConversion() async {
    if (_selectedFormat == null) {
      developer.log(
        '转换失败: 未选择输出格式',
        name: 'ConverterPage',
        level: 900, // ERROR level
      );
      return;
    }

    final inputFile = widget.files[_selectedFileIndex];
    final inputPath = inputFile.path;
    final fileName = inputPath.split(Platform.pathSeparator).last;

    // 记录转换开始前的详细信息
    developer.log(
      '========== 开始转换 ==========',
      name: 'ConverterPage',
      level: 500, // INFO level
    );
    developer.log(
      '输入文件: $inputPath',
      name: 'ConverterPage',
    );
    developer.log(
      '文件名: $fileName',
      name: 'ConverterPage',
    );
    developer.log(
      '文件大小: ${_getFileSize(inputFile)}',
      name: 'ConverterPage',
    );
    developer.log(
      '输出格式: $_selectedFormat',
      name: 'ConverterPage',
    );
    developer.log(
      '输出文件夹: $_outputPath',
      name: 'ConverterPage',
    );
    developer.log(
      '输出文件: ${_getOutputFileName()}',
      name: 'ConverterPage',
    );
    developer.log(
      '完整路径: ${_getFullOutputPath()}',
      name: 'ConverterPage',
    );
    developer.log(
      '硬件加速: $_currentHardwareDevice',
      name: 'ConverterPage',
    );
    developer.log(
      '视频编码器: ${_settings.videoCodec}',
      name: 'ConverterPage',
    );
    developer.log(
      '视频码率: ${_settings.videoBitrateDisplay}',
      name: 'ConverterPage',
    );
    developer.log(
      '帧率: ${_settings.framerateDisplay}',
      name: 'ConverterPage',
    );
    developer.log(
      '分辨率: ${_settings.resolutionDisplay}',
      name: 'ConverterPage',
    );
    developer.log(
      '音频编码器: ${_settings.audioCodec}',
      name: 'ConverterPage',
    );
    developer.log(
      '音频码率: ${_settings.audioBitrateDisplay}',
      name: 'ConverterPage',
    );

    // 检查输入文件是否存在
    if (!await inputFile.exists()) {
      developer.log(
        '转换失败: 输入文件不存在 - $inputPath',
        name: 'ConverterPage',
        level: 900,
      );
      _showErrorSnackBar('输入文件不存在');
      return;
    }

    // 检查输出路径是否设置
    if (_outputPath.isEmpty) {
      developer.log(
        '转换失败: 输出路径未设置',
        name: 'ConverterPage',
        level: 900,
      );
      _showErrorSnackBar('请先设置输出路径');
      return;
    }

    setState(() {
      _isConverting = true;
    });

    developer.log(
      '开始执行转换任务...',
      name: 'ConverterPage',
    );

    try {
      // TODO: 调用 Rust FFI 执行实际转换
      // 目前使用模拟进度
      for (int i = 0; i <= 100; i += 5) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (!mounted) {
          developer.log(
            '转换中断: Widget 已卸载',
            name: 'ConverterPage',
            level: 800, // WARNING level
          );
          return;
        }
        setState(() {
          _fileProgress[inputPath] = i.toDouble();
        });
        if (i % 20 == 0) {
          developer.log(
            '转换进度: $i%',
            name: 'ConverterPage',
          );
        }
      }

      if (!mounted) return;

      setState(() {
        _isConverting = false;
        _fileProgress[inputPath] = 100.0;
      });

      developer.log(
        '========== 转换完成 ==========',
        name: 'ConverterPage',
        level: 500,
      );
      developer.log(
        '输出文件: $_outputPath',
        name: 'ConverterPage',
      );
      developer.log(
        '总耗时: 约 ${(100 * 100 / 1000).toStringAsFixed(1)} 秒 (模拟)',
        name: 'ConverterPage',
      );

      if (!mounted) return;
      final colorScheme = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('转换完成!', style: TextStyle(color: colorScheme.onPrimary)),
          backgroundColor: colorScheme.primary,
        ),
      );
    } catch (e, stackTrace) {
      developer.log(
        '========== 转换失败 ==========',
        name: 'ConverterPage',
        level: 900,
      );
      developer.log(
        '错误信息: $e',
        name: 'ConverterPage',
        level: 900,
      );
      developer.log(
        '堆栈跟踪: $stackTrace',
        name: 'ConverterPage',
        level: 900,
      );

      if (!mounted) return;
      setState(() {
        _isConverting = false;
      });
      _showErrorSnackBar('转换失败: $e');
    }
  }

  String _getFileSize(File file) {
    try {
      final bytes = file.lengthSync();
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      if (bytes < 1024 * 1024 * 1024) {
        return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    } catch (e) {
      return '未知';
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: colorScheme.onError)),
        backgroundColor: colorScheme.error,
        duration: const Duration(seconds: 5),
      ),
    );
  }
}
