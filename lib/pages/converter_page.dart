import 'package:flutter/material.dart';
import 'dart:io';
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
  double _progress = 0.0;
  final Map<String, double> _fileProgress = {};

  late List<FormatInfo> _supportedFormats;

  @override
  void initState() {
    super.initState();
    _supportedFormats = ConversionService.getSupportedFormats();
    for (var file in widget.files) {
      _fileProgress[file.path] = 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D2D3F),
        title: const Text(
          '选择输出格式',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Row(
        children: [
          // 左边：文件列表
          Expanded(
            flex: 2,
            child: _buildFileList(),
          ),
          // 分隔线
          Container(
            width: 1,
            color: const Color(0xFF4A4A6A),
          ),
          // 右边：格式列表
          Expanded(
            flex: 3,
            child: _buildFormatGrid(),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildFileList() {
    return Container(
      color: const Color(0xFF252536),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '已选文件',
              style: TextStyle(
                color: Color(0xFF9CA3AF),
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
                  onTap: () => setState(() => _selectedFileIndex = index),
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF7C3AED).withValues(alpha: 0.2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF7C3AED)
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
                                ? const Color(0xFF7C3AED)
                                : const Color(0xFF3D3D5C),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              extension.length > 3
                                  ? extension.substring(0, 3)
                                  : extension,
                              style: TextStyle(
                                color: Colors.white,
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
                                      ? Colors.white
                                      : const Color(0xFF9CA3AF),
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
                                    backgroundColor: const Color(0xFF3D3D5C),
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                      Color(0xFF7C3AED),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (_fileProgress[file.path] == 100)
                          const Icon(
                            Icons.check_circle,
                            color: Color(0xFF10B981),
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

  Widget _buildFormatGrid() {
    final currentFile = widget.files[_selectedFileIndex];
    final currentExtension =
        currentFile.path.split('.').last.toLowerCase();
    final isVideoFile = _isVideoFile(currentExtension);

    final filteredFormats = _supportedFormats
        .where((f) =>
            f.is_video == isVideoFile && f.format != currentExtension)
        .toList();

    // 按视频/音频分组
    final videoFormats =
        filteredFormats.where((f) => f.is_video).toList();
    final audioFormats =
        filteredFormats.where((f) => !f.is_video).toList();

    return Container(
      color: const Color(0xFF1E1E2E),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isVideoFile && videoFormats.isNotEmpty) ...[
              const Text(
                '视频格式',
                style: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: videoFormats.map((format) {
                  return _buildFormatChip(format);
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],
            if (audioFormats.isNotEmpty) ...[
              Text(
                isVideoFile ? '音频格式 (提取音频)' : '音频格式',
                style: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: audioFormats.map((format) {
                  return _buildFormatChip(format);
                }).toList(),
              ),
            ],
            if (!isVideoFile && videoFormats.isEmpty) ...[
              const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.music_off,
                      size: 64,
                      color: Color(0xFF4A4A6A),
                    ),
                    SizedBox(height: 16),
                    Text(
                      '当前文件不支持转换为视频格式',
                      style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFormatChip(FormatInfo format) {
    final isSelected = _selectedFormat == format.format;

    return GestureDetector(
      onTap: () => setState(() => _selectedFormat = format.format),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF7C3AED)
              : const Color(0xFF2D2D3F),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF7C3AED)
                : const Color(0xFF4A4A6A),
          ),
        ),
        child: Column(
          children: [
            Text(
              format.format.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              format.name.replaceAll(' Video', '').replaceAll(' Audio', ''),
              style: const TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF2D2D3F),
        border: Border(
          top: BorderSide(color: Color(0xFF4A4A6A)),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (_selectedFormat != null)
              Expanded(
                child: Text(
                  '输出格式: ${_selectedFormat!.toUpperCase()}',
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 14,
                  ),
                ),
              )
            else
              const Expanded(
                child: Text(
                  '请选择输出格式',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 14,
                  ),
                ),
              ),
            const SizedBox(width: 16),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _selectedFormat != null && !_isConverting
                    ? _startConversion
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  disabledBackgroundColor: const Color(0xFF3D3D5C),
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isConverting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        '开始转换',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isVideoFile(String extension) {
    const videoExtensions = [
      'mp4', 'avi', 'mkv', 'mov', 'webm', 'wmv', 'flv', 'gif'
    ];
    return videoExtensions.contains(extension);
  }

  Future<void> _startConversion() async {
    if (_selectedFormat == null) return;

    setState(() {
      _isConverting = true;
      _progress = 0.0;
    });

    // TODO: 调用 Rust FFI 进行转换
    // final result = await ConversionService.convert(
    //   inputPath: widget.files[_selectedFileIndex].path,
    //   outputFormat: _selectedFormat!,
    // );

    // 模拟转换过程
    for (int i = 0; i <= 100; i += 5) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      setState(() {
        _progress = i.toDouble();
        _fileProgress[widget.files[_selectedFileIndex].path] = i.toDouble();
      });
    }

    if (!mounted) return;
    setState(() {
      _isConverting = false;
      _fileProgress[widget.files[_selectedFileIndex].path] = 100.0;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('转换完成!'),
        backgroundColor: Color(0xFF10B981),
      ),
    );
  }
}
