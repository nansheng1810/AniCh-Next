import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:xs/src/pages/download/download_manager.dart';
import 'package:xs/src/pages/download/download_settings.dart';
import 'package:xs/src/pages/download/models/download_task.dart';
import 'package:xs/src/utils/utils.dart';

class DownloadPageController extends GetxController
    with StateMixin, GetTickerProviderStateMixin {
  // 导航栏
  final List<Tab> tabs = <Tab>[
    const Tab(
      child: Align(
        alignment: Alignment.center,
        child: Text('正在下载'),
      ),
    ),
    const Tab(
      child: Align(
        alignment: Alignment.center,
        child: Text('下载完成'),
      ),
    )
  ];

  late TabController tabController;
  RxInt tabIndex = 0.obs;

  late final AnimationController animationController;

  // 批量选择
  RxBool selectionMode = false.obs;
  RxSet<String> selectedKeys = <String>{}.obs;

  DownloadManager get manager {
    if (!Get.isRegistered<DownloadManager>()) {
      Get.put(DownloadManager());
    }
    return DownloadManager.instance;
  }

  RxList<DownloadTask> get tasks => manager.tasks;

  List<DownloadTask> get visibleTasks =>
      tabIndex.value == 0 ? manager.activeTasks : manager.completedTasks;

  void pauseTask(DownloadTask task) {
    manager.pause(task);
  }

  void resumeTask(DownloadTask task) {
    manager.resume(task);
  }

  Future<void> cancelTask(DownloadTask task) {
    return manager.cancel(task);
  }

  Future<void> deleteTask(DownloadTask task) {
    return manager.delete(task);
  }

  void playTask(DownloadTask task) {
    Get.toNamed('/vod/${task.bangumiId}', arguments: {
      'id': task.bangumiId,
      'episode': task.episode,
    });
  }

  // ---------- 批量选择 ----------

  bool isSelected(DownloadTask task) => selectedKeys.contains(task.key);

  void enterSelection() {
    selectionMode(true);
  }

  void exitSelection() {
    selectionMode(false);
    selectedKeys.clear();
  }

  void toggleSelection(DownloadTask task) {
    if (selectedKeys.contains(task.key)) {
      selectedKeys.remove(task.key);
    } else {
      selectedKeys.add(task.key);
    }
  }

  void selectAll() {
    selectedKeys.assignAll(visibleTasks.map((e) => e.key));
  }

  List<DownloadTask> get selectedTasks => manager.tasks
      .where((e) => selectedKeys.contains(e.key))
      .toList(growable: false);

  Future<void> deleteSelected() async {
    final items = selectedTasks;
    if (items.isEmpty) {
      SmartDialog.showToast('请先选择任务');
      return;
    }
    final confirm = await Utils.showAlertDialog(
      '将删除 ${items.length} 个任务及其本地文件，是否继续？',
      title: '批量删除',
      confirm: '删除',
    );
    if (!confirm) {
      return;
    }
    await manager.deleteMany(items);
    exitSelection();
  }

  // ---------- 缓存设置 ----------

  int get maxConcurrent => DownloadSettingsStorage.maxConcurrent;

  String get directory => DownloadSettingsStorage.directory;

  bool get notifyOnComplete => DownloadSettingsStorage.notifyOnComplete;

  void setMaxConcurrent(int value) {
    DownloadSettingsStorage.setMaxConcurrent(value);
    manager.onConcurrencyChanged();
    update();
  }

  void setNotifyOnComplete(bool value) {
    DownloadSettingsStorage.setNotifyOnComplete(value);
    update();
  }

  Future<void> pickDirectory() async {
    try {
      final path = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择缓存目录',
      );
      if (path == null || path.isEmpty) {
        return;
      }
      DownloadSettingsStorage.setDirectory(path);
      SmartDialog.showToast('缓存目录已更新，新任务将保存到该目录');
      update();
    } catch (e) {
      SmartDialog.showToast('目录选择失败');
    }
  }

  void resetDirectory() {
    DownloadSettingsStorage.setDirectory('');
    SmartDialog.showToast('已恢复默认缓存目录');
    update();
  }

  void pauseAll() {
    manager.pauseAll();
  }

  void resumeAll() {
    manager.resumeAll();
  }

  Future<void> clearCompleted() async {
    await manager.clearCompleted();
    SmartDialog.showToast('已清空下载完成记录');
  }

  @override
  void onInit() {
    super.onInit();

    tabController =
        TabController(vsync: this, length: tabs.length, initialIndex: 0);
    tabController.addListener(() {
      tabIndex(tabController.index);
      if (selectionMode.value) {
        selectedKeys.clear();
      }
    });

    animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }
}
