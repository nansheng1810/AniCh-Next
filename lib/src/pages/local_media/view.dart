import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:xs/src/pages/local_media/player.dart';
import 'package:xs/src/pages/local_media/storage.dart';
import 'package:xs/src/utils/app_style.dart';
import 'package:xs/src/utils/desktop.dart';
import 'package:xs/src/widgets/drag_to_move_bar.dart';
import 'package:xs/src/widgets/settings/settings_card.dart';

/// 本地媒体库：扫描本地文件夹，按进度续播。
class LocalMediaPage extends StatefulWidget {
  const LocalMediaPage({super.key});

  @override
  State<LocalMediaPage> createState() => _LocalMediaPageState();
}

class _LocalMediaPageState extends State<LocalMediaPage> {
  final TextEditingController _searchController = TextEditingController();

  List<String> _folders = [];
  List<LocalVideo> _videos = [];
  Map<String, LocalPlayProgress> _progress = {};
  bool _loading = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _folders = LocalMediaStorage.folders;
    _progress = LocalMediaStorage.progress;
    _refresh();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _basename(String path) {
    final index = path.lastIndexOf(RegExp(r'[\\/]'));
    return index < 0 ? path : path.substring(index + 1);
  }

  String _extension(String path) {
    final name = _basename(path);
    final dot = name.lastIndexOf('.');
    if (dot < 0) {
      return '';
    }
    return name.substring(dot + 1).toLowerCase();
  }

  Future<void> _refresh() async {
    if (_loading) {
      return;
    }
    setState(() => _loading = true);
    final videos = <LocalVideo>[];
    final seen = <String>{};
    for (final folder in _folders) {
      final directory = Directory(folder);
      try {
        if (!await directory.exists()) {
          continue;
        }
        await for (final entity in directory.list(
          recursive: true,
          followLinks: false,
        )) {
          if (entity is! File) {
            continue;
          }
          if (!LocalMediaStorage.videoExtensions.contains(
            _extension(entity.path),
          )) {
            continue;
          }
          if (!seen.add(entity.path)) {
            continue;
          }
          try {
            final stat = await entity.stat();
            videos.add(
              LocalVideo(
                path: entity.path,
                name: _basename(entity.path),
                folder: folder,
                size: stat.size,
              ),
            );
          } catch (_) {
            // 忽略无权限或已被删除的文件
          }
        }
      } catch (_) {
        // 文件夹不存在或无权限
      }
    }
    videos.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (!mounted) {
      return;
    }
    setState(() {
      _videos = videos;
      _progress = LocalMediaStorage.progress;
      _loading = false;
    });
  }

  Future<void> _addFolder() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择视频文件夹',
    );
    if (path == null || path.isEmpty) {
      return;
    }
    LocalMediaStorage.addFolder(path);
    setState(() => _folders = LocalMediaStorage.folders);
    await _refresh();
  }

  void _removeFolder(String folder) {
    LocalMediaStorage.removeFolder(folder);
    setState(() {
      _folders = LocalMediaStorage.folders;
      _videos = _videos.where((video) => video.folder != folder).toList();
    });
    SmartDialog.showToast('已移除文件夹，不会删除本地文件');
  }

  Future<void> _play(LocalVideo video) async {
    await Get.to(
      () => LocalVideoPage(path: video.path, title: video.name),
    );
    if (mounted) {
      setState(() => _progress = LocalMediaStorage.progress);
    }
  }

  List<LocalVideo> get _continueList {
    final list = _videos
        .where((video) => _progress[video.path]?.hasProgress ?? false)
        .toList();
    list.sort((a, b) {
      final aTime = _progress[a.path]?.updatedAt ?? 0;
      final bTime = _progress[b.path]?.updatedAt ?? 0;
      return bTime.compareTo(aTime);
    });
    return list.take(6).toList();
  }

  List<LocalVideo> get _filteredVideos {
    if (_query.trim().isEmpty) {
      return _videos;
    }
    final keyword = _query.trim().toLowerCase();
    return _videos
        .where((video) => video.name.toLowerCase().contains(keyword))
        .toList();
  }

  void _clearProgress(LocalVideo video) {
    LocalMediaStorage.clearProgress(video.path);
    setState(() => _progress = LocalMediaStorage.progress);
  }

  @override
  Widget build(BuildContext context) {
    final continueList = _continueList;
    final filtered = _filteredVideos;
    return Scaffold(
      body: DesktopCentered(
        child: SafeArea(
          top: true,
          bottom: false,
          child: Column(
            children: [
              const CustomDragToMoveArea(
                child: SizedBox(height: 24, width: double.infinity),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 4),
                    Text('本地媒体库', style: Get.textTheme.titleMedium),
                    const Spacer(),
                    IconButton(
                      tooltip: '添加文件夹',
                      onPressed: _addFolder,
                      icon: const Icon(Icons.create_new_folder_outlined),
                    ),
                    _loading
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            tooltip: '重新扫描',
                            onPressed: _refresh,
                            icon: const Icon(Icons.refresh),
                          ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: AppStyle.edgeInsetsA12,
                  children: [
                    _sectionTitle('监控文件夹'),
                    SettingsCard(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: _folders.isEmpty
                            ? Column(
                                children: [
                                  const SizedBox(height: 16),
                                  Icon(
                                    Icons.folder_open,
                                    size: 40,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text('还没有添加文件夹'),
                                  const SizedBox(height: 4),
                                  const Text(
                                    '添加存放动画、电影的文件夹，AniCh 会递归扫描其中的视频',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  FilledButton.tonalIcon(
                                    onPressed: _addFolder,
                                    icon: const Icon(Icons.add, size: 18),
                                    label: const Text('添加文件夹'),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              )
                            : Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _folders.map((folder) {
                                  return InputChip(
                                    avatar: const Icon(Icons.folder, size: 16),
                                    label: Text(
                                      folder,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onDeleted: () => _removeFolder(folder),
                                  );
                                }).toList(),
                              ),
                      ),
                    ),
                    if (_videos.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 4),
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            isDense: true,
                            hintText: '搜索文件名',
                            prefixIcon: Icon(Icons.search, size: 20),
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) => setState(() => _query = value),
                        ),
                      ),
                      if (continueList.isNotEmpty) ...[
                        _sectionTitle('继续观看'),
                        SettingsCard(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (var i = 0; i < continueList.length; i++) ...[
                                _videoTile(continueList[i], showProgress: true),
                                if (i != continueList.length - 1)
                                  AppStyle.divider,
                              ],
                            ],
                          ),
                        ),
                      ],
                      _sectionTitle('全部视频（${filtered.length}）'),
                      if (filtered.isEmpty)
                        const SettingsCard(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                              child: Text(
                                '没有匹配的视频',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          ),
                        )
                      else
                        SettingsCard(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (var i = 0; i < filtered.length; i++) ...[
                                _videoTile(filtered[i]),
                                if (i != filtered.length - 1) AppStyle.divider,
                              ],
                            ],
                          ),
                        ),
                    ] else if (_folders.isNotEmpty && !_loading) ...[
                      const SizedBox(height: 40),
                      const Center(
                        child: Text(
                          '这些文件夹里还没有找到视频文件',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _videoTile(LocalVideo video, {bool showProgress = false}) {
    final progress = _progress[video.path];
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: Icon(
        showProgress ? Icons.play_circle_outline : Icons.movie_outlined,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(
        video.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        showProgress && progress != null
            ? '已观看 ${(progress.ratio * 100).round()}% · ${video.sizeText}'
            : video.sizeText,
        style: const TextStyle(fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showProgress && progress != null)
            SizedBox(
              width: 48,
              child: LinearProgressIndicator(
                value: progress.ratio,
                minHeight: 3,
              ),
            ),
          PopupMenuButton<String>(
            tooltip: '更多',
            icon: const Icon(Icons.more_vert, size: 20),
            onSelected: (value) {
              if (value == 'clear') {
                _clearProgress(video);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'clear',
                child: Text('清除播放进度'),
              ),
            ],
          ),
        ],
      ),
      onTap: () => _play(video),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: AppStyle.edgeInsetsA12.copyWith(top: 12),
      child: Text(title, style: Get.textTheme.titleSmall),
    );
  }
}
