import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:xs/src/pages/download/download_manager.dart';
import 'package:xs/src/pages/download/models/download_task.dart';

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

  DownloadManager get manager {
    if (!Get.isRegistered<DownloadManager>()) {
      Get.put(DownloadManager());
    }
    return DownloadManager.instance;
  }

  RxList<DownloadTask> get tasks => manager.tasks;

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

  @override
  void onInit() {
    super.onInit();

    tabController =
        TabController(vsync: this, length: tabs.length, initialIndex: 0);
    tabController.addListener(() {
      tabIndex(tabController.index);
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
