import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:xs/src/pages/download/download_settings.dart';
import 'package:xs/src/pages/download/models/download_task.dart';
import 'package:xs/src/utils/network.dart';
import 'package:xs/src/utils/notification.dart';

/// 离线缓存管理器：负责任务持久化、并发队列、暂停/继续与本地文件清理。
class DownloadManager extends GetxController {
  static DownloadManager get instance => Get.find<DownloadManager>();

  static const String _storageKey = 'downloadTasks';

  final GetStorage _box = GetStorage();
  final Dio _dio = _createDio();

  static Dio _createDio() {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(minutes: 10),
    ));
    applyNetworkSettings(dio);
    return dio;
  }

  final RxList<DownloadTask> tasks = <DownloadTask>[].obs;
  final Map<String, CancelToken> _cancelTokens = {};

  bool _initialized = false;

  int get maxConcurrent => DownloadSettingsStorage.maxConcurrent;

  int get activeCount =>
      tasks.where((e) => e.status == DownloadStatus.downloading).length;

  int get queuedCount =>
      tasks.where((e) => e.status == DownloadStatus.queued).length;

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
    _pump();
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
    return sameLine.isNotEmpty
        ? sameLine.first.filePath
        : matched.first.filePath;
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
    final exists =
        tasks.any((e) => e.bangumiId == bangumiId && e.episode == episode);
    if (exists) {
      return false;
    }
    final downloadDir = await resolveDirectory();
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
      status: DownloadStatus.queued,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    tasks.add(task);
    _save();
    _pump();
    return true;
  }

  /// 解析缓存目录：优先使用用户自定义目录，不可用时回退到默认目录。
  Future<Directory> resolveDirectory() async {
    final custom = DownloadSettingsStorage.directory.trim();
    if (custom.isNotEmpty) {
      try {
        final dir = Directory(custom);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return dir;
      } catch (_) {
        DownloadSettingsStorage.setDirectory('');
        SmartDialog.showToast('自定义缓存目录不可用，已恢复默认目录');
      }
    }
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}downloads');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  void pause(DownloadTask task) {
    _cancelTokens[task.key]?.cancel();
    _update(task.key, status: DownloadStatus.paused, received: task.received);
    _save();
    _pump();
  }

  void resume(DownloadTask task) {
    final index = tasks.indexWhere((e) => e.key == task.key);
    if (index == -1) {
      return;
    }
    final current = tasks[index];
    if (current.status == DownloadStatus.downloading ||
        current.status == DownloadStatus.queued ||
        current.isCompleted) {
      return;
    }
    tasks[index] = current.copyWith(
      status: DownloadStatus.queued,
      received: 0,
      total: 0,
    );
    _save();
    _pump();
  }

  /// 暂停全部进行中的任务。
  void pauseAll() {
    for (final task in tasks
        .where((e) =>
            e.status == DownloadStatus.downloading ||
            e.status == DownloadStatus.queued)
        .toList()) {
      if (task.status == DownloadStatus.downloading) {
        pause(task);
      } else {
        _update(task.key, status: DownloadStatus.paused);
      }
    }
    _save();
  }

  /// 继续全部被暂停/失败的任务。
  void resumeAll() {
    for (final task in tasks
        .where((e) =>
            e.status == DownloadStatus.paused ||
            e.status == DownloadStatus.failed)
        .toList()) {
      resume(task);
    }
  }

  Future<void> cancel(DownloadTask task) async {
    _cancelTokens[task.key]?.cancel();
    _cancelTokens.remove(task.key);
    tasks.removeWhere((e) => e.key == task.key);
    _save();
    await _deleteFile(task.filePath);
    _pump();
  }

  Future<void> delete(DownloadTask task) async {
    _cancelTokens[task.key]?.cancel();
    _cancelTokens.remove(task.key);
    tasks.removeWhere((e) => e.key == task.key);
    _save();
    await _deleteFile(task.filePath);
    _pump();
  }

  /// 批量删除任务与本地文件。
  Future<void> deleteMany(Iterable<DownloadTask> items) async {
    for (final task in items.toList()) {
      _cancelTokens[task.key]?.cancel();
      _cancelTokens.remove(task.key);
      tasks.removeWhere((e) => e.key == task.key);
      await _deleteFile(task.filePath);
    }
    _save();
    _pump();
  }

  Future<void> clearCompleted() async {
    await deleteMany(completedTasks.toList());
  }

  /// 设置变更后重新排空队列。
  void onConcurrencyChanged() {
    _pump();
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
      if (!tasks.any((e) => e.key == task.key)) {
        return;
      }
      final length = File(task.filePath).lengthSync();
      _update(task.key,
          status: DownloadStatus.completed, received: length, total: length);
      _save();
      if (DownloadSettingsStorage.notifyOnComplete) {
        NotificationService.show(
          '离线缓存完成',
          '${task.title} 第${task.episode}集',
        );
      }
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
      _pump();
    }
  }

  /// 在并发上限内启动排队中的任务。
  void _pump() {
    var changed = false;
    while (activeCount < maxConcurrent) {
      final index = tasks.indexWhere((e) => e.status == DownloadStatus.queued);
      if (index == -1) {
        break;
      }
      tasks[index] = tasks[index].copyWith(
        status: DownloadStatus.downloading,
        received: 0,
        total: 0,
      );
      changed = true;
      _start(tasks[index]);
    }
    if (changed) {
      _save();
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
