import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:xs/protobuf/bangumi.pb.dart';
import 'package:xs/protobuf/danmaku.pb.dart';
import 'package:xs/src/apis/bangumi.dart';
import 'package:xs/src/pages/bangumi_detail/models/bangumi_detail_model.dart';
import 'package:xs/src/pages/bangumi_vod/models/qq_video_model.dart';
import 'package:xs/src/pages/download/download_manager.dart';
import 'package:xs/src/pages/settings/storage/play_history_storage.dart';
import 'package:xs/src/utils/account.dart';
import 'package:xs/src/utils/time.dart';
import 'package:xs/src/widgets/danmaku_settings/storage.dart';
import 'package:xs/src/widgets/danmaku_shield/storage.dart';
import 'package:xs/src/utils/app_style.dart';
import 'package:xs/src/utils/color.dart';
import 'package:xs/src/utils/log.dart';
import 'package:xs/src/utils/utils.dart';
import 'package:xs/src/widgets/danmaku_settings/view.dart';
import 'package:xs/src/widgets/danmaku_shield/view.dart';
import 'package:xs/src/widgets/ns_danmaku/danmaku_controller.dart';
import 'package:xs/src/widgets/ns_danmaku/models/danmaku_item.dart';
import 'package:xs/src/widgets/ns_danmaku/utils.dart';
import 'package:xs/src/widgets/player/controller.dart';
import 'package:xs/src/widgets/player/upscaler.dart';
import 'package:xs/src/widgets/settings/settings_card.dart';
import 'package:xs/src/widgets/settings/settings_switch.dart';

const String assetName = 'assets/images/no_image.svg';
final Widget noImage = SvgPicture.asset(assetName);

class BangumiVodPageController extends PlayerController
    with StateMixin, WidgetsBindingObserver, GetTickerProviderStateMixin {
  final int pId;
  final int pEpisode;
  BangumiVodPageController({
    required this.pId,
    required this.pEpisode,
  }) {
    rxId = pId.obs;
    rxEpisode = pEpisode.obs;
  }

  late RxInt rxId;
  int get id => rxId.value;
  late RxInt rxEpisode;
  int get episode => rxEpisode.value;

  // 线路数据
  RxList<vod_item_> playUrls = RxList<vod_item_>();

  // 当前线路
  var currentLineIndex = -1;
  var currentLineInfo = ''.obs;

  // 加载失败
  var loadError = false.obs;
  Error? error;

  // 退出
  RxBool leave = false.obs;

  // 导航栏
  final List<Tab> tabs = <Tab>[
    const Tab(
      child: Align(
        alignment: Alignment.center,
        child: Text('简介'),
      ),
    ),
    const Tab(
      child: Align(
        alignment: Alignment.center,
        child: Text('评论'),
      ),
    ),
  ];

  late TabController tabController;
  late final AnimationController animationController;
  RxInt tabIndex = 0.obs;

  late final BangumiDetailModel data;
  late final bangumi_episodes_data_ episodeDetail;
  List<bangumi_episodes_data_> episodes = [];
  List<data_> danmakuList = [];
  List<bilibili_danmaku_item_> bilibiliDanmakuList = [];
  List<bilibili_danmaku_item_> bilibiliHmtDanmakuList = [];
  List<BarrageList> qqDanmakuList = [];

  ScrollController playListScrollController = ScrollController();
  ScrollController playListScrollController2 = ScrollController();

  Map<dynamic, dynamic> bangumiInfo = {'episodes': []};

  RxInt lastPosition = 0.obs;

  RxBool playing = true.obs;

  @override
  void onInit() {
    WidgetsBinding.instance.addObserver(this);

    get();

    tabController =
        TabController(vsync: this, length: tabs.length, initialIndex: 0);
    tabController.addListener(() {
      tabIndex(tabController.index);
    });

    animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    super.onInit();
    listen();
  }

  bool _listening = false;

  void listen() {
    // GetBuilder 会在每次重建时调用 listen，避免重复订阅播放器流
    if (_listening) {
      return;
    }
    _listening = true;
    int position = 0;
    int inSeconds = 0;

    player.stream.error.listen((event) {
      // if (RegExp('Failed to open').hasMatch(event)) {
      //   SmartDialog.showToast(event);
      // }
      SmartDialog.showToast('播放失败: $event');
    });

    player.stream.completed.listen((event) {
      if (event) {
        showControls();
      }
    });

    player.stream.playing.listen((event) {
      playing(player.state.playing);
      showDanmakuState.value = DanmakuSettingsStorage.danmakuEnable.value;
      bilibiliDanmakuState.value =
          DanmakuSettingsStorage.bilibiliDanmakuEnable.value;
      bilibiliHmtDanmakuState.value =
          DanmakuSettingsStorage.bilibiliHmtDanmakuEnable.value;
      qqDanmakuState.value = DanmakuSettingsStorage.qqDanmakuEnable.value;
      if (showDanmakuState.value && danmakuController is DanmakuController) {
        if (event) {
          int currentPosition = player.state.position.inMilliseconds ~/ 1000;
          if (position != currentPosition) {
            position = currentPosition;
          }
          danmakuController!.resume();
        } else {
          danmakuController!.pause();
        }
      }
    });

    player.stream.position.listen((event) async {
      int currentinSeconds = event.inSeconds;
      if (currentinSeconds > 0 && lastPosition.value > 0) {
        final thisLastPosition = Duration(seconds: lastPosition.value);
        lastPosition(0);
        await player.seek(thisLastPosition);
        debugPrint('跳转到$thisLastPosition');
      }
      if ((inSeconds - currentinSeconds).abs() >= 5) {
        inSeconds = currentinSeconds;
        final date = DateTime.now().millisecondsSinceEpoch;
        bangumiInfo['id'] = id;
        bangumiInfo['title'] = data.title;
        bangumiInfo['date'] = date;
        bangumiInfo['image'] = data.image;
        final episodeInfo = {
          'episode': episode,
          'title': '第$episode集 ${episodeDetail.title}',
          'position': currentinSeconds,
          'date': date,
          'image': episodeDetail.image
        };
        final item = bangumiInfo['episodes'].firstWhere(
          (e) {
            return e['episode'] == episode;
          },
          orElse: () => {},
        );
        if (item.isEmpty) {
          bangumiInfo['episodes'].add(episodeInfo);
          // print(bangumiInfo);
        } else {
          item['position'] = episodeInfo['position'];
          item['date'] = episodeInfo['date'];
          // print(bangumiInfo);
        }
        PlayHistoryStorage.save(id, bangumiInfo, notify: false);
      }
      if (showDanmakuState.value && danmakuController is DanmakuController) {
        int currentPosition = event.inMilliseconds ~/ 100;
        if (position != currentPosition) {
          position = currentPosition;
          // 默认弹幕
          if (danmakuList.isNotEmpty) {
            final currentDanmakuList = danmakuList.where((e) {
              return double.parse(e.time.toStringAsFixed(1)) ==
                      currentPosition / 10 &&
                  DanmakuShieldStorage.shieldCheck(e.text);
            });
            final currentDanmakuListQueue = currentDanmakuList.map((e) {
              return DanmakuItem(e.text,
                  color: ColorUtil.fromHex(e.color),
                  // time: currentPosition,
                  time: e.time,
                  type: DanmakuUtils.getPosition(e.type),
                  id: int.tryParse(e.id));
            }).toList();
            try {
              danmakuController!.addItems(currentDanmakuListQueue);
            } catch (e) {
              debugPrint(e.toString());
            }
          }
          // 哔哩哔哩弹幕
          if (bilibiliDanmakuList.isNotEmpty && bilibiliDanmakuState.value) {
            final currentDanmakuList = bilibiliDanmakuList.where((e) {
              // return (e.progress / 1000).floor() == currentPosition;
              return double.parse((e.progress / 1000).toStringAsFixed(1)) ==
                      currentPosition / 10 &&
                  DanmakuShieldStorage.shieldCheck(e.content);
            });
            final currentDanmakuListQueue = currentDanmakuList.map((e) {
              return DanmakuItem(e.content,
                  color: ColorUtil.decimalToColor(e.color),
                  // time: currentPosition,
                  time: e.progress / 1000,
                  type: DanmakuUtils.getBilibiliPosition(e.mode));
            }).toList();
            try {
              danmakuController!.addItems(currentDanmakuListQueue);
            } catch (e) {
              debugPrint(e.toString());
            }
          }
          // 哔哩哔哩(港澳台)弹幕
          if (bilibiliHmtDanmakuList.isNotEmpty &&
              bilibiliHmtDanmakuState.value) {
            final currentDanmakuList = bilibiliHmtDanmakuList.where((e) {
              // return (e.progress / 1000).floor() == currentPosition;
              return double.parse((e.progress / 1000).toStringAsFixed(1)) ==
                      currentPosition / 10 &&
                  DanmakuShieldStorage.shieldCheck(e.content);
            });
            final currentDanmakuListQueue = currentDanmakuList.map((e) {
              return DanmakuItem(e.content,
                  color: ColorUtil.decimalToColor(e.color),
                  // time: currentPosition,
                  time: e.progress / 1000,
                  type: DanmakuUtils.getBilibiliPosition(e.mode));
            }).toList();
            try {
              danmakuController!.addItems(currentDanmakuListQueue);
            } catch (e) {
              debugPrint(e.toString());
            }
          }
          // 腾讯视频弹幕
          if (qqDanmakuList.isNotEmpty && qqDanmakuState.value) {
            final currentDanmakuList = qqDanmakuList.where((e) {
              // return (int.parse(e.timeOffset ?? '0') / 1000).floor() ==
              //     currentPosition;
              return double.parse((int.parse(e.timeOffset ?? '0') / 1000)
                          .toStringAsFixed(1)) ==
                      currentPosition / 10 &&
                  DanmakuShieldStorage.shieldCheck(e.content);
            });
            final currentDanmakuListQueue = currentDanmakuList.map((e) {
              return DanmakuItem(e.content ?? '一条弹幕',
                  color: Colors.white,
                  // time: currentPosition,
                  time: int.parse(e.timeOffset ?? '0') / 1000,
                  type: DanmakuUtils.getQQPosition(e.rickType ?? 1));
            }).toList();
            try {
              danmakuController!.addItems(currentDanmakuListQueue);
            } catch (e) {
              debugPrint(e.toString());
            }
          }
        }
      }
    });
  }

  // 番剧数据
  void setBangumiData(data) async {
    try {
      debugPrint('BangumiVodController-setBangumiData');
      this.data = data;
      change(data, status: RxStatus.success());
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  // 获取番剧数据
  void getBangumiData() async {
    try {
      debugPrint('BangumiVodController-getBangumiData');
      change(null, status: RxStatus.loading());
      final response = await BangumiApi.getBangumiDetail(id: id);
      if (response.statusCode == 200) {
        final data = BangumiDetailModel.fromJson(response.data);
        this.data = data;
        change(data, status: RxStatus.success());
      } else {
        throw Error();
      }
    } catch (e) {
      debugPrint(e.toString());
      change(null, status: RxStatus.error('error'));
    }
  }

  // 番剧剧集
  void setBangumiEpisodes(episodes) async {
    try {
      debugPrint('BangumiVodController-setBangumiEpisodes');
      this.episodes = episodes;
      episodeDetail = episodes.firstWhere((e) => e.sort == episode);
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  // 获取番剧剧集
  void getBangumiEpisodes() async {
    try {
      debugPrint('BangumiVodController-getBangumiEpisodes');
      final response = await BangumiApi.getBangumiEpisodes(id: id);
      if (response.statusCode == 200) {
        final data = bangumi_episodes_.fromBuffer(response.data);
        episodes.addAll(data.data);
        episodeDetail = episodes.firstWhere((e) => e.sort == episode);
        update(['bangumi_vod_page']);
      } else {
        throw Error();
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  // 获取弹幕
  void getDanmaku() async {
    int thisEpisode = episode;
    int index = 0;
    int length = 3000;
    bool completed = false;
    while (!completed && !leave.value && thisEpisode == episode) {
      try {
        debugPrint('BangumiVodController-getDanmaku-$index');
        final response = await BangumiApi.getDanmaku(
            id: id, episode: episode, skip: index * length);
        if (response.statusCode == 200) {
          final data = danmaku_.fromBuffer(response.data);
          if (data.data.isNotEmpty) {
            danmakuList.addAll(data.data);
            if (data.data.length == length) {
              index += 1;
            } else {
              completed = true;
            }
          } else {
            completed = true;
          }
        } else {
          throw Error();
        }
      } catch (e) {
        completed = true;
        debugPrint(e.toString());
      }
    }
    debugPrint('BangumiVodController-getDanmaku-complete');
  }

  // 获取哔哩哔哩弹幕
  void getBilibiliDanmaku() async {
    int thisEpisode = episode;
    int index = 1;
    bool completed = false;
    while (!completed && !leave.value && thisEpisode == episode) {
      await Future.delayed(const Duration(seconds: 1));
      if (episodes.isNotEmpty) {
        final currentEpisode = getEpisodeData();
        if (currentEpisode.sites.isNotEmpty) {
          bangumi_episodes_sites_ site = currentEpisode.sites.firstWhere(
              (e) => e.site == 'bili_cid',
              orElse: () => bangumi_episodes_sites_());
          if (site.id.isEmpty) {
            completed = true;
            return;
          } else {
            try {
              debugPrint('BangumiVodController-getBilibiliDanmaku-$index');
              final response = await BangumiApi.getBilibiliDanmaku(
                  type: 1, oid: int.parse(site.id), segmentIndex: index);
              if (response.statusCode == 200) {
                final data = bilibili_danmaku_.fromBuffer(response.data);
                if (data.list.isNotEmpty) {
                  final list = Utils.splitList(data.list, 500);
                  for (final item in list) {
                    final list_ = (await compute(
                            DanmakuShieldStorage.defaultShieldCheck, item))
                        .cast<bilibili_danmaku_item_>();
                    bilibiliDanmakuList.addAll(list_);
                  }
                  index += 1;
                } else {
                  completed = true;
                }
              } else {
                completed = true;
                throw Error();
              }
            } catch (e) {
              completed = true;
              debugPrint(e.toString());
            }
          }
        }
      }
    }
    debugPrint('BangumiVodController-getBilibiliDanmaku-complete');
  }

  // 获取哔哩哔哩(港澳台)弹幕
  void getBilibiliHmtDanmaku() async {
    int thisEpisode = episode;
    int index = 1;
    bool completed = false;
    while (!completed && !leave.value && thisEpisode == episode) {
      await Future.delayed(const Duration(seconds: 1));
      if (episodes.isNotEmpty) {
        final currentEpisode = getEpisodeData();
        if (currentEpisode.sites.isNotEmpty) {
          bangumi_episodes_sites_ site = currentEpisode.sites.firstWhere(
              (e) => e.site == 'bili_hmt_cid',
              orElse: () => bangumi_episodes_sites_());
          if (site.id.isEmpty) {
            completed = true;
            return;
          } else {
            try {
              debugPrint('BangumiVodController-getBilibiliHmtDanmaku-$index');
              final response = await BangumiApi.getBilibiliDanmaku(
                  type: 1, oid: int.parse(site.id), segmentIndex: index);
              if (response.statusCode == 200) {
                final data = bilibili_danmaku_.fromBuffer(response.data);
                if (data.list.isNotEmpty) {
                  final list = Utils.splitList(data.list, 500);
                  for (final item in list) {
                    final list_ = (await compute(
                            DanmakuShieldStorage.defaultShieldCheck, item))
                        .cast<bilibili_danmaku_item_>();
                    bilibiliHmtDanmakuList.addAll(list_);
                  }
                  index += 1;
                } else {
                  completed = true;
                }
              } else {
                completed = true;
                throw Error();
              }
            } catch (e) {
              completed = true;
              debugPrint(e.toString());
            }
          }
        }
      }
    }
    debugPrint('BangumiVodController-getBilibiliHmtDanmaku-complete');
  }

  // 获取腾讯视频弹幕
  void getQQDanmaku() async {
    int thisEpisode = episode;
    int index = 1;
    bool completed = false;
    while (!completed && !leave.value && thisEpisode == episode) {
      await Future.delayed(const Duration(seconds: 1));
      if (episodes.isNotEmpty) {
        final currentEpisode = getEpisodeData();
        if (currentEpisode.sites.isNotEmpty) {
          bangumi_episodes_sites_ site = currentEpisode.sites.firstWhere(
              (e) => e.site == 'qq',
              orElse: () => bangumi_episodes_sites_());
          if (site.id.isEmpty) {
            completed = true;
            return;
          } else {
            try {
              debugPrint('BangumiVodController-getQQDanmaku-$index');
              final response =
                  await BangumiApi.getQQDanmaku(id: site.id, page: index);
              if (response.statusCode == 200) {
                final data = QqVideoModel.fromJson(response.data).barrageList;
                if (data!.isNotEmpty) {
                  final list = Utils.splitList(data, 500);
                  for (final item in list) {
                    final list_ = (await compute(
                            DanmakuShieldStorage.defaultShieldCheck, item))
                        .cast<BarrageList>();
                    qqDanmakuList.addAll(list_);
                  }
                  index += 1;
                } else {
                  completed = true;
                }
              } else {
                completed = true;
                throw Error();
              }
            } catch (e) {
              completed = true;
              debugPrint(e.toString());
            }
          }
        }
      }
    }
    debugPrint('BangumiVodController-getQQDanmaku-complete');
  }

  // URL解密
  String urlDecode(str) {
    try {
      return utf8.decode(base64
          .decode(base64.normalize(str.substring(0, 3) + str.substring(4))));
    } catch (e) {
      debugPrint(e.toString());
      return '';
    }
  }

  // 获取视频链接
  void getPlayUrl() async {
    // 切换剧集时尽量沿用当前线路
    final previousLine = currentLineIndex;
    playUrls.clear();
    currentLineInfo.value = '获取中...';
    currentLineIndex = -1;
    final response =
        await BangumiApi.getBangumiEpisodeVod(id: id, episode: episode);
    if (response.statusCode != 200) {
      currentLineInfo.value = '获取失败';
      SmartDialog.showToast('无法读取播放地址');
      return;
    }
    vod_ data = vod_.fromBuffer(response.data.cast<int>());
    playUrls.value = data.data;
    if (data.data.isEmpty) {
      currentLineInfo.value = '暂无资源';
      SmartDialog.showToast('暂无资源');
      return;
    }
    currentLineIndex =
        previousLine >= 0 && previousLine < data.data.length ? previousLine : 0;
    setPlayer();
  }

  // 设置视频链接
  void setPlayer() async {
    if (playUrls.isNotEmpty) {
      lastPosition(PlayHistoryStorage.getLastPosition(id, episode));
      final manager = Get.isRegistered<DownloadManager>()
          ? DownloadManager.instance
          : Get.put(DownloadManager());
      final localPath = manager.localPath(id, episode, currentLineIndex);
      final networkUrl = urlDecode(playUrls[currentLineIndex].url);
      currentLineInfo.value =
          localPath != null ? '本地缓存' : '线路${currentLineIndex + 1}';
      Map<String, String> headers = {};
      await player.open(
        Media(
          localPath != null ? Uri.file(localPath).toString() : networkUrl,
          httpHeaders: headers,
        ),
      );
      // open 之后恢复倍速、音量与画质
      await player.setRate(playerSpeed.value);
      await player.setVolume(playerVolume.value);
      await applySuperResolution();
      await applyRenderSize();
      await applyUpscaler();

      // final history = box.read(id.toString());
      // if (history != null) {
      //   final thisEpisode = history['episodes'].firstWhere(
      //       (e) => e['episode'].toString() == episode.toString(),
      //       orElse: () => {});
      //   lastPosition(int.parse(thisEpisode['position'].toString()));
      // }

      Log.d('播放链接\r\n：${urlDecode(playUrls[currentLineIndex].url)}');
    }
  }

  // 获取集数据
  bangumi_episodes_data_ getEpisodeData() {
    return episodes.firstWhere((e) => e.sort == episode,
        orElse: () => bangumi_episodes_data_());
  }

  // 长按弹幕：暂停播放并确认举报
  Future<void> onDanmakuLongPress(DanmakuItem item) async {
    final danmakuId = item.id;
    if (danmakuId == null) {
      SmartDialog.showToast('该弹幕不支持举报');
      return;
    }
    if (AccountUtil.token().isEmpty) {
      SmartDialog.showToast('请先登录');
      return;
    }
    final wasPlaying = player.state.playing;
    if (wasPlaying) {
      await player.pause();
    }
    final confirmed = await Utils.showAlertDialog(
      item.text,
      title: '举报弹幕',
      confirm: '举报',
    );
    if (confirmed) {
      try {
        await BangumiApi.reportDanmaku(id: danmakuId);
        SmartDialog.showToast('举报成功');
      } catch (e) {
        final status = e is DioException ? e.response?.statusCode : null;
        if (status == 401 || status == 403) {
          SmartDialog.showToast('请先登录');
        } else {
          SmartDialog.showToast('举报失败');
        }
      }
    }
    if (wasPlaying) {
      await player.play();
    }
  }

  // 离线缓存当前剧集
  Future<void> downloadCurrentEpisode() async {
    if (playUrls.isEmpty || currentLineIndex < 0) {
      SmartDialog.showToast('暂无可缓存的播放地址');
      return;
    }
    final url = urlDecode(playUrls[currentLineIndex].url);
    if (url.isEmpty) {
      SmartDialog.showToast('播放地址无效');
      return;
    }
    if (url.contains('.m3u8')) {
      SmartDialog.showToast('暂不支持 m3u8 离线缓存');
      return;
    }
    final manager = Get.isRegistered<DownloadManager>()
        ? DownloadManager.instance
        : Get.put(DownloadManager());
    final added = await manager.addTask(
      bangumiId: id,
      episode: episode,
      title: data.title ?? '',
      episodeTitle: getEpisodeData().title,
      image: data.image ?? '',
      lineIndex: currentLineIndex,
      url: url,
    );
    SmartDialog.showToast(added ? '已加入离线缓存' : '该剧集已存在缓存任务');
  }

  // 切换线路
  void changePlayLine(int index) {
    currentLineIndex = index;
    setPlayer();
  }

  // 上一集，已经是第一集时返回 null
  bangumi_episodes_data_? previousEpisodeData() {
    final index = episodes.indexWhere((e) => e.sort == episode);
    if (index <= 0) {
      return null;
    }
    return episodes[index - 1];
  }

  // 下一集，已经是最后一集时返回 null
  bangumi_episodes_data_? nextEpisodeData() {
    final index = episodes.indexWhere((e) => e.sort == episode);
    if (index < 0 || index + 1 >= episodes.length) {
      return null;
    }
    return episodes[index + 1];
  }

  // 切换剧集
  void changeEpisode(int sort) {
    if (sort == episode) {
      return;
    }
    rxEpisode(sort);
    // 刷新页面，让侧栏标题、选集高亮等跟随当前剧集更新
    update(['bangumi_vod_page']);
    player.stop();
    danmakuController?.clear();
    get();
  }

  // 播放上一集
  void playPreviousEpisode() {
    final data = previousEpisodeData();
    if (data != null) {
      changeEpisode(data.sort);
    }
  }

  // 播放下一集
  void playNextEpisode() {
    final data = nextEpisodeData();
    if (data != null) {
      changeEpisode(data.sort);
    }
  }

  // 刷新
  void reload() async {
    getPlayUrl();
  }

  // 获取数据
  void get() async {
    getPlayUrl();
    danmakuList.clear();
    bilibiliDanmakuList.clear();
    bilibiliHmtDanmakuList.clear();
    qqDanmakuList.clear();
    getDanmaku();
    getBilibiliDanmaku();
    getBilibiliHmtDanmaku();
    getQQDanmaku();
  }

  // 跳转到指定集数位置
  void scrollToIndex() {
    WidgetsBinding.instance.addPostFrameCallback((callback) {
      try {
        final index = episodes.indexWhere((e) => e.sort == episode);
        if (playListScrollController.position.hasPixels) {
          playListScrollController.animateTo(index * 150,
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeIn);
        }
      } catch (e) {
        debugPrint(e.toString());
      }
    });
  }

  /// 底部打开播放器设置
  void showDanmakuSettingsSheet() {
    Utils.showBottomSheet(
      title: '弹幕设置',
      child: ListView(
        padding: AppStyle.edgeInsetsA12,
        children: [
          DanmakuSettingsView(
            playerController: this,
            danmakuController: danmakuController,
            onTapDanmakuShield: () {
              Get.back();
              DanmakuShieldView.showDanmakuShieldBottomSheet();
            },
          ),
        ],
      ),
    );
  }

  void showDanmakuShield() {
    TextEditingController keywordController = TextEditingController();

    void addKeyword() {
      if (keywordController.text.isEmpty) {
        SmartDialog.showToast('请输入关键词');
        return;
      }

      DanmakuShieldStorage.addShieldList(keywordController.text.trim());
      keywordController.text = '';
    }

    Utils.showBottomSheet(
      title: '关键词屏蔽',
      child: ListView(
        padding: AppStyle.edgeInsetsA12,
        children: [
          TextField(
            controller: keywordController,
            decoration: InputDecoration(
              contentPadding: AppStyle.edgeInsetsH12,
              border: const OutlineInputBorder(),
              hintText: '请输入关键词',
              suffixIcon: TextButton.icon(
                onPressed: addKeyword,
                icon: const Icon(Icons.add),
                label: const Text('添加'),
              ),
            ),
            onSubmitted: (e) {
              addKeyword();
            },
          ),
          AppStyle.vGap12,
          Obx(
            () => Text(
              '已添加${DanmakuShieldStorage.shieldList.length}个关键词（点击移除）',
              style: Get.textTheme.titleSmall,
            ),
          ),
          AppStyle.vGap12,
          Obx(
            () => Wrap(
              runSpacing: 12,
              spacing: 12,
              children: DanmakuShieldStorage.shieldList
                  .map(
                    (item) => InkWell(
                      borderRadius: AppStyle.radius24,
                      onTap: () {
                        DanmakuShieldStorage.removeShieldList(item);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: AppStyle.radius24,
                        ),
                        padding: AppStyle.edgeInsetsH12.copyWith(
                          top: 4,
                          bottom: 4,
                        ),
                        child: Text(
                          item,
                          style: Get.textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  void showPlayerSettingsSheet() {
    Utils.showBottomSheet(
      scrollControlDisabledMaxHeightRatio: 0.7,
      title: '播放设置',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: ListView(
          padding: AppStyle.edgeInsetsV12,
          children: [
            Padding(
              padding: AppStyle.edgeInsetsA12.copyWith(top: 0),
              child: Text(
                '画质',
                style: Get.textTheme.titleSmall,
              ),
            ),
            Obx(
              () => SettingsCard(
                child: SettingsSwitch(
                  title: '超分辨率',
                  subtitle: 'GPU 硬件解码 + 高质量缩放',
                  value: superResolution.value,
                  onChanged: toggleSuperResolution,
                ),
              ),
            ),
            Obx(
              () => SettingsCard(
                child: SettingsSwitch(
                  title: '4K 渲染',
                  subtitle: '固定 3840×2160 视频输出（需要 GPU 性能）',
                  value: render4K.value,
                  onChanged: toggleRender4K,
                ),
              ),
            ),
            Obx(
              () => SettingsCard(
                child: ListTile(
                  title: const Text('超分引擎'),
                  subtitle: Text(
                    upscaler.value.description,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  trailing: Text(upscaler.value.label),
                  onTap: showUpscalerPicker,
                ),
              ),
            ),
            Padding(
              padding: AppStyle.edgeInsetsA12.copyWith(top: 12),
              child: Text(
                '画面尺寸',
                style: Get.textTheme.titleSmall,
              ),
            ),
            SettingsCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Obx(
                    () => SettingsSwitch(
                      title: '适应',
                      value: scaleMode.value == 0,
                      onChanged: (e) {
                        updateScaleMode(0);
                      },
                    ),
                  ),
                  AppStyle.divider,
                  Obx(
                    () => SettingsSwitch(
                      title: '拉伸',
                      value: scaleMode.value == 1,
                      onChanged: (e) {
                        updateScaleMode(1);
                      },
                    ),
                  ),
                  AppStyle.divider,
                  Obx(
                    () => SettingsSwitch(
                      title: '铺满',
                      value: scaleMode.value == 2,
                      onChanged: (e) {
                        updateScaleMode(2);
                      },
                    ),
                  ),
                  AppStyle.divider,
                  Obx(
                    () => SettingsSwitch(
                      title: '16:9',
                      value: scaleMode.value == 3,
                      onChanged: (e) {
                        updateScaleMode(3);
                      },
                    ),
                  ),
                  AppStyle.divider,
                  Obx(
                    () => SettingsSwitch(
                      title: '4:3',
                      value: scaleMode.value == 4,
                      onChanged: (e) {
                        updateScaleMode(4);
                      },
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: AppStyle.edgeInsetsA12.copyWith(top: 12),
              child: Text(
                '播放速度',
                style: Get.textTheme.titleSmall,
              ),
            ),
            SettingsCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: speedsList.map((rate) {
                  return Obx(
                    () => SizedBox(
                      child: Column(
                        children: [
                          SettingsSwitch(
                            title: '${rate}X',
                            value: playerSpeed.value == rate,
                            onChanged: (e) {
                              setPlaybackSpeed(rate);
                            },
                          ),
                          AppStyle.divider,
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void showEpisodesSheet() {
    Utils.showRightDialog(
      title: '选集',
      width: 400,
      useSystem: true,
      child: Builder(builder: (builder) {
        WidgetsBinding.instance.addPostFrameCallback((callback) {
          if (playListScrollController2.position.hasPixels) {
            final index = episodes.indexWhere((e) => e.sort == episode);
            playListScrollController2.animateTo(index * 100,
                duration: const Duration(milliseconds: 100),
                curve: Curves.easeIn);
          }
        });
        return ListView(
          controller: playListScrollController2,
          children: episodes.map((item) {
            return Material(
              child: InkWell(
                onTap: () {
                  if (episode == item.sort) {
                    return;
                  }
                  changeEpisode(item.sort);
                  Utils.hideRightDialog();
                },
                child: Obx(() {
                  return Container(
                    height: 100,
                    decoration: BoxDecoration(
                        color: episode == item.sort
                            ? Colors.grey.withOpacity(0.2)
                            : Colors.transparent),
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          constraints: const BoxConstraints(maxWidth: 150),
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(7),
                              color: Colors.grey.withOpacity(0.1)),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: Stack(
                              alignment: AlignmentDirectional.bottomCenter,
                              // fit: StackFit.expand,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: item.image.isNotEmpty
                                      ? Image.network(
                                          item.image,
                                          width: double.infinity,
                                          height: double.infinity,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                            return noImage;
                                          },
                                        )
                                      : noImage,
                                ),
                                Positioned(
                                  bottom: 5,
                                  right: 0,
                                  child: Row(
                                    children: [
                                      Visibility(
                                        visible: true,
                                        maintainSize: false,
                                        maintainSemantics: false,
                                        maintainAnimation: false,
                                        child: Container(
                                          padding: const EdgeInsets.only(
                                              top: 1,
                                              left: 5,
                                              right: 5,
                                              bottom: 3),
                                          margin:
                                              const EdgeInsets.only(right: 5),
                                          decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(5),
                                              color:
                                                  Colors.black.withAlpha(120)),
                                          child: Text(
                                            item.status ? '有资源' : '无资源',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12),
                                          ),
                                        ),
                                      ),
                                      Visibility(
                                        visible: item.duration > 0,
                                        maintainSize: false,
                                        maintainSemantics: false,
                                        maintainAnimation: false,
                                        child: Container(
                                          padding: const EdgeInsets.only(
                                              top: 1,
                                              left: 5,
                                              right: 5,
                                              bottom: 3),
                                          margin:
                                              const EdgeInsets.only(right: 5),
                                          decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(5),
                                              color:
                                                  Colors.black.withAlpha(120)),
                                          child: Text(
                                            Duration(seconds: item.duration)
                                                .toString()
                                                .split('.')
                                                .first,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(
                          width: 10,
                        ),
                        Expanded(
                            child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '第${item.sort}集 ${item.title}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 15),
                            ),
                            Opacity(
                              opacity: 0.7,
                              child: Text(
                                Time.dateTimeFormat(item.airdate.toInt()),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            Opacity(
                              opacity: 0.7,
                              child: Text(
                                item.overview,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                ),
                              ),
                            )
                          ],
                        ))
                      ],
                    ),
                  );
                }),
              ),
            );
          }).toList(),
        );
      }),
    );
  }

  void showPlayUrlsSheet() {
    Utils.showBottomSheet(
      title: '切换线路',
      child: ListView.builder(
        itemCount: playUrls.length,
        itemBuilder: (_, i) {
          return RadioListTile(
            value: i,
            groupValue: currentLineIndex,
            title: Text('线路${i + 1}'),
            subtitle: Text(urlDecode(playUrls[i].url)),
            secondary: Text(
              playUrls[i].caption,
            ),
            onChanged: (e) {
              Get.back();
              //currentLineIndex = i;
              //setPlayer();
              changePlayLine(i);
            },
          );
        },
      ),
    );
  }

  void showVolumeSlider(BuildContext targetContext) {
    SmartDialog.showAttach(
      targetContext: targetContext,
      alignment: Alignment.topCenter,
      displayTime: const Duration(seconds: 3),
      maskColor: const Color(0x00000000),
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: AppStyle.radius12,
            color: Theme.of(context).cardColor,
          ),
          padding: AppStyle.edgeInsetsA4,
          child: SizedBox(
            width: 200,
            child: Obx(() => Slider(
                  min: 0,
                  max: 100,
                  value: playerVolume.value,
                  onChanged: (newValue) => setVolume(newValue),
                  onChangeEnd: (newValue) => persistVolume(),
                )),
          ),
        );
      },
    );
  }

  bool _disposed = false;

  @override
  void onClose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    // 退出播放页时补一次通知，让详情页的续看标记立即刷新
    if (bangumiInfo['id'] != null) {
      PlayHistoryStorage.save(id, bangumiInfo);
    }
    danmakuController = null;
    leave(true);
    // 页面销毁时释放本页自己创建的资源，否则每次进出播放页都会残留
    tabController.dispose();
    animationController.dispose();
    playListScrollController.dispose();
    playListScrollController2.dispose();
    super.onClose();
  }
}
