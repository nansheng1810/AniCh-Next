import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:xs/src/pages/search/controller.dart';
import 'package:xs/src/pages/settings/storage/play_history_storage.dart';
import 'package:xs/src/utils/utils.dart';
import 'package:xs/src/widgets/app_state_view.dart';
import 'package:xs/src/widgets/bangumi_card.dart';
import 'package:xs/src/widgets/keepalive.dart';
import 'package:xs/src/widgets/subordinate_scroll_controller.dart';

class SearchBangumiView extends StatelessWidget {
  const SearchBangumiView(
      {super.key, required this.keyword, this.active = false});
  final String keyword;
  final bool active;

  static const SliverGridDelegateWithMaxCrossAxisExtent _delegate =
      SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 168,
    crossAxisSpacing: 14,
    mainAxisSpacing: 18,
    childAspectRatio: 0.6,
  );

  @override
  Widget build(BuildContext context) {
    Brightness currentBrightness = MediaQuery.of(context).platformBrightness;
    // 设置状态栏图标的亮度
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarIconBrightness: currentBrightness == Brightness.light
          ? Brightness.dark
          : Brightness.light,
    ));
    return GetBuilder(
        id: keyword,
        global: false,
        init: SearchBangumiController(keyword),
        builder: (controller) {
          return SafeArea(
            top: false,
            bottom: false,
            maintainBottomViewPadding: true,
            child: Builder(builder: (context) {
              final parentController = PrimaryScrollController.of(context);
              final scrollController =
                  SubordinateScrollController(parentController);
              return KeepAliveWrapper(
                  child: RefreshIndicator(
                displacement: 0,
                edgeOffset: 40,
                onRefresh: () async {
                  await controller.reload();
                },
                child: controller.obx(
                  (state) {
                    if (state!.isEmpty) {
                      return const AppStateView(
                        icon: Icons.search_off,
                        message: '没有找到相关番剧',
                      );
                    }
                    return CustomScrollView(
                      key: const PageStorageKey('search-bangumi'),
                      controller:
                          active ? scrollController : ScrollController(),
                      shrinkWrap: true,
                      slivers: [
                        SliverOverlapInjector(
                            handle: NestedScrollView
                                .sliverOverlapAbsorberHandleFor(context)),
                        Obx(() {
                          // 订阅观看记录变化，续播角标才能实时刷新
                          PlayHistoryStorage.revision.value;
                          return SliverPadding(
                            padding: const EdgeInsets.only(
                                top: 10, left: 10, right: 10, bottom: 10),
                            sliver: SliverGrid.builder(
                              gridDelegate: _delegate,
                              itemCount: state.length,
                              itemBuilder: (context, index) {
                                final item = state[index];
                                final resume =
                                    PlayHistoryStorage.resume(item.id);
                                return BangumiCard(
                                  title: item.title,
                                  image: item.image,
                                  badge: Utils.episodeLabel(item.status,
                                      item.episodesTotal, item.episode),
                                  meta: item.tagline,
                                  resumeLabel: resume == null
                                      ? null
                                      : '续看第${resume.episode}集',
                                  onResume: resume == null
                                      ? null
                                      : () => Get.toNamed('/vod/${item.id}',
                                          arguments: {
                                            'id': item.id,
                                            'episode': resume.episode,
                                          }),
                                  onTap: () => Get.toNamed(
                                      '/bangumi/${item.id}',
                                      arguments: item),
                                );
                              },
                            ),
                          );
                        }),
                        SliverToBoxAdapter(child: Obx(() {
                          return SizedBox(
                              height: 5,
                              child: Visibility(
                                visible: controller.isLoading.isTrue,
                                maintainSize: false,
                                maintainSemantics: false,
                                maintainAnimation: false,
                                child: LinearProgressIndicator(
                                    backgroundColor: Colors.grey,
                                    valueColor: AlwaysStoppedAnimation(
                                        Theme.of(context).colorScheme.primary)),
                              ));
                        }))
                      ],
                    );
                  },
                  onLoading: GridView.builder(
                    padding: const EdgeInsets.only(
                        top: 10, left: 10, right: 10, bottom: 10),
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: _delegate,
                    itemCount: 12,
                    itemBuilder: (context, index) =>
                        const BangumiCardSkeleton(),
                  ),
                  onError: (error) => AppStateView(
                    icon: Icons.cloud_off,
                    message: '搜索失败',
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
