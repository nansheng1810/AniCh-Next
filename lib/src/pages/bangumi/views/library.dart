import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:xs/protobuf/bangumi.pb.dart';
import 'package:xs/src/apis/bangumi.dart';
import 'package:xs/src/pages/bangumi/controller.dart';
import 'package:xs/src/pages/bangumi/views/filter_rail.dart';
import 'package:xs/src/pages/settings/storage/play_history_storage.dart';
import 'package:xs/src/utils/account.dart';
import 'package:xs/src/widgets/bangumi_card.dart';

/// 番剧库结果区：网格 + 加载/空/错误三态。
class BangumiLibraryView extends StatelessWidget {
  const BangumiLibraryView({
    super.key,
    required this.controller,
    this.desktop = true,
  });

  final BangumiLibraryController controller;
  final bool desktop;

  static const SliverGridDelegateWithMaxCrossAxisExtent _delegate =
      SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 168,
    crossAxisSpacing: 14,
    mainAxisSpacing: 18,
    childAspectRatio: 0.6,
  );

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        controller.obx(
          (state) => state!.isEmpty ? _empty(context) : _grid(context, state),
          onLoading: _skeleton(context),
          onError: (error) => _error(context),
        ),
        if (!desktop)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              heroTag: 'bangumi-filter',
              onPressed: () => _showFilter(context),
              icon: const Icon(Icons.tune, size: 18),
              label: const Text('筛选'),
            ),
          ),
      ],
    );
  }

  Widget _grid(BuildContext context, List<bangumi_list_item_> items) {
    return Obx(() {
      // 订阅观看记录变化，续播角标才能在播放返回后刷新
      PlayHistoryStorage.revision.value;
      return RefreshIndicator(
        onRefresh: controller.reload,
        child: NotificationListener<ScrollEndNotification>(
          onNotification: (notification) {
            if (notification.metrics.atEdge &&
                notification.metrics.pixels > 0) {
              controller.more();
            }
            return false;
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                sliver: SliverGrid.builder(
                  gridDelegate: _delegate,
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final resume = PlayHistoryStorage.resume(item.id);
                    return BangumiCard(
                      title: item.title,
                      image: item.image,
                      badge: _episodeLabel(item),
                      meta: item.tagline,
                      resumeLabel:
                          resume == null ? null : '续看第${resume.episode}集',
                      onResume: resume == null
                          ? null
                          : () => _play(item.id, resume.episode),
                      onSecondaryTap: (position) =>
                          _showContextMenu(context, item, position),
                      onTap: () =>
                          Get.toNamed('/bangumi/${item.id}', arguments: item),
                    );
                  },
                ),
              ),
              SliverToBoxAdapter(
                child: Obx(
                  () => controller.isLoading.value
                      ? const LinearProgressIndicator(minHeight: 2)
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  void _play(int id, int episode) {
    Get.toNamed('/vod/$id', arguments: {'id': id, 'episode': episode});
  }

  Widget _skeleton(BuildContext context) {
    return Column(
      children: [
        const BangumiLoadingHint(),
        Expanded(
          child: SkeletonPulse(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: _delegate,
              itemCount: 12,
              itemBuilder: (context, index) => const BangumiCardSkeleton(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _empty(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off,
              size: 40, color: colorScheme.onSurface.withAlpha(90)),
          const SizedBox(height: 12),
          Text(
            controller.hasFilter ? '没有符合当前筛选的番剧' : '暂无番剧',
            style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
          ),
          if (controller.hasFilter)
            TextButton(
              onPressed: controller.reset,
              child: const Text('清除筛选'),
            ),
        ],
      ),
    );
  }

  Widget _error(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off,
              size: 40, color: colorScheme.onSurface.withAlpha(90)),
          const SizedBox(height: 12),
          Text(
            '番剧列表加载失败',
            style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: controller.get,
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Future<void> _showContextMenu(
      BuildContext context, bangumi_list_item_ item, Offset position) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        overlay.size.width - position.dx,
        overlay.size.height - position.dy,
      ),
      items: const [
        PopupMenuItem<String>(
          value: 'open',
          height: 40,
          child: Row(
            children: [
              Icon(Icons.open_in_new, size: 18),
              SizedBox(width: 10),
              Text('打开番剧'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'watch',
          height: 40,
          child: Row(
            children: [
              Icon(Icons.favorite_border, size: 18),
              SizedBox(width: 10),
              Text('收藏到在看'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'cancel',
          height: 40,
          child: Row(
            children: [
              Icon(Icons.favorite_border_outlined, size: 18),
              SizedBox(width: 10),
              Text('取消收藏'),
            ],
          ),
        ),
      ],
    );
    switch (selected) {
      case 'open':
        Get.toNamed('/bangumi/${item.id}', arguments: item);
        break;
      case 'watch':
        await _changeCollect(item.id);
        break;
      case 'cancel':
        await _cancelCollect(item.id);
        break;
    }
  }

  Future<void> _changeCollect(int id) async {
    if (AccountUtil.token().isEmpty) {
      SmartDialog.showToast('请先登录');
      return;
    }
    try {
      final response = await BangumiApi.changeCollect(id: id, type: 'watch');
      if (response.statusCode == 200 && (response.data['data'] ?? false)) {
        SmartDialog.showToast('已收藏到在看');
      } else {
        throw Error();
      }
    } catch (e) {
      debugPrint(e.toString());
      SmartDialog.showToast('操作失败，请重试');
    }
  }

  Future<void> _cancelCollect(int id) async {
    if (AccountUtil.token().isEmpty) {
      SmartDialog.showToast('请先登录');
      return;
    }
    try {
      final response = await BangumiApi.cancelCollect(id: id);
      if (response.statusCode == 200) {
        SmartDialog.showToast('已取消收藏');
      } else {
        throw Error();
      }
    } catch (e) {
      debugPrint(e.toString());
      SmartDialog.showToast('操作失败，请重试');
    }
  }

  String _episodeLabel(bangumi_list_item_ item) {
    if (item.status.isEmpty) return '敬请期待';
    if (item.status == 'released') return '全1集';
    if (item.status == 'finale') return '全${item.episodesTotal}集';
    return '更新至第${item.episode}集';
  }

  void _showFilter(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: BangumiFilterRail(controller: controller, showDone: true),
      ),
    );
  }
}
