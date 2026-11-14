import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:xs/protobuf/bangumi.pb.dart';
import 'package:xs/src/pages/bangumi_detail/controller.dart';
import 'package:xs/src/pages/bangumi_detail/models/bangumi_detail_model.dart';
import 'package:xs/src/pages/settings/storage/play_history_storage.dart';
import 'package:xs/src/utils/time.dart';
import 'package:xs/src/widgets/app_state_view.dart';
import 'package:xs/src/widgets/keepalive.dart';

class BangumiDetailEpisodesView extends StatelessWidget {
  const BangumiDetailEpisodesView({super.key, this.active = false, this.data});
  final bool active;
  final BangumiDetailModel? data;

  @override
  Widget build(BuildContext context) {
    const String assetName = 'assets/images/no_image.svg';
    final Widget noImage = SvgPicture.asset(assetName);
    Brightness currentBrightness = MediaQuery.of(context).platformBrightness;
    // 设置状态栏图标的亮度
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarIconBrightness: currentBrightness == Brightness.light
          ? Brightness.dark
          : Brightness.light,
    ));
    return GetBuilder(
        id: Get.currentRoute,
        global: false,
        init: BangumiDetailEpisodesController(),
        builder: (controller) {
          return SafeArea(
            top: false,
            bottom: false,
            maintainBottomViewPadding: true,
            child: Builder(builder: (context) {
              final scrollController =
                  controller.tabScrollController(context, active);
              return KeepAliveWrapper(
                  child: RefreshIndicator(
                displacement: 60,
                edgeOffset: 80,
                onRefresh: () async {
                  await controller.reload();
                },
                child: controller.obx(
                  (state) {
                    if (state!.isEmpty) {
                      return const AppStateView(
                        icon: Icons.video_library_outlined,
                        message: '暂无剧集',
                      );
                    }
                    return CustomScrollView(
                      key: const PageStorageKey('bangumi-detail-episodes'),
                      controller: scrollController,
                      shrinkWrap: true,
                      slivers: [
                        SliverOverlapInjector(
                            handle:
                                NestedScrollView.sliverOverlapAbsorberHandleFor(
                                    context)),
                        Obx(() {
                          // 订阅观看记录变化，续看标记才能实时刷新
                          PlayHistoryStorage.revision.value;
                          final resume = PlayHistoryStorage.resume(controller.id);
                          return SliverPadding(
                            padding: const EdgeInsets.only(
                                top: 10, left: 10, right: 10, bottom: 10),
                            sliver: SliverGrid.builder(
                                gridDelegate:
                                    const SliverGridDelegateWithMaxCrossAxisExtent(
                                        maxCrossAxisExtent: 200,
                                        crossAxisSpacing: 10,
                                        mainAxisSpacing: 10,
                                        childAspectRatio: 1.2),
                                itemCount: state.length,
                                itemBuilder: (context, index) {
                                  final item = state[index];
                                  return _EpisodeCard(
                                    item: item,
                                    noImage: noImage,
                                    resumed:
                                        resume?.episode == item.sort,
                                    onTap: () {
                                      Get.toNamed('/vod/${controller.id}',
                                          arguments: {
                                            'id': controller.id,
                                            'episode': item.sort,
                                            'data': data,
                                            'episodes': state
                                          });
                                    },
                                  );
                                }),
                          );
                        }),
                      ],
                    );
                  },
                  onLoading: const Center(
                    child: CircularProgressIndicator(),
                  ),
                  onError: (error) => AppStateView(
                    icon: Icons.cloud_off,
                    message: '剧集加载失败',
                    actionLabel: '重试',
                    onAction: controller.get,
                  ),
                ),
              ));
            }),
          );
        });
  }
}

/// 剧集网格卡片：封面 + 状态角标 + 集数标题。
class _EpisodeCard extends StatelessWidget {
  const _EpisodeCard({
    required this.item,
    required this.noImage,
    required this.resumed,
    required this.onTap,
  });

  final bangumi_episodes_data_ item;
  final Widget noImage;
  final bool resumed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = item.title.isEmpty
        ? '第${item.sort}集'
        : '第${item.sort}集 ${item.title}';
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  color: colorScheme.onSurface.withAlpha(12),
                  border: resumed
                      ? Border.all(color: colorScheme.primary, width: 1.4)
                      : null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      item.image.isNotEmpty
                          ? Image.network(
                              item.image,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  noImage,
                            )
                          : noImage,
                      if (resumed)
                        const Positioned(
                          top: 5,
                          left: 5,
                          child: _Badge(
                            text: '续看',
                            background: Colors.black54,
                            color: Colors.white,
                          ),
                        ),
                      Positioned(
                        bottom: 5,
                        right: 5,
                        child: Row(
                          children: [
                            _Badge(
                              text: item.status ? '有资源' : '无资源',
                              background: Colors.black.withAlpha(120),
                              color: Colors.white,
                            ),
                            if (item.duration > 0) ...[
                              const SizedBox(width: 4),
                              _Badge(
                                text: Duration(seconds: item.duration)
                                    .toString()
                                    .split('.')
                                    .first,
                                background: Colors.black.withAlpha(120),
                                color: Colors.white,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15),
            ),
            Opacity(
              opacity: 0.7,
              child: Text(
                Time.dateTimeFormat(item.airdate.toInt()),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.text,
    required this.background,
    required this.color,
  });

  final String text;
  final Color background;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(5, 1, 5, 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        color: background,
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 12),
      ),
    );
  }
}
