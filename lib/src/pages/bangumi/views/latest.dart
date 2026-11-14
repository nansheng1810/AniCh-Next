import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:xs/protobuf/bangumi.pb.dart';
import 'package:xs/src/pages/bangumi/controller.dart';
import 'package:xs/src/widgets/bangumi_card.dart';

/// 最近更新：按剧集展示的横版卡片。
class BangumiLatestView extends StatelessWidget {
  const BangumiLatestView({super.key});

  static const SliverGridDelegateWithMaxCrossAxisExtent _delegate =
      SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 260,
    crossAxisSpacing: 14,
    mainAxisSpacing: 18,
    childAspectRatio: 1.22,
  );

  @override
  Widget build(BuildContext context) {
    return GetBuilder(
        init: BangumiLatestController(),
        builder: (controller) {
          return controller.obx(
            (state) => state!.isEmpty
                ? _empty(context)
                : _grid(context, controller, state),
            onLoading: _skeleton(context),
            onError: (error) => _error(context, controller),
          );
        });
  }

  Widget _grid(BuildContext context, BangumiLatestController controller,
      List<bangumi_latest_item_> items) {
    return RefreshIndicator(
      onRefresh: controller.reload,
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
                return _LatestCard(
                  item: item,
                  onTap: () => Get.toNamed('/vod/${item.id}', arguments: {
                    'id': item.id,
                    'episode': item.ep,
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _skeleton(BuildContext context) {
    return Column(
      children: [
        const BangumiLoadingHint(text: '正在加载最近更新…'),
        Expanded(
          child: SkeletonPulse(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: _delegate,
              itemCount: 9,
              itemBuilder: (context, index) => const BangumiCardSkeleton(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _empty(BuildContext context) {
    return Center(
      child: Text(
        '暂无更新',
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _error(BuildContext context, BangumiLatestController controller) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off,
              size: 40,
              color: Theme.of(context).colorScheme.onSurface.withAlpha(90)),
          const SizedBox(height: 12),
          Text(
            '最近更新加载失败',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
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
}

class _LatestCard extends StatelessWidget {
  const _LatestCard({required this.item, required this.onTap});

  final bangumi_latest_item_ item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final Widget placeholder =
        SvgPicture.asset('assets/images/no_image.svg', fit: BoxFit.cover);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: colorScheme.onSurface.withAlpha(12)),
                    item.image.isEmpty
                        ? placeholder
                        : Image.network(
                            item.image,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                placeholder,
                          ),
                    if (!item.status)
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(120),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text(
                            '无资源',
                            style:
                                TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 34,
              child: Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.25,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(
              height: 16,
              child: Text(
                '第${item.ep}集 · ${_date(item.airdate)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _date(double timestamp) {
    if (timestamp <= 0) return '未知';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp.toInt());
    return '${date.month}月${date.day}日';
  }
}
