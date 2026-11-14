import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:xs/src/pages/download/controller.dart';
import 'package:xs/src/pages/download/models/download_task.dart';
import 'package:xs/src/widgets/drag_to_move_bar.dart';
import 'package:xs/src/widgets/multi_sliver_compat/sliver_persistent_header_delegate.dart';
import 'package:xs/src/widgets/navbar.dart';

class DownloadPage extends StatelessWidget {
  const DownloadPage({super.key});

  @override
  Widget build(BuildContext context) {
    RxInt scrollHeight = 0.obs;
    RxBool scrollStatus = true.obs;
    RxDouble maxShrinkOpacity = 1.0.obs;
    return GetBuilder(
        init: DownloadPageController(),
        builder: (controller) {
          return Scaffold(
            extendBody: true,
            body: SafeArea(
              top: true,
              bottom: false,
              maintainBottomViewPadding: false,
              child: DefaultTabController(
                length: controller.tabs.length,
                child: NestedScrollView(
                  floatHeaderSlivers: true,
                  body: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      final pixels = notification.metrics.pixels.toInt();
                      if ((pixels - scrollHeight.value).abs() >= 50) {
                        final lastScrollStatus = scrollStatus.value;
                        if (pixels > scrollHeight.value) {
                          if (notification.depth > 0 &&
                              lastScrollStatus != false) {
                            scrollStatus(false);
                            controller.animationController.forward();
                            debugPrint('向下');
                          }
                        } else if (pixels < scrollHeight.value) {
                          if (lastScrollStatus != true) {
                            scrollStatus(true);
                            controller.animationController.reverse();
                            debugPrint('向上');
                          }
                        }
                        scrollHeight(pixels);
                      }
                      return false;
                    },
                    child: TabBarView(
                      controller: controller.tabController,
                      children: [
                        buildTaskList(context, controller, active: true),
                        buildTaskList(context, controller, active: false),
                      ],
                    ),
                  ),
                  headerSliverBuilder: (context, innerBoxIsScrolled) {
                    return [
                      SliverPersistentHeader(
                          floating: true,
                          delegate: CustomSliverPersistentHeaderDelegate(
                            onMaxOffset: (offset) {
                              maxShrinkOpacity(1 - offset);
                            },
                            child: Material(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              child: CustomDragToMoveArea(
                                child: Obx(
                                  () {
                                    return Opacity(
                                      opacity: maxShrinkOpacity.value,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 5),
                                        constraints:
                                            const BoxConstraints(minHeight: 50),
                                        color: Theme.of(context)
                                            .scaffoldBackgroundColor,
                                        child: Row(
                                          children: [
                                            const Expanded(
                                              child: Text(
                                                '离线缓存',
                                                style: TextStyle(fontSize: 16),
                                              ),
                                            ),
                                            closeWindowButton(
                                                positioned: false,
                                                padding: const EdgeInsets.only(
                                                    left: 10)),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          )),
                      SliverOverlapAbsorber(
                        handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                            context),
                        sliver: SliverPersistentHeader(
                            pinned: true,
                            delegate: CustomSliverPersistentHeaderDelegate(
                              maxExtent: 40,
                              minExtent: 40,
                              child: PreferredSize(
                                preferredSize: const Size.fromHeight(40),
                                child: Material(
                                  color:
                                      Theme.of(context).scaffoldBackgroundColor,
                                  child: CustomDragToMoveArea(
                                    child: TabBar(
                                      controller: controller.tabController,
                                      tabAlignment: TabAlignment.start,
                                      isScrollable: true,
                                      indicatorSize: TabBarIndicatorSize.label,
                                      dividerColor: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainer,
                                      tabs: controller.tabs,
                                    ),
                                  ),
                                ),
                              ),
                            )),
                      ),
                    ];
                  },
                ),
              ),
            ),
            bottomNavigationBar: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                SlideTransition(
                  position: Tween(begin: Offset.zero, end: const Offset(0, 1.0))
                      .animate(controller.animationController),
                  child: NavBar(
                    children: [
                      NavItem(
                          icon: Icons.arrow_back,
                          title: '返回',
                          onTap: () => Get.back()),
                    ],
                  ),
                )
              ],
            ),
          );
        });
  }

  Widget buildTaskList(
    BuildContext context,
    DownloadPageController controller, {
    required bool active,
  }) {
    return Obx(() {
      final tasks = active
          ? controller.manager.activeTasks
          : controller.manager.completedTasks;
      if (tasks.isEmpty) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 120),
            Center(
              child: Text(
                active ? '暂无下载任务' : '暂无已完成缓存',
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          ],
        );
      }
      return ListView.separated(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 80,
        ),
        itemCount: tasks.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          return buildTaskItem(
            context,
            controller,
            tasks[index],
            active: active,
          );
        },
      );
    });
  }

  Widget buildTaskItem(
    BuildContext context,
    DownloadPageController controller,
    DownloadTask task, {
    required bool active,
  }) {
    final theme = Theme.of(context);
    final statusText = switch (task.status) {
      DownloadStatus.downloading =>
        '${(task.progress * 100).toStringAsFixed(0)}%  ${task.sizeText}',
      DownloadStatus.paused => '已暂停',
      DownloadStatus.failed => '下载失败',
      DownloadStatus.completed => task.sizeText,
    };
    return InkWell(
      onTap: active ? null : () => controller.playTask(task),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 96,
                height: 54,
                child: task.image.isNotEmpty
                    ? Image.network(
                        task.image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            buildImagePlaceholder(theme),
                      )
                    : buildImagePlaceholder(theme),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '第${task.episode}集 ${task.episodeTitle}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.grey),
                  ),
                  if (active && task.status == DownloadStatus.downloading) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: task.total > 0 ? task.progress : null,
                        minHeight: 4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    statusText,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            if (active) ...[
              IconButton(
                tooltip:
                    task.status == DownloadStatus.downloading ? '暂停' : '继续',
                onPressed: () {
                  if (task.status == DownloadStatus.downloading) {
                    controller.pauseTask(task);
                  } else {
                    controller.resumeTask(task);
                  }
                },
                icon: Icon(task.status == DownloadStatus.downloading
                    ? Icons.pause
                    : Icons.play_arrow),
              ),
              IconButton(
                tooltip: '取消',
                onPressed: () => controller.cancelTask(task),
                icon: const Icon(Icons.close),
              ),
            ] else ...[
              IconButton(
                tooltip: '播放',
                onPressed: () => controller.playTask(task),
                icon: const Icon(Icons.play_circle_outline),
              ),
              IconButton(
                tooltip: '删除',
                onPressed: () => controller.deleteTask(task),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget buildImagePlaceholder(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainer,
      child: const Icon(Icons.movie, color: Colors.grey),
    );
  }
}
