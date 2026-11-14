import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:xs/src/pages/bangumi_detail/controller.dart';
import 'package:xs/src/pages/bangumi_detail/models/bangumi_detail_model.dart';
import 'package:xs/src/pages/bangumi_detail/views/characters.dart';
import 'package:xs/src/pages/bangumi_detail/views/index.dart';
import 'package:xs/src/pages/bangumi_detail/views/episodes.dart';
import 'package:xs/src/pages/bangumi_detail/views/persons.dart';
import 'package:xs/src/pages/bangumi_detail/views/related.dart';
import 'package:xs/src/pages/settings/storage/play_history_storage.dart';
import 'package:xs/src/utils/app_route_observer.dart';
import 'package:xs/src/utils/time.dart';
import 'package:xs/src/utils/utils.dart';
import 'package:xs/src/widgets/drag_to_move_bar.dart';
import 'package:xs/src/widgets/navbar.dart';

class BangumiDetailPage extends StatefulWidget {
  const BangumiDetailPage({super.key});

  @override
  State<BangumiDetailPage> createState() => _BangumiDetailPageState();
}

class _BangumiDetailPageState extends State<BangumiDetailPage> with RouteAware {
  // 内容区重挂计数：从其它页面（尤其是播放页）返回时自愈可能残留的错误布局
  int _contentKey = 0;
  BangumiDetailController? _controller;
  bool _subscribed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_subscribed) {
      return;
    }
    final route = ModalRoute.of(context);
    if (route != null) {
      appRouteObserver.subscribe(this, route);
      _subscribed = true;
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    if (!mounted) {
      return;
    }
    // 从播放页返回或出现过渲染错误时，重挂内容区消除可能残留的错误布局
    final needRemount = hadRenderError || vodPageClosed;
    hadRenderError = false;
    vodPageClosed = false;
    if (needRemount) {
      setState(() {
        _contentKey++;
      });
    }
    _controller?.reload();
  }

  @override
  Widget build(BuildContext context) {
    const String assetName = 'assets/images/no_image.svg';
    final Widget noImage = SvgPicture.asset(assetName);
    RxDouble appBarHeight = 1.0.obs;
    RxInt scrollHeight = 0.obs;
    RxBool scrollStatus = true.obs;
    return GetBuilder(
        id: 'bangumi_detail_page',
        global: false,
        init: BangumiDetailController(),
        builder: (controller) {
          _controller = controller;
          return Scaffold(
            extendBody: true,
            body: controller.obx(
                (state) {
                  final data = state;
                  final ratings = <String>[
                    for (final item
                        in data!.rating ?? <BangumiDetailModelRating>[])
                      if ((item?.score ?? 0) > 0)
                        '${item?.site} ${item?.score}',
                  ];
                  return Obx(() {
                    return DefaultTabController(
                      length: controller.tabs.length,
                      child: NestedScrollView(
                        key: ValueKey('bangumi_detail_content_$_contentKey'),
                        floatHeaderSlivers: false,
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
                              BangumiDetailIndexView(
                                controller: controller,
                                active: controller.tabIndex.value == 0,
                                data: data,
                              ),
                              BangumiDetailEpisodesView(
                                active: controller.tabIndex.value == 1,
                                data: data,
                              ),
                              BangumiDetailCharactersView(
                                  active: controller.tabIndex.value == 2),
                              BangumiDetailPersonsView(
                                  active: controller.tabIndex.value == 3),
                              BangumiDetailRelatedView(
                                  active: controller.tabIndex.value == 4),
                            ],
                          ),
                        ),
                        headerSliverBuilder: (context, innerBoxIsScrolled) {
                          return [
                            SliverOverlapAbsorber(
                              sliver: SliverAppBar(
                                title: Obx(() {
                                  return CustomDragToMoveArea(
                                      child: Opacity(
                                    opacity: min(appBarHeight.value.abs(), 1.0),
                                    child: Text('${data.title}'),
                                  ));
                                }),
                                pinned: true,
                                automaticallyImplyLeading: false,
                                floating: true,
                                snap: false,
                                expandedHeight: 270,
                                collapsedHeight: 50,
                                toolbarHeight: 50,
                                backgroundColor:
                                    Theme.of(context).scaffoldBackgroundColor,
                                surfaceTintColor: Theme.of(context)
                                    .colorScheme
                                    .inverseSurface,
                                flexibleSpace: LayoutBuilder(
                                  builder: (context, constraints) {
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                      appBarHeight(1.5 -
                                          (constraints.biggest.height -
                                                  MediaQuery.of(context)
                                                      .padding
                                                      .top) /
                                              180);
                                    });
                                    return Obx(() {
                                      return Opacity(
                                        opacity: max(
                                            (appBarHeight.value - 1).abs(),
                                            0.0),
                                        child: CustomDragToMoveArea(
                                          child: FlexibleSpaceBar(
                                            background: Stack(
                                              children: [
                                                ShaderMask(
                                                  shaderCallback: (rect) {
                                                    return LinearGradient(
                                                        begin:
                                                            Alignment.topCenter,
                                                        end: Alignment
                                                            .bottomCenter,
                                                        colors: [
                                                          Colors.black
                                                              .withAlpha(100),
                                                          Colors.transparent
                                                        ]).createShader(
                                                        Rect.fromLTRB(
                                                            0,
                                                            0,
                                                            rect.width,
                                                            rect.height));
                                                  },
                                                  blendMode: BlendMode.dstIn,
                                                  child: Stack(
                                                    fit: StackFit.expand,
                                                    children: [
                                                      data.image != null
                                                          ? Image.network(
                                                              '${data.image}',
                                                              fit: BoxFit.cover,
                                                            )
                                                          : noImage,
                                                      BackdropFilter(
                                                        filter:
                                                            ImageFilter.blur(
                                                                sigmaX: 10,
                                                                sigmaY: 10),
                                                        child: Container(),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Container(
                                                  padding: EdgeInsets.only(
                                                      top:
                                                          MediaQuery.of(context)
                                                                  .padding
                                                                  .top +
                                                              10,
                                                      left: 10,
                                                      right: 10,
                                                      bottom: 10),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.start,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      SizedBox(
                                                        width: 150,
                                                        child: AspectRatio(
                                                          aspectRatio: 3 / 4,
                                                          child: ClipRRect(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        10),
                                                            child: data.image !=
                                                                    null
                                                                ? Image.network(
                                                                    '${data.image}',
                                                                    fit: BoxFit
                                                                        .cover,
                                                                  )
                                                                : noImage,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                        width: 10,
                                                      ),
                                                      Expanded(
                                                        child: Column(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .start,
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            SizedBox(
                                                              child: Text(
                                                                '${data.title}',
                                                                maxLines: 3,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                                textAlign:
                                                                    TextAlign
                                                                        .start,
                                                                style: const TextStyle(
                                                                    fontSize:
                                                                        20,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold),
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                                height: 10),
                                                            _detailMeta(
                                                              context,
                                                              Icons
                                                                  .calendar_today_outlined,
                                                              Time.dateTimeFormat(
                                                                  data.airdate ??
                                                                      0),
                                                            ),
                                                            const SizedBox(
                                                                height: 5),
                                                            _detailMeta(
                                                              context,
                                                              Icons
                                                                  .play_circle_outline,
                                                              Utils
                                                                  .episodeLabel(
                                                                data.status,
                                                                data.episodesTotal,
                                                                data.episode,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                                height: 5),
                                                            _detailMeta(
                                                              context,
                                                              Icons.star_border,
                                                              ratings.isEmpty
                                                                  ? '暂无评分'
                                                                  : ratings
                                                                      .join(
                                                                          '  '),
                                                            ),
                                                          ],
                                                        ),
                                                      )
                                                    ],
                                                  ),
                                                )
                                              ],
                                            ),
                                            // centerTitle: true,
                                            collapseMode: CollapseMode.pin,
                                          ),
                                        ),
                                      );
                                    });
                                  },
                                ),
                                bottom: PreferredSize(
                                  preferredSize: const Size.fromHeight(50),
                                  child: Material(
                                    color: Colors.transparent,
                                    // color: Theme.of(context).scaffoldBackgroundColor,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            margin: const EdgeInsets.only(
                                                right: 10),
                                            child: TabBar(
                                              labelPadding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10),
                                              controller:
                                                  controller.tabController,
                                              tabAlignment: TabAlignment.start,
                                              isScrollable: true,
                                              indicatorSize:
                                                  TabBarIndicatorSize.label,
                                              dividerColor: Theme.of(context)
                                                  .scaffoldBackgroundColor,
                                              tabs: controller.tabs,
                                            ),
                                          ),
                                        ),
                                        Obx(() {
                                          PlayHistoryStorage.revision.value;
                                          final resume =
                                              PlayHistoryStorage.resume(
                                                  controller.id.value);
                                          if (resume == null) {
                                            return const SizedBox.shrink();
                                          }
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                                right: 10),
                                            child: SizedBox(
                                              height: 30,
                                              child: FilledButton.tonal(
                                                style: ButtonStyle(
                                                  padding:
                                                      WidgetStateProperty.all(
                                                          const EdgeInsets
                                                              .symmetric(
                                                              horizontal: 10)),
                                                  shape:
                                                      WidgetStateProperty.all(
                                                    RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(5)),
                                                  ),
                                                ),
                                                onPressed: () => Get.toNamed(
                                                    '/vod/${controller.id.value}',
                                                    arguments: {
                                                      'id': controller.id.value,
                                                      'episode': resume.episode,
                                                    }),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.play_arrow,
                                                        size: 16),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                        '续看第${resume.episode}集'),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        }),
                                        Obx(() {
                                          if (controller
                                              .collectStatusLoading.isFalse) {
                                            return !controller
                                                    .collectStatus.value
                                                ? SizedBox(
                                                    height: 30,
                                                    child: FilledButton(
                                                      style: ButtonStyle(
                                                          shape: WidgetStateProperty.all(
                                                              RoundedRectangleBorder(
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              5)))),
                                                      onPressed: () {
                                                        controller
                                                            .showCollectSheet();
                                                      },
                                                      child: const Row(
                                                        children: [
                                                          Icon(
                                                            Icons.favorite,
                                                            size: 16,
                                                            color: Colors.white,
                                                          ),
                                                          SizedBox(width: 5),
                                                          Text('收藏')
                                                        ],
                                                      ),
                                                    ),
                                                  )
                                                : SizedBox(
                                                    height: 30,
                                                    child: FilledButton(
                                                      style: ButtonStyle(
                                                          backgroundColor:
                                                              WidgetStateProperty
                                                                  .all(Theme.of(
                                                                          context)
                                                                      .colorScheme
                                                                      .primary
                                                                      .withAlpha(
                                                                          200)),
                                                          shape: WidgetStateProperty.all(
                                                              RoundedRectangleBorder(
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              5)))),
                                                      onPressed: () {
                                                        controller
                                                            .showMarkSheet();
                                                      },
                                                      child: const Row(
                                                        children: [
                                                          Icon(
                                                            Icons.more_vert,
                                                            size: 16,
                                                            color: Colors.white,
                                                          ),
                                                          Text('标记为...')
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                          } else {
                                            return Container();
                                          }
                                        }),
                                        const SizedBox(width: 10)
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              handle: NestedScrollView
                                  .sliverOverlapAbsorberHandleFor(context),
                            ),
                          ];
                        },
                      ),
                    );
                  });
                },
                onLoading: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(height: 12),
                      Text(
                        '正在加载番剧详情…',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                onError: (e) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off,
                            size: 40, color: Colors.grey),
                        const SizedBox(height: 12),
                        const Text(
                          '番剧详情加载失败',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => controller.get(),
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  );
                }),
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
}

/// 详情页头部的单行元信息（图标 + 文本）。
Widget _detailMeta(BuildContext context, IconData icon, String text) {
  final color = Theme.of(context).colorScheme.onSurfaceVariant;
  return Row(
    children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 5),
      Expanded(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: color),
        ),
      ),
    ],
  );
}
