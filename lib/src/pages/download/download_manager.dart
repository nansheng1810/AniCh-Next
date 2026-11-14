import 'dart:io';

import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:xs/src/pages/download/models/download_task.dart';

/// 离线缓存管理器：负责任务持久化、下载、暂停/继续与本地文件清理。
class DownloadManager extends GetxController {
  static DownloadManager get instance => Get.find<DownloadManager>();

  static const String _storageKey = 'downloadTasks';

  final GetStorage _box = GetStorage();
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(minutes: 10),
  ));

  final RxList<DownloadTask> tasks = <DownloadTask>[].obs;
  final Map<String, CancelToken> _cancelTokens = {};

  bool _initialized = false;

  List<DownloadTask> get activeTasks =>
      tasks.where((e) => !e.isCompleted).toList();

  List<DownloadTask> get completedTasks =>
      tasks.where((e) => e.isCompleted).toList();

  Future<void> init() async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    final raw = _box.read(_storageKey);
    if (raw is List) {
      final restored = raw
          .whereType<Map>()
          .map((e) => DownloadTask.fromJson(Map<String, dynamic>.from(e)))
          .map((e) => e.status == DownloadStatus.downloading
              ? e.copyWith(status: DownloadStatus.paused)
              : e)
          .toList();
      tasks.assignAll(restored);
      _save();
    }
  }

  /// 查找可用的本地缓存文件；优先匹配当前线路。
  String? localPath(int bangumiId, int episode, [int lineIndex = 0]) {
    final matched = tasks.where((e) =>
        e.bangumiId == bangumiId &&
        e.episode == episode &&
        e.isCompleted &&
        File(e.filePath).existsSync());
    if (matched.isEmpty) {
      return null;
    }
    final sameLine = matched.where((e) => e.lineIndex == lineIndex);
    return sameLine.isNotEmpty ? sameLine.first.filePath : matched.first.filePath;
  }

  Future<bool> addTask({
    required int bangumiId,
    required int episode,
    required String title,
    required String episodeTitle,
    required String image,
    required int lineIndex,
    required String url,
  }) async {
    final exists = tasks.any(
        (e) => e.bangumiId == bangumiId && e.episode == episode);
    if (exists) {
      return false;
    }
    final directory = await getApplicationSupportDirectory();
    final downloadDir =
        Directory('${directory.path}${Platform.pathSeparator}downloads');
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }
    final fileName =
        '${bangumiId}_${episode}_$lineIndex.${_extensionFromUrl(url)}';
    final task = DownloadTask(
      bangumiId: bangumiId,
      episode: episode,
      title: title,
      episodeTitle: episodeTitle,
      image: image,
      lineIndex: lineIndex,
      url: url,
      filePath: '${downloadDir.path}${Platform.pathSeparator}$fileName',
      received: 0,
      total: 0,
      status: DownloadStatus.downloading,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    tasks.add(task);
    _save();
    _start(task);
    return true;
  }

  void pause(DownloadTask task) {
    _cancelTokens[task.key]?.cancel();
    _update(task.key, status: DownloadStatus.paused);
    _save();
  }

  void resume(DownloadTask task) {
    final index = tasks.indexWhere((e) => e.key == task.key);
    if (index == -1) {
      return;
    }
    final current = tasks[index];
    if (current.status == DownloadStatus.downloading || current.isCompleted) {
      return;
    }
    tasks[index] = current.copyWith(
      status: DownloadStatus.downloading,
      received: 0,
      total: 0,
    );
    _save();
    _start(tasks[index]);
  }

  Future<void> cancel(DownloadTask task) async {
    _cancelTokens[task.key]?.cancel();
    _cancelTokens.remove(task.key);
    tasks.removeWhere((e) => e.key == task.key);
    _save();
    await _deleteFile(task.filePath);
  }

  Future<void> delete(DownloadTask task) async {
    tasks.removeWhere((e) => e.key == task.key);
    _save();
    await _deleteFile(task.filePath);
  }

  Future<void> _start(DownloadTask task) async {
    final cancelToken = CancelToken();
    _cancelTokens[task.key] = cancelToken;
    try {
      await _dio.download(
        task.url,
        task.filePath,
        cancelToken: cancelToken,
        deleteOnError: true,
        onReceiveProgress: (received, total) {
          final index = tasks.indexWhere((e) => e.key == task.key);
          if (index == -1) {
            return;
          }
          tasks[index] = tasks[index].copyWith(
            received: received,
            total: total > 0 ? total : tasks[index].total,
          );
        },
      );
      final length = File(task.filePath).lengthSync();
      _update(task.key,
          status: DownloadStatus.completed, received: length, total: length);
      _save();
    } on DioException catch (e) {
      if (!CancelToken.isCancel(e)) {
        _update(task.key, status: DownloadStatus.failed);
        _save();
      }
    } catch (_) {
      _update(task.key, status: DownloadStatus.failed);
      _save();
    } finally {
      if (_cancelTokens[task.key] == cancelToken) {
        _cancelTokens.remove(task.key);
      }
    }
  }

  void _update(String key,
      {DownloadStatus? status, int? received, int? total}) {
    final index = tasks.indexWhere((e) => e.key == key);
    if (index == -1) {
      return;
    }
    tasks[index] = tasks[index].copyWith(
      status: status,
      received: received,
      total: total,
    );
  }

  void _save() {
    _box.write(_storageKey, tasks.map((e) => e.toJson()).toList());
  }

  Future<void> _deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // 文件已被删除或无法访问时忽略
    }
  }

  String _extensionFromUrl(String url) {
    try {
      final path = Uri.parse(url).path;
      final name = path.split('/').last;
      if (name.contains('.')) {
        final ext = name.split('.').last.toLowerCase();
        if (RegExp(r'^[a-z0-9]{1,5}$').hasMatch(ext)) {
          return ext;
        }
      }
    } catch (_) {
      // 解析失败时使用默认扩展名
    }
    return 'mp4';
  }
}
