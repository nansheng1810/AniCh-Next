import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
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
import 'package:xs/src/pages/settings/storage/playback_markers.dart';
import 'package:xs/src/pages/settings/storage/player_storage.dart';
import 'package:xs/src/pages/settings/storage/smart_intro_storage.dart';
import 'package:xs/src/pages/settings/storage/watch_stats_storage.dart';
import 'package:xs/src/utils/account.dart';
import 'package:xs/src/utils/time.dart';
import 'package:xs/src/widgets/danmaku_local/local_danmaku.dart';
import 'package:xs/src/widgets/danmaku_local/view.dart';
import 'package:xs/src/widgets/danmaku_settings/storage.dart';
import 'package:xs/src/widgets/danmaku_shield/storage.dart';
import 'package:xs/src/utils/app_style.dart';
import 'package:xs/src/utils/color.dart';
import 'package:xs/src/utils/log.dart';
import 'package:xs/src/utils/line_speed_test.dart';
import 'package:xs/src/utils/dlna.dart';
import 'package:xs/src/utils/utils.dart';
import 'package:xs/src/widgets/danmaku_settings/view.dart';
import 'package:xs/src/widgets/danmaku_shield/view.dart';
import 'package:xs/src/widgets/ns_danmaku/danmaku_controller.dart';
import 'package:xs/src/widgets/ns_danmaku/models/danmaku_item.dart';
import 'package:xs/src/widgets/ns_danmaku/utils.dart';
import 'package:xs/src/widgets/player/controller.dart';
import 'package:xs/src/widgets/player/player_settings_view.dart';

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

  // 线路测速结果
  RxMap<int, LineSpeedResult> lineSpeedResults = <int, LineSpeedResult>{}.obs;
  RxBool lineTesting = false.obs;

  // DLNA 投屏
  final DlnaService _dlnaService = DlnaService();
  final LocalMediaServer _localMediaServer = LocalMediaServer();
  final RxList<DlnaDevice> dlnaDevices = <DlnaDevice>[].obs;
  final RxBool dlnaSearching = false.obs;
  final RxString dlnaCastingTo = ''.obs;
  DlnaDevice? _castingDevice;

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

  // 本地导入弹幕（增强）
  List<LocalDanmakuItem> localDanmakuList = [];
  RxBool localDanmakuState = LocalDanmakuStorage.enabled.obs;

  ScrollController playListScrollController = ScrollController();
  ScrollController playListScrollController2 = ScrollController();

  Map<dynamic, dynamic> bangumiInfo = {'episodes': []};

  RxInt lastPosition = 0.obs;

  RxBool playing = true.obs;

  // 片头/片尾自动跳过只在本集触发一次，避免用户回看时被反复跳走
  bool _introSkipped = false;
  bool _outroHandled = false;

  // 智能片头学习：记录播放位置跳变，连续两次快进到相近位置时生效
  int _lastTickPosition = 0;
  bool _smartSkipNotified = false;

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
        // 本次回调的位置是跳转前的位置，等下一帧再处理片头片尾
        return;
      }
      _handleAutoSkip(currentinSeconds);
      _learnSmartIntro(currentinSeconds);
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
          // 本地导入弹幕
          if (localDanmakuList.isNotEmpty && localDanmakuState.value) {
            final currentDanmakuList = localDanmakuList.where((e) {
              return double.parse(e.time.toStringAsFixed(1)) ==
                      currentPosition / 10 &&
                  DanmakuShieldStorage.shieldCheck(e.text);
            });
            final currentDanmakuListQueue =
                currentDanmakuList.map((e) => e.toDanmakuItem()).toList();
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
    _speedTestSession += 1;
    lineTesting(false);
    lineSpeedResults.clear();
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
    if (PlayerSettingsStorage.autoFastestLine && data.data.length > 1) {
      testLineSpeeds(autoSwitch: true);
    }
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
      _introSkipped = false;
      _outroHandled = false;
      _lastTickPosition = 0;
      _smartSkipNotified = false;
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
      // 换集/换线路后重新挂载外挂字幕，并按需自动全屏
      await applySubtitleTrack();
      await maybeEnterAutoFullscreen();

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

  // 片头/片尾自动跳过
  void _handleAutoSkip(int position) {
    // 时长未知时说明媒体还没加载好，此时 seek 也不会生效
    if (player.state.duration <= Duration.zero) {
      return;
    }
    final markers = PlaybackMarkersStorage.read(id);
    // 手动标记优先；开启智能学习时使用学到的片头结束点
    final learnedIntro = PlayerSettingsStorage.smartSkipIntro
        ? SmartIntroStorage.learned(id)
        : 0;
    final introEnd = markers.hasIntro ? markers.introEnd : learnedIntro;
    final introEnabled = markers.hasIntro
        ? PlayerSettingsStorage.skipIntro
        : PlayerSettingsStorage.smartSkipIntro && learnedIntro > 0;
    if (introEnabled && !_introSkipped && position < introEnd) {
      _introSkipped = true;
      player.seek(Duration(seconds: introEnd));
      SmartDialog.showToast('已跳过片头');
      return;
    }
    if (PlayerSettingsStorage.skipOutro &&
        markers.hasOutro &&
        !_outroHandled &&
        position >= markers.outroStart) {
      _outroHandled = true;
      if (sleepAtEpisodeEnd.value) {
        cancelSleepTimer();
        player.pause();
        SmartDialog.showToast('已到片尾，本集播放结束');
        return;
      }
      if (nextEpisodeData() != null) {
        SmartDialog.showToast('已跳过片尾，播放下一集');
        playNextEpisode();
      } else if (player.state.duration > Duration.zero) {
        player.seek(player.state.duration);
      }
    }
  }

  // 智能学习：用户从片头区域快进时记录落点，重复落点视为片头结束
  void _learnSmartIntro(int position) {
    final previous = _lastTickPosition;
    _lastTickPosition = position;
    if (!PlayerSettingsStorage.smartSkipIntro) {
      return;
    }
    if (previous <= 0 ||
        position <= previous ||
        position - previous < 8 ||
        previous > 120 ||
        position > 300) {
      return;
    }
    final learned = SmartIntroStorage.addCandidate(id, position);
    if (learned != null && !_smartSkipNotified) {
      _smartSkipNotified = true;
      SmartDialog.showToast(
        '已学习片头结束点：${formatPlaybackTime(Duration(seconds: learned))}',
      );
    }
  }

  // ---------- 本地弹幕（增强） ----------

  void loadLocalDanmaku() {
    localDanmakuList = LocalDanmakuStorage.load(id, episode);
  }

  void setLocalDanmakuEnabled(bool value) {
    localDanmakuState(value);
    LocalDanmakuStorage.setEnabled(value);
  }

  Future<void> importLocalDanmakuFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'xml', 'txt'],
      );
      final path = result?.files.single.path;
      if (path == null) {
        return;
      }
      final content = await File(path).readAsString();
      final items = DanmakuFileCodec.decode(content);
      if (items.isEmpty) {
        SmartDialog.showToast('未从文件中解析到弹幕');
        return;
      }
      final added = LocalDanmakuStorage.merge(id, episode, items);
      loadLocalDanmaku();
      if (!localDanmakuState.value) {
        setLocalDanmakuEnabled(true);
      }
      SmartDialog.showToast(
        '已导入 $added 条，自动去重（文件共 ${items.length} 条）',
      );
    } catch (_) {
      SmartDialog.showToast('弹幕导入失败，请检查文件格式');
    }
  }

  /// 合并当前所有来源的弹幕，含本地导入。
  List<LocalDanmakuItem> collectAllDanmaku() {
    final map = <String, LocalDanmakuItem>{};
    void add(LocalDanmakuItem item) {
      if (item.text.isNotEmpty) {
        map.putIfAbsent(item.key, () => item);
      }
    }

    for (final e in danmakuList) {
      add(LocalDanmakuItem(
        time: e.time.toDouble(),
        text: e.text,
        type: DanmakuUtils.getPosition(e.type),
        color: _hexToDecimal(e.color),
      ));
    }
    for (final e in bilibiliDanmakuList) {
      add(LocalDanmakuItem(
        time: e.progress / 1000,
        text: e.content,
        type: DanmakuUtils.getBilibiliPosition(e.mode),
        color: e.color,
      ));
    }
    for (final e in bilibiliHmtDanmakuList) {
      add(LocalDanmakuItem(
        time: e.progress / 1000,
        text: e.content,
        type: DanmakuUtils.getBilibiliPosition(e.mode),
        color: e.color,
      ));
    }
    for (final e in qqDanmakuList) {
      add(LocalDanmakuItem(
        time: (int.tryParse(e.timeOffset ?? '0') ?? 0) / 1000,
        text: e.content ?? '',
        type: DanmakuUtils.getQQPosition(e.rickType ?? 1),
      ));
    }
    for (final e in localDanmakuList) {
      add(e);
    }
    return map.values.toList()..sort((a, b) => a.time.compareTo(b.time));
  }

  Future<void> exportDanmakuFile({required bool asXml}) async {
    final items = collectAllDanmaku();
    if (items.isEmpty) {
      SmartDialog.showToast('当前没有可导出的弹幕');
      return;
    }
    final safeTitle =
        (data.title ?? 'danmaku').replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: '导出弹幕',
        fileName: '$safeTitle-第$episode集.${asXml ? 'xml' : 'json'}',
        type: FileType.custom,
        allowedExtensions: [asXml ? 'xml' : 'json'],
      );
      if (path == null) {
        return;
      }
      final content = asXml
          ? DanmakuFileCodec.encodeXml(items)
          : DanmakuFileCodec.encodeJson(items);
      await File(path).writeAsString(content);
      SmartDialog.showToast('已导出 ${items.length} 条弹幕');
    } catch (_) {
      SmartDialog.showToast('弹幕导出失败');
    }
  }

  void clearLocalDanmaku() {
    LocalDanmakuStorage.clear(id, episode);
    loadLocalDanmaku();
    SmartDialog.showToast('已清空本集本地弹幕');
  }

  List<DanmakuSearchResult> searchDanmaku(String keyword) {
    final kw = keyword.trim().toLowerCase();
    if (kw.isEmpty) {
      return [];
    }
    final results = <DanmakuSearchResult>[];
    for (final e in danmakuList) {
      if (e.text.toLowerCase().contains(kw)) {
        results.add(DanmakuSearchResult(
          time: e.time.toDouble(),
          text: e.text,
          source: '本站',
        ));
      }
    }
    for (final e in bilibiliDanmakuList) {
      if (e.content.toLowerCase().contains(kw)) {
        results.add(DanmakuSearchResult(
          time: e.progress / 1000,
          text: e.content,
          source: '哔哩哔哩',
        ));
      }
    }
    for (final e in bilibiliHmtDanmakuList) {
      if (e.content.toLowerCase().contains(kw)) {
        results.add(DanmakuSearchResult(
          time: e.progress / 1000,
          text: e.content,
          source: '哔哩哔哩港澳台',
        ));
      }
    }
    for (final e in qqDanmakuList) {
      final text = e.content ?? '';
      if (text.toLowerCase().contains(kw)) {
        results.add(DanmakuSearchResult(
          time: (int.tryParse(e.timeOffset ?? '0') ?? 0) / 1000,
          text: text,
          source: '腾讯视频',
        ));
      }
    }
    for (final e in localDanmakuList) {
      if (e.text.toLowerCase().contains(kw)) {
        results.add(DanmakuSearchResult(
          time: e.time,
          text: e.text,
          source: '本地',
        ));
      }
    }
    results.sort((a, b) => a.time.compareTo(b.time));
    return results.take(300).toList();
  }

  void showDanmakuSearch() {
    final keywordController = TextEditingController();
    Utils.showBottomSheet(
      title: '弹幕搜索',
      scrollControlDisabledMaxHeightRatio: 0.85,
      child: StatefulBuilder(
        builder: (context, setState) {
          final results = searchDanmaku(keywordController.text);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  controller: keywordController,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    isDense: true,
                    border: const OutlineInputBorder(),
                    hintText: '输入关键词搜索当前弹幕',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: keywordController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              keywordController.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.clear),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: results.isEmpty
                    ? Center(
                        child: Text(
                          keywordController.text.isEmpty
                              ? '输入关键词开始搜索'
                              : '没有匹配的弹幕',
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      )
                    : ListView.builder(
                        itemCount: results.length,
                        itemBuilder: (context, index) {
                          final item = results[index];
                          return ListTile(
                            dense: true,
                            leading: Text(
                              formatPlaybackTime(item.position),
                              style: const TextStyle(fontSize: 12),
                            ),
                            title: Text(
                              item.text,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              item.source,
                              style: const TextStyle(fontSize: 11),
                            ),
                            onTap: () {
                              player.seek(item.position);
                              Get.back();
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  int _hexToDecimal(String? value) {
    if (value == null) {
      return 0xFFFFFF;
    }
    var text = value.trim();
    if (text.startsWith('#')) {
      text = text.substring(1);
    }
    if (text.length == 8) {
      text = text.substring(2);
    }
    return int.tryParse(text, radix: 16) ?? 0xFFFFFF;
  }

  // 本集播放结束：记录完成集数，按设置自动连播或暂停
  @override
  void mediaEnd() {
    WatchStatsStorage.addCompleted(id, episode);
    if (sleepAtEpisodeEnd.value) {
      cancelSleepTimer();
      showControls();
      SmartDialog.showToast('本集播放结束，已停止播放');
      return;
    }
    if (autoPlayNext.value && nextEpisodeData() != null) {
      playNextEpisode();
      return;
    }
    showControls();
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

  // 批量缓存本番剧所有有资源的剧集
  Future<void> batchDownload() async {
    if (episodes.isEmpty) {
      SmartDialog.showToast('剧集信息尚未加载完成');
      return;
    }
    final manager = Get.isRegistered<DownloadManager>()
        ? DownloadManager.instance
        : Get.put(DownloadManager());
    final pending = episodes
        .where((e) => e.status)
        .where((e) =>
            !manager.tasks.any((t) => t.bangumiId == id && t.episode == e.sort))
        .toList();
    if (pending.isEmpty) {
      SmartDialog.showToast('全部剧集已在缓存队列中');
      return;
    }
    final confirm = await Utils.showAlertDialog(
      '将为 ${pending.length} 集加入离线缓存，自动跳过无资源与 m3u8 线路，是否继续？',
      title: '批量缓存',
      confirm: '开始',
    );
    if (!confirm) {
      return;
    }
    var added = 0;
    var skipped = 0;
    SmartDialog.showLoading(msg: '正在添加缓存任务');
    for (final item in pending) {
      try {
        final response = await BangumiApi.getBangumiEpisodeVod(
          id: id,
          episode: item.sort,
        );
        if (response.statusCode != 200) {
          skipped += 1;
          continue;
        }
        final vodData = vod_.fromBuffer(response.data.cast<int>());
        final index = vodData.data.indexWhere((e) {
          final url = urlDecode(e.url);
          return url.isNotEmpty && !url.contains('.m3u8');
        });
        if (index < 0) {
          skipped += 1;
          continue;
        }
        final ok = await manager.addTask(
          bangumiId: id,
          episode: item.sort,
          title: data.title ?? '',
          episodeTitle: item.title,
          image: item.image,
          lineIndex: index,
          url: urlDecode(vodData.data[index].url),
        );
        if (ok) {
          added += 1;
        } else {
          skipped += 1;
        }
      } catch (_) {
        skipped += 1;
      }
    }
    SmartDialog.dismiss(status: SmartStatus.loading);
    SmartDialog.showToast('已加入 $added 集缓存，跳过 $skipped 集');
  }

  // 切换线路
  void changePlayLine(int index) {
    currentLineIndex = index;
    setPlayer();
  }

  // ---------- 多线路测速（增强） ----------

  int _speedTestSession = 0;

  Future<void> testLineSpeeds({bool autoSwitch = false}) async {
    if (playUrls.isEmpty || lineTesting.value) {
      return;
    }
    final session = ++_speedTestSession;
    lineTesting(true);
    lineSpeedResults.clear();
    final results = await Future.wait(
      playUrls.asMap().entries.map((entry) async {
        final result = await LineSpeedTester.test(urlDecode(entry.value.url));
        return MapEntry(entry.key, result);
      }),
    );
    if (session != _speedTestSession) {
      return;
    }
    for (final entry in results) {
      lineSpeedResults[entry.key] = entry.value;
    }
    lineTesting(false);
    if (autoSwitch) {
      final best = fastestLineIndex();
      if (best != null && best != currentLineIndex) {
        SmartDialog.showToast('已自动切换到最快线路${best + 1}');
        changePlayLine(best);
        return;
      }
    }
    if (results.every((e) => e.value.error)) {
      SmartDialog.showToast('测速失败，请检查网络');
    }
  }

  int? fastestLineIndex() {
    int? best;
    double bestScore = double.negativeInfinity;
    for (final entry in lineSpeedResults.entries) {
      if (entry.value.error) {
        continue;
      }
      final score =
          entry.value.speedKbps * 1000 - entry.value.latencyMs.toDouble();
      if (score > bestScore) {
        bestScore = score;
        best = entry.key;
      }
    }
    return best;
  }

  String lineSpeedText(int index) {
    final result = lineSpeedResults[index];
    if (result != null) {
      return result.text;
    }
    return lineTesting.value ? '测速中…' : '';
  }

  // ---------- DLNA 投屏（增强） ----------

  Future<void> searchDlnaDevices() async {
    if (dlnaSearching.value) {
      return;
    }
    dlnaSearching(true);
    dlnaDevices.clear();
    final devices = await _dlnaService.discover();
    dlnaDevices.assignAll(devices);
    dlnaSearching(false);
    if (devices.isEmpty) {
      SmartDialog.showToast('未发现 DLNA 设备，请检查电视与网络');
    }
  }

  void showDlnaSheet() {
    final manager = Get.isRegistered<DownloadManager>()
        ? DownloadManager.instance
        : Get.put(DownloadManager());
    final localPath = manager.localPath(id, episode, currentLineIndex);
    Utils.showBottomSheet(
      title: '投屏到电视（DLNA）',
      scrollControlDisabledMaxHeightRatio: 0.85,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    localPath != null ? '使用本地缓存，通过局域网推送到电视' : '使用当前线路地址推送到电视',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
                Obx(
                  () => TextButton.icon(
                    onPressed: dlnaSearching.value ? null : searchDlnaDevices,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: Text(dlnaSearching.value ? '搜索中…' : '搜索设备'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Obx(
              () {
                if (dlnaSearching.value && dlnaDevices.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (dlnaDevices.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        '未发现 DLNA 设备\n请确认电视与电脑连接同一局域网，并开启投屏功能',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: dlnaDevices.length,
                  itemBuilder: (context, index) {
                    final device = dlnaDevices[index];
                    return ListTile(
                      leading: const Icon(Icons.tv),
                      title: Text(device.name),
                      subtitle: Text(device.host),
                      trailing: dlnaCastingTo.value == device.name
                          ? const Text(
                              '投屏中',
                              style: TextStyle(color: Colors.green),
                            )
                          : const Icon(Icons.chevron_right),
                      onTap: () => castToDevice(device, localPath),
                    );
                  },
                );
              },
            ),
          ),
          Obx(
            () => dlnaCastingTo.value.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '正在投屏：${dlnaCastingTo.value}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        TextButton(
                          onPressed: pauseCasting,
                          child: const Text('暂停'),
                        ),
                        TextButton(
                          onPressed: stopCasting,
                          child: const Text('停止投屏'),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
    if (dlnaDevices.isEmpty) {
      searchDlnaDevices();
    }
  }

  Future<void> castToDevice(DlnaDevice device, String? localPath) async {
    try {
      final url = localPath != null
          ? await _localMediaServer.serve(localPath)
          : (playUrls.isNotEmpty && currentLineIndex >= 0
              ? urlDecode(playUrls[currentLineIndex].url)
              : '');
      if (url.isEmpty) {
        SmartDialog.showToast('当前没有可投屏的播放地址');
        return;
      }
      await _dlnaService.setAvTransportUri(
        device,
        url,
        title: '${data.title ?? 'AniCh'} 第$episode集',
      );
      await _dlnaService.play(device);
      _castingDevice = device;
      dlnaCastingTo(device.name);
      SmartDialog.showToast('已投屏到 ${device.name}');
    } catch (_) {
      SmartDialog.showToast('投屏失败，请确认设备支持 DLNA');
    }
  }

  Future<void> pauseCasting() async {
    final device = _castingDevice;
    if (device == null) {
      return;
    }
    try {
      await _dlnaService.pause(device);
      SmartDialog.showToast('已在电视上暂停');
    } catch (_) {
      SmartDialog.showToast('暂停失败');
    }
  }

  Future<void> stopCasting() async {
    final device = _castingDevice;
    if (device == null) {
      return;
    }
    try {
      await _dlnaService.stop(device);
    } catch (_) {
      // 设备已断开时忽略
    }
    _castingDevice = null;
    dlnaCastingTo('');
    await _localMediaServer.stop();
    SmartDialog.showToast('已停止投屏');
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
    loadLocalDanmaku();
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
          const SizedBox(height: 12),
          LocalDanmakuSettings(controller: this),
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
      child: PlayerSettingsView(controller: this),
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
      scrollControlDisabledMaxHeightRatio: 0.8,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Obx(
                  () => TextButton.icon(
                    onPressed:
                        lineTesting.value ? null : () => testLineSpeeds(),
                    icon: const Icon(Icons.speed, size: 16),
                    label: Text(lineTesting.value ? '测速中…' : '线路测速'),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => testLineSpeeds(autoSwitch: true),
                  icon: const Icon(Icons.auto_fix_high, size: 16),
                  label: const Text('自动选最快'),
                ),
                const Spacer(),
                if (playUrls.isNotEmpty)
                  Text(
                    '共 ${playUrls.length} 条',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Obx(
              () => ListView.builder(
                itemCount: playUrls.length,
                itemBuilder: (_, i) {
                  final speed = lineSpeedText(i);
                  return RadioListTile(
                    value: i,
                    groupValue: currentLineIndex,
                    title: Text('线路${i + 1}'),
                    subtitle: Text(
                      speed.isEmpty
                          ? urlDecode(playUrls[i].url)
                          : '${urlDecode(playUrls[i].url)}\n$speed',
                    ),
                    secondary: Text(playUrls[i].caption),
                    onChanged: (e) {
                      Get.back();
                      changePlayLine(i);
                    },
                  );
                },
              ),
            ),
          ),
        ],
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
    // 释放 DLNA 本地投屏服务
    _localMediaServer.stop();
    _dlnaService.dispose();
    super.onClose();
  }
}
