import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/format_info.dart';
import '../services/conversion_service.dart';
import '../services/ffmpeg_service.dart';
import '../theme/app_colors.dart';
import '../utils/media_utils.dart';

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
  String _outputPath = '';
  final Map<String, double> _fileProgress = {};
  late ConversionSettings _settings;
  List<HardwareAccelerator> _devices = const [
    HardwareAccelerator(id: 'cpu', name: 'CPU'),
  ];
  String _selectedHardwareId = 'cpu';

  static const _videoCodecs = ['h264', 'h265', 'vp9', 'av1'];
  static const _audioCodecs = ['aac', 'mp3', 'opus', 'flac', 'pcm_s16le'];
  static const _videoBitrates = [-1, 0, 500, 1000, 2000, 3000, 5000, 8000, 10000];
  static const _audioBitrates = [-1, 0, 64, 128, 192, 256, 320];
  static const _framerates = [0, 15, 24, 25, 30, 60];
  static const _resolutionMap = {
    '复制': (0, 0),
    '1080p': (1920, 1080),
    '720p': (1280, 720),
    '480p': (854, 480),
    '360p': (640, 360),
  };

  @override
  void initState() {
    super.initState();
    _settings = ConversionSettings();
    for (final f in widget.files) {
      _fileProgress[f.path] = 0;
    }
    _initOutput();
    _detectHardware();
  }

  String get _hardwareLabel {
    if (!_settings.hardwareAcceleration) return 'CPU';
    for (final d in _devices) {
      if (d.id == _selectedHardwareId) return d.name;
    }
    return 'CPU';
  }

  Future<void> _initOutput() async {
    final dir = await getApplicationDocumentsDirectory();
    if (mounted) setState(() => _outputPath = dir.path);
  }

  Future<void> _detectHardware() async {
    try {
      final list = await FfmpegService.detectHardwareAccelerators();
      if (!mounted) return;
      setState(() {
        _devices = list;
        final hw = list.firstWhere(
          (d) => d.id != 'cpu',
          orElse: () => list.first,
        );
        _selectedHardwareId = hw.id;
        _settings.hardwareAcceleration = hw.id != 'cpu';
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('选择输出格式'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 900) {
            return Row(
              children: [
                Expanded(flex: 2, child: _wideFilePanel(scheme)),
                VerticalDivider(width: 1, color: scheme.outline),
                Expanded(flex: 5, child: _settingsPanel(scheme)),
              ],
            );
          }
          return Column(
            children: [
              _narrowFileBar(scheme),
              Expanded(child: _settingsPanel(scheme)),
              _outputBar(scheme),
            ],
          );
        },
      ),
    );
  }

  // ---------- 文件区 ----------

  Widget _wideFilePanel(ColorScheme scheme) {
    return Container(
      color: scheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '已选文件',
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.7),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: widget.files.length,
              itemBuilder: (context, index) =>
                  _fileTile(scheme, index),
            ),
          ),
          _outputBar(scheme),
        ],
      ),
    );
  }

  Widget _fileTile(ColorScheme scheme, int index) {
    final file = widget.files[index];
    final selected = index == _selectedFileIndex;
    final name = fileNameOf(file.path);
    final ext = name.contains('.')
        ? name.split('.').last.toUpperCase()
        : 'FILE';
    final progress = _fileProgress[file.path] ?? 0;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedFileIndex = index);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.selection
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? scheme.primary : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? scheme.primary
                    : scheme.onSurface.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                ext.length > 3 ? ext.substring(0, 3) : ext,
                style: TextStyle(
                  color: selected ? scheme.onPrimary : scheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                  if (progress > 0 && progress < 100)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(value: progress / 100),
                    ),
                ],
              ),
            ),
            if (progress >= 100)
              Icon(Icons.check_circle, color: AppColors.success, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _narrowFileBar(ColorScheme scheme) {
    if (widget.files.isEmpty) return const SizedBox.shrink();

    return Container(
      color: scheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '已选文件',
            style: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.files.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final file = widget.files[index];
                final selected = index == _selectedFileIndex;
                final progress = _fileProgress[file.path] ?? 0;

                return ChoiceChip(
                  selected: selected,
                  selectedColor: scheme.primary,
                  label: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 140),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fileNameOf(file.path),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: selected
                                ? scheme.onPrimary
                                : scheme.onSurface,
                          ),
                        ),
                        if (progress > 0 && progress < 100)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: SizedBox(
                              width: 100,
                              child: LinearProgressIndicator(
                                value: progress / 100,
                                minHeight: 3,
                                valueColor: AlwaysStoppedAnimation(
                                  selected
                                      ? scheme.onPrimary
                                      : scheme.primary,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  onSelected: (_) => setState(() => _selectedFileIndex = index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------- 输出 / 转换 ----------

  Widget _outputBar(ColorScheme scheme) {
    final canStart = _selectedFormat != null &&
        _outputPath.isNotEmpty &&
        !_isConverting;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outline)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _outputPath.isEmpty ? '未设置输出文件夹' : _outputPath,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: _outputPath.isEmpty
                        ? scheme.onSurface.withValues(alpha: 0.5)
                        : scheme.onSurface,
                  ),
                ),
              ),
              IconButton(
                onPressed: _pickOutputDir,
                icon: const Icon(Icons.folder_open, size: 18),
                tooltip: '选择输出文件夹',
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canStart ? _startConversion : null,
              child: _isConverting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      '开始转换',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickOutputDir() async {
    final dir = await FilePicker.getDirectoryPath(dialogTitle: '选择输出文件夹');
    if (dir != null && mounted) setState(() => _outputPath = dir);
  }

  String get _outputFileName {
    final name = fileNameOf(widget.files[_selectedFileIndex].path);
    final base = name.contains('.') ? name.split('.').first : name;
    return '$base.${_selectedFormat ?? 'mp4'}';
  }

  String get _fullOutputPath => p.join(_outputPath, _outputFileName);

  Future<void> _startConversion() async {
    if (_selectedFormat == null) return;

    final input = widget.files[_selectedFileIndex];
    if (!await input.exists()) {
      _toastError('输入文件不存在');
      return;
    }
    if (_outputPath.isEmpty) {
      _toastError('请先设置输出路径');
      return;
    }

    setState(() => _isConverting = true);
    final outputPath = _fullOutputPath;

    try {
      await FfmpegService.convert(
        input.path,
        outputPath,
        _settings,
        (p) {
          if (!mounted) return;
          setState(() => _fileProgress[input.path] = p);
        },
        _selectedHardwareId,
      );

      if (!mounted) return;
      setState(() {
        _isConverting = false;
        _fileProgress[input.path] = 100;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('转换完成!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isConverting = false);
      _toastError('转换失败: $e');
    }
  }

  void _toastError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  // ---------- 格式与参数 ----------

  Widget _settingsPanel(ColorScheme scheme) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _hardwareChip(scheme),
            const SizedBox(height: 16),
            _sectionTitle(scheme, '输出格式'),
            const SizedBox(height: 12),
            _formatChips(scheme),
            if (_selectedFormat != null) ...[
              const SizedBox(height: 24),
              _sectionTitle(scheme, '参数配置'),
              const SizedBox(height: 12),
              _paramCard(scheme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(ColorScheme scheme, String text) => Text(
        text,
        style: TextStyle(
          color: scheme.onSurface.withValues(alpha: 0.7),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      );

  Widget _hardwareChip(ColorScheme scheme) {
    final on = _settings.hardwareAcceleration;
    return GestureDetector(
      onTap: () => _showHardwareDialog(scheme),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: scheme.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              on ? Icons.speed : Icons.computer,
              size: 16,
              color: on ? scheme.primary : scheme.onSurface,
            ),
            const SizedBox(width: 8),
            Text('硬件: ',
                style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.7),
                  fontSize: 13,
                )),
            Text(
              _hardwareLabel,
              style: TextStyle(
                color: on ? scheme.primary : scheme.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }

  void _showHardwareDialog(ColorScheme scheme) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择硬件加速设备'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _devices.map((d) {
            final selected = d.id == _selectedHardwareId;
            final enabled = _settings.hardwareAcceleration;
            return ListTile(
              leading: Icon(
                d.id == 'cpu' ? Icons.computer : Icons.speed,
                color: selected && enabled ? scheme.primary : null,
              ),
              title: Text(d.name),
              subtitle: Text(
                d.id == 'cpu' ? '使用 CPU 进行软件编码' : '使用硬件加速编码',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: selected ? Icon(Icons.check, color: scheme.primary) : null,
              enabled: enabled,
              onTap: enabled
                  ? () {
                      setState(() => _selectedHardwareId = d.id);
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
      ),
    );
  }

  Widget _formatChips(ColorScheme scheme) {
    final currentExt =
        fileNameOf(widget.files[_selectedFileIndex].path).split('.').last.toLowerCase();
    final list = ConversionService.formats
        .where((f) => f.format != currentExt || f.format == 'mp4')
        .toList();

    Widget wrap(List<FormatInfo> items) => Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items.map((f) {
            final selected = _selectedFormat == f.format;
            return GestureDetector(
              onTap: () => setState(() {
                _selectedFormat = f.format;
                _settings = ConversionSettings();
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: selected ? scheme.primary : scheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? scheme.primary : scheme.outline,
                  ),
                ),
                child: Text(
                  '.${f.format}',
                  style: TextStyle(
                    color: selected ? scheme.onPrimary : scheme.onSurface,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 15,
                  ),
                ),
              ),
            );
          }).toList(),
        );

    final videos = list.where((f) => f.isVideo).toList();
    final audios = list.where((f) => !f.isVideo).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (videos.isNotEmpty) ...[wrap(videos), const SizedBox(height: 12)],
        if (audios.isNotEmpty) wrap(audios),
      ],
    );
  }

  Widget _paramCard(ColorScheme scheme) {
    final isVideo = ConversionService.formats
        .firstWhere((f) => f.format == _selectedFormat)
        .isVideo;

    final children = <Widget>[
      if (isVideo) ...[
        Text('视频设置',
            style: TextStyle(
              color: scheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            )),
        const SizedBox(height: 8),
        _row(scheme, '编码器', _dropdown<String>(
          scheme: scheme,
          value: _settings.videoCodec,
          items: _videoCodecs,
          label: (v) => v.toUpperCase(),
          onChanged: (v) => setState(() => _settings.videoCodec = v),
        )),
        _row(scheme, '视频码率', _dropdown<int>(
          scheme: scheme,
          value: _settings.videoBitrate,
          items: _videoBitrates,
          label: _bitrateLabel,
          onChanged: (v) => setState(() => _settings.videoBitrate = v),
        )),
        _row(scheme, '帧率', _dropdown<int>(
          scheme: scheme,
          value: _settings.framerate,
          items: _framerates,
          label: (v) => v == 0 ? '复制' : '$v FPS',
          onChanged: (v) => setState(() => _settings.framerate = v),
        )),
        _row(scheme, '分辨率', _dropdown<String>(
          scheme: scheme,
          value: _resolutionLabel,
          items: _resolutionMap.keys.toList(),
          label: (v) => v,
          onChanged: (v) {
            final size = _resolutionMap[v]!;
            setState(() {
              _settings.resolutionWidth = size.$1;
              _settings.resolutionHeight = size.$2;
            });
          },
        )),
        _row(scheme, '硬件加速', Switch(
          value: _settings.hardwareAcceleration,
          onChanged: (v) =>
              setState(() => _settings.hardwareAcceleration = v),
        )),
        const SizedBox(height: 16),
      ],
      Text('音频设置',
          style: TextStyle(
            color: scheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          )),
      const SizedBox(height: 8),
      _row(scheme, '音频编码器', _dropdown<String>(
        scheme: scheme,
        value: _settings.audioCodec,
        items: _audioCodecs,
        label: (v) => v.toUpperCase().replaceAll('_', ' '),
        onChanged: (v) => setState(() => _settings.audioCodec = v),
      )),
      _row(scheme, '音频码率', _dropdown<int>(
        scheme: scheme,
        value: _settings.audioBitrate,
        items: _audioBitrates,
        label: _bitrateLabel,
        onChanged: (v) => setState(() => _settings.audioBitrate = v),
      )),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(children: children),
    );
  }

  String get _resolutionLabel {
    for (final e in _resolutionMap.entries) {
      if (e.value.$1 == _settings.resolutionWidth &&
          e.value.$2 == _settings.resolutionHeight) {
        return e.key;
      }
    }
    return '复制';
  }

  String _bitrateLabel(int v) {
    if (v == ConversionSettings.bitrateCopy) return '复制';
    if (v == ConversionSettings.bitrateVBR) return '动态(VBR)';
    return '$v kbps';
  }

  Widget _row(ColorScheme scheme, String label, Widget child) {
    final narrow = MediaQuery.sizeOf(context).width < 700;
    final labelText = Text(
      label,
      style: TextStyle(
        color: scheme.onSurface.withValues(alpha: 0.7),
        fontSize: 13,
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: narrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                labelText,
                const SizedBox(height: 4),
                Align(alignment: Alignment.centerRight, child: child),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [Flexible(child: labelText), child],
            ),
    );
  }

  Widget _dropdown<T>({
    required ColorScheme scheme,
    required T value,
    required List<T> items,
    required String Function(T) label,
    required ValueChanged<T> onChanged,
  }) {
    return DropdownButton<T>(
      value: value,
      items: [
        for (final item in items)
          DropdownMenuItem(value: item, child: Text(label(item))),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
      style: TextStyle(color: scheme.onSurface),
      dropdownColor: scheme.surface,
      underline: const SizedBox.shrink(),
    );
  }
}
