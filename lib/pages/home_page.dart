import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/media_utils.dart';
// desktop_drop 仅桌面端
import 'package:desktop_drop/desktop_drop.dart' if (dart.library.html) '';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isDragging = false;
  List<File> _selectedFiles = [];

  bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/logo.png',
                width: 28,
                height: 28,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Icon(Icons.swap_horiz, size: 22, color: scheme.primary),
              ),
            ),
            const SizedBox(width: 8),
            const Text('转转喵'),
          ],
        ),
      ),
      body: Center(
        child: _selectedFiles.isEmpty
            ? _dropZone(scheme)
            : _fileListView(scheme),
      ),
    );
  }

  Widget _dropZone(ColorScheme scheme) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 400;

    Widget content = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _pickFiles,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: (size.width - 48).clamp(280.0, 500.0),
          height: (size.height * 0.55).clamp(240.0, 350.0),
          decoration: BoxDecoration(
            color: _isDragging ? AppColors.selection : scheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isDragging ? AppColors.focusBorder : scheme.outlineVariant,
              width: _isDragging ? 2 : 1,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isDragging ? Icons.file_download : Icons.swap_horiz,
                size: compact ? 56 : 80,
                color: AppColors.accentBlue,
              ),
              const SizedBox(height: 20),
              Text(
                _isDragging
                    ? '松开以选择文件'
                    : _isDesktop
                        ? '点击选择或拖放媒体文件'
                        : '点击选择媒体文件',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: compact ? 15 : 18,
                  color: _isDragging ? AppColors.accentBlue : AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '支持视频: MP4, AVI, MKV, MOV, WebM\n支持音频: MP3, WAV, AAC, FLAC, OGG',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textComment,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!_isDesktop) return content;

    return DropTarget(
      onDragDone: (details) {
        final files = details.files
            .map((f) => File(f.path))
            .where((f) => isMediaPath(f.path))
            .toList();
        setState(() => _selectedFiles = files);
        if (files.isNotEmpty) _navigateToConverter();
      },
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      child: content,
    );
  }

  Widget _fileListView(ColorScheme scheme) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _pickFiles,
                icon: const Icon(Icons.add),
                label: const Text('添加更多文件'),
              ),
              OutlinedButton.icon(
                onPressed: () => setState(_selectedFiles.clear),
                icon: const Icon(Icons.clear_all),
                label: const Text('清空'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: _selectedFiles.length,
            itemBuilder: (context, index) =>
                _fileCard(_selectedFiles[index], scheme),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed:
                  _selectedFiles.isEmpty ? null : _navigateToConverter,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                '开始转换',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _fileCard(File file, ColorScheme scheme) {
    final name = fileNameOf(file.path);
    final ext = name.contains('.') ? name.split('.').last.toUpperCase() : 'FILE';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outline),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.selection,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              ext,
              style: TextStyle(
                color: scheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  formatFileSize(file),
                  style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close,
              color: scheme.onSurface.withValues(alpha: 0.5),
            ),
            onPressed: () => setState(() => _selectedFiles.remove(file)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: kMediaExtensions.toList(),
      allowMultiple: true,
    );
    if (result == null) return;

    setState(() {
      _selectedFiles = result.paths
          .whereType<String>()
          .map(File.new)
          .toList();
    });
    if (_selectedFiles.isNotEmpty) _navigateToConverter();
  }

  Future<void> _navigateToConverter() async {
    await Navigator.pushNamed(
      context,
      '/converter',
      arguments: _selectedFiles,
    );
    if (mounted) setState(() {});
  }
}
