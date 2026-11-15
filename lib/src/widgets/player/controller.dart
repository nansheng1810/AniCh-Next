import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:auto_orientation/auto_orientation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:floating/floating.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:perfect_volume_control/perfect_volume_control.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';
import 'package:xs/src/pages/settings/storage/player_storage.dart';
import 'package:xs/src/pages/settings/storage/watch_stats_storage.dart';
import 'package:xs/src/utils/app_style.dart';
import 'package:xs/src/utils/custom_throttle.dart';
import 'package:xs/src/utils/log.dart';
import 'package:xs/src/utils/utils.dart';
import 'package:xs/src/widgets/danmaku_settings/storage.dart';
import 'package:xs/src/widgets/ns_danmaku/danmaku_controller.dart';
import 'package:xs/src/widgets/ns_danmaku/models/danmaku_item.dart';
import 'package:xs/src/widgets/ns_danmaku/models/danmaku_option.dart';
import 'package:xs/src/widgets/player/upscaler.dart';

/// 播放时间格式化：去掉小时前的 0:，例如 01:23:45 → 1:23:45、00:12:34 → 12:34。
String formatPlaybackTime(Duration duration) {
  final text = duration.toString().split('.').first;
  return text.startsWith('0:') ? text.substring(2) : text;
}

mixin PlayerMixin {
  GlobalKey<VideoState> globalPlayerKey = GlobalKey<VideoState>();
  GlobalKey globalDanmuKey = GlobalKey();

  // 播放器实例
  late final player = Player();

  // 视频控制器
  late final videoController = VideoController(
    player,
  );
}

mixin PlayerStateMixin on PlayerMixin {
  // 音量控制条计时器
  Timer? hidevolumeTimer;

  // 是否进入桌面端小窗
  RxBool smallWindowState = false.obs;

  // 是否显示弹幕
  RxBool showDanmakuState = true.obs;

  // 是否显示弹幕发送框
  RxBool showDanmakuTextField = false.obs;

  // 是否显示控制器
  RxBool showControlsState = false.obs;

  // 是否显示设置窗口
  RxBool showSettingState = false.obs;

  // 是否显示弹幕设置窗口
  RxBool showDanmakuSettingState = false.obs;

  // 是否处于锁定控制器状态
  RxBool lockControlsState = false.obs;

  // 是否处于全屏状态
  RxBool fullScreenState = false.obs;

  // 播放器焦点节点：进入/退出全屏后把键盘焦点拉回 Flutter 视图，
  // 否则窗口切换全屏后方向键等快捷键会失效。
  final FocusNode playerFocusNode = FocusNode(debugLabel: 'player');

  // 显示手势Tip
  RxBool showGestureTip = false.obs;

  // 手势Tip文本
  RxString gestureTipText = ''.obs;

  // 显示提示底部Tip
  RxBool showBottomTip = false.obs;

  // 提示底部Tip文本
  RxString bottomTipText = ''.obs;

  // 自动隐藏控制器计时器
  Timer? hideControlsTimer;

  // 自动隐藏提示计时器
  Timer? hideSeekTipTimer;

  // 是否为竖屏直播间
  var isVertical = false.obs;

  // 画面尺寸
  RxInt scaleMode = 0.obs;
  BoxFit boxFit = BoxFit.contain;
  double? aspectRatio;

  // 超分辨率（GPU 硬件解码 + 高质量缩放）
  RxBool superResolution = PlayerSettingsStorage.superResolution.obs;

  // 4K 渲染（固定 3840x2160 视频输出）
  RxBool render4K = PlayerSettingsStorage.render4K.obs;

  // 硬件解码方式与 HDR 色调映射
  RxString hwdec = PlayerSettingsStorage.hwdec.obs;
  RxString hdrToneMapping = PlayerSettingsStorage.hdrToneMapping.obs;

  // 静音前的音量，用于 M 键恢复
  double _volumeBeforeMute = 100;

  // 超分引擎（mpv 用户着色器）
  Rx<UpscalerEngine> upscaler = _readUpscaler().obs;

  static UpscalerEngine _readUpscaler() {
    final id = PlayerSettingsStorage.upscaler;
    return UpscalerEngine.values.firstWhere(
      (engine) => engine.id == id,
      orElse: () => UpscalerEngine.none,
    );
  }

  // 超分引擎可调参数（键为 "引擎id:参数名"）
  RxMap<String, double> upscalerParams =
      PlayerSettingsStorage.upscalerNumeric.obs;
  RxMap<String, String> upscalerChoices =
      PlayerSettingsStorage.upscalerChoices.obs;

  // 播放倍速
  RxDouble playerSpeed = 1.0.obs;
  final List<double> speedsList = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  // 音量（0-100）
  RxDouble playerVolume = 100.0.obs;

  Widget? danmakuView;

  var showQualites = false.obs;
  var showLines = false.obs;

  // 是否显示哔哩哔哩弹幕
  RxBool bilibiliDanmakuState = true.obs;
  RxBool bilibiliHmtDanmakuState = true.obs;

  // 是否显示腾讯视频弹幕
  RxBool qqDanmakuState = true.obs;

  // 播放行为
  RxBool autoFullscreen = PlayerSettingsStorage.autoFullscreen.obs;
  RxBool autoPlayNext = PlayerSettingsStorage.autoPlayNext.obs;
  RxBool longPressSpeedEnabled = PlayerSettingsStorage.longPressSpeed.obs;
  RxDouble longPressSpeedValue = PlayerSettingsStorage.longPressSpeedValue.obs;

  // 外挂字幕
  RxString subtitlePath = ''.obs;
  RxDouble subtitleFontSize = PlayerSettingsStorage.subtitleFontSize.obs;
  RxDouble subtitleOutline = PlayerSettingsStorage.subtitleOutline.obs;
  RxDouble subtitleBottomPadding =
      PlayerSettingsStorage.subtitleBottomPadding.obs;
  RxBool subtitleBold = PlayerSettingsStorage.subtitleBold.obs;
  RxDouble subtitleDelay = PlayerSettingsStorage.subtitleDelay.obs;

  // 睡眠定时（剩余秒数，0 表示关闭）
  RxInt sleepRemaining = 0.obs;
  RxBool sleepAtEpisodeEnd = false.obs;
  Timer? _sleepTimer;

  // 长按倍速恢复用的原始倍速
  double? _speedBeforeBoost;

  // 设置倍速
  Future setPlaybackSpeed(double rate) async {
    try {
      await player.setRate(rate);
    } catch (e) {
      debugPrint(e.toString());
    }
    playerSpeed(rate);
    PlayerSettingsStorage.setSpeed(rate);
  }

  // 设置音量
  void setVolume(double value) {
    final volume = value.clamp(0.0, 100.0);
    player.setVolume(volume);
    playerVolume(volume);
  }

  // 拖动结束后再落盘，避免滑块拖动过程频繁写入
  void persistVolume() {
    PlayerSettingsStorage.setVolume(playerVolume.value);
  }

  // 播放行为设置
  void setAutoFullscreen(bool value) {
    autoFullscreen(value);
    PlayerSettingsStorage.setAutoFullscreen(value);
  }

  void setAutoPlayNext(bool value) {
    autoPlayNext(value);
    PlayerSettingsStorage.setAutoPlayNext(value);
  }

  void setLongPressSpeedEnabled(bool value) {
    longPressSpeedEnabled(value);
    PlayerSettingsStorage.setLongPressSpeed(value);
  }

  void setLongPressSpeedValue(double value) {
    final speed = value.clamp(1.5, 4.0);
    longPressSpeedValue(speed);
    PlayerSettingsStorage.setLongPressSpeedValue(speed);
  }

  // 长按临时倍速：只在按住期间生效，不覆盖用户默认倍速
  Future<void> startLongPressBoost() async {
    if (!longPressSpeedEnabled.value || _speedBeforeBoost != null) {
      return;
    }
    _speedBeforeBoost = playerSpeed.value;
    try {
      await player.setRate(longPressSpeedValue.value);
    } catch (e) {
      debugPrint(e.toString());
    }
    _showPlayerTip('${longPressSpeedValue.value}X 倍速');
  }

  Future<void> stopLongPressBoost() async {
    final speed = _speedBeforeBoost;
    if (speed == null) {
      return;
    }
    _speedBeforeBoost = null;
    try {
      await player.setRate(speed);
    } catch (e) {
      debugPrint(e.toString());
    }
    _showPlayerTip('${speed}X 倍速');
  }

  // 外挂字幕：选择本地字幕文件
  Future<void> pickSubtitleFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['srt', 'ass', 'ssa', 'vtt', 'sub'],
      );
      final path = result?.files.single.path;
      if (path == null) {
        return;
      }
      subtitlePath(path);
      await applySubtitleTrack();
      SmartDialog.showToast('已加载字幕');
    } catch (e) {
      SmartDialog.showToast('字幕加载失败');
    }
  }

  // 重新挂载当前外挂字幕（换集/换线路后调用）
  Future<void> applySubtitleTrack() async {
    final path = subtitlePath.value;
    if (path.isEmpty) {
      return;
    }
    try {
      await player.setSubtitleTrack(
        SubtitleTrack.uri(
          Uri.file(path).toString(),
          title: path.split(RegExp(r'[\\/]')).last,
        ),
      );
      await applySubtitleDelay();
    } catch (e) {
      SmartDialog.showToast('字幕加载失败：$e');
    }
  }

  Future<void> clearSubtitle() async {
    subtitlePath('');
    try {
      await player.setSubtitleTrack(SubtitleTrack.no());
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  // 字幕样式：由 Flutter 字幕层渲染，实时生效
  SubtitleViewConfiguration buildSubtitleViewConfiguration() {
    final outline = subtitleOutline.value;
    final shadows = outline <= 0
        ? null
        : <Shadow>[
            Shadow(
                color: Colors.black,
                offset: Offset(-outline, -outline),
                blurRadius: outline),
            Shadow(
                color: Colors.black,
                offset: Offset(outline, -outline),
                blurRadius: outline),
            Shadow(
                color: Colors.black,
                offset: Offset(-outline, outline),
                blurRadius: outline),
            Shadow(
                color: Colors.black,
                offset: Offset(outline, outline),
                blurRadius: outline),
          ];
    return SubtitleViewConfiguration(
      style: TextStyle(
        height: 1.4,
        fontSize: subtitleFontSize.value,
        color: Colors.white,
        fontWeight: subtitleBold.value ? FontWeight.bold : FontWeight.normal,
        shadows: shadows,
      ),
      padding: EdgeInsets.fromLTRB(16, 0, 16, subtitleBottomPadding.value),
    );
  }

  void setSubtitleFontSize(double value) {
    final size = value.clamp(16.0, 64.0);
    subtitleFontSize(size);
    PlayerSettingsStorage.setSubtitleFontSize(size);
  }

  void setSubtitleOutline(double value) {
    final outline = value.clamp(0.0, 4.0);
    subtitleOutline(outline);
    PlayerSettingsStorage.setSubtitleOutline(outline);
  }

  void setSubtitleBottomPadding(double value) {
    final padding = value.clamp(0.0, 160.0);
    subtitleBottomPadding(padding);
    PlayerSettingsStorage.setSubtitleBottomPadding(padding);
  }

  void setSubtitleBold(bool value) {
    subtitleBold(value);
    PlayerSettingsStorage.setSubtitleBold(value);
  }

  Future<void> applySubtitleDelay() async {
    final platform = player.platform;
    if (platform is NativePlayer) {
      try {
        await platform.setProperty(
          'sub-delay',
          subtitleDelay.value.toStringAsFixed(2),
        );
      } catch (e) {
        debugPrint(e.toString());
      }
    }
  }

  void setSubtitleDelay(double value) {
    final delay = value.clamp(-10.0, 10.0);
    subtitleDelay(delay);
    PlayerSettingsStorage.setSubtitleDelay(delay);
    applySubtitleDelay();
  }

  // 睡眠定时
  void setSleepTimer(Duration? duration) {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    sleepAtEpisodeEnd(false);
    if (duration == null) {
      sleepRemaining(0);
      return;
    }
    sleepRemaining(duration.inSeconds);
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (sleepRemaining.value <= 1) {
        cancelSleepTimer();
        if (player.state.playing) {
          player.pause();
        }
        SmartDialog.showToast('睡眠定时结束，已暂停播放');
        showControls();
      } else {
        sleepRemaining.value--;
      }
    });
    SmartDialog.showToast('将在${_sleepLabel(duration.inSeconds)}后暂停');
  }

  // 本集播完后暂停
  void setSleepAtEpisodeEnd(bool value) {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    sleepRemaining(0);
    sleepAtEpisodeEnd(value);
    if (value) {
      SmartDialog.showToast('本集播放结束后自动暂停');
    }
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    sleepRemaining(0);
    sleepAtEpisodeEnd(false);
  }

  String get sleepTimerLabel {
    if (sleepAtEpisodeEnd.value) {
      return '本集结束后暂停';
    }
    if (sleepRemaining.value <= 0) {
      return '关闭';
    }
    return _sleepLabel(sleepRemaining.value);
  }

  String _sleepLabel(int seconds) {
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    if (minutes <= 0) {
      return '$rest秒';
    }
    return rest == 0 ? '$minutes分钟' : '$minutes分$rest秒';
  }

  void _showPlayerTip(String text) {
    gestureTipText.value = text;
    showGestureTip.value = true;
    hideSeekTipTimer?.cancel();
    hideSeekTipTimer = Timer(const Duration(milliseconds: 900), () {
      showGestureTip.value = false;
    });
  }

  // 获取视频分辨率文本
  String getRatioText() {
    if (player.state.width != null) {
      return ' (${player.state.width}x${player.state.height})';
    } else {
      return '';
    }
  }

  // 隐藏控制器
  void hideControls() {
    showControlsState.value = false;
    hideControlsTimer?.cancel();
  }

  void setLockState() {
    lockControlsState.value = !lockControlsState.value;
    if (lockControlsState.value) {
      showControlsState.value = false;
    } else {
      showControlsState.value = true;
    }
  }

  // 显示控制器
  void showControls() {
    showControlsState.value = true;
    resetHideControlsTimer();
  }

  // 开始隐藏控制器计时
  // - 当点击控制器上时功能时需要重新计时
  void resetHideControlsTimer() {
    hideControlsTimer?.cancel();

    hideControlsTimer = Timer(
      const Duration(
        seconds: 5,
      ),
      hideControls,
    );
  }

  void updateScaleMode(int value) {
    scaleMode(value);
    PlayerSettingsStorage.setScaleMode(value);
    if (player.state.width != null && player.state.height != null) {
      aspectRatio = player.state.width! / player.state.height!;
    }

    if (scaleMode.value == 0) {
      boxFit = BoxFit.contain;
    } else if (scaleMode.value == 1) {
      boxFit = BoxFit.fill;
    } else if (scaleMode.value == 2) {
      boxFit = BoxFit.cover;
    } else if (scaleMode.value == 3) {
      boxFit = BoxFit.contain;
      aspectRatio = 16 / 9;
    } else if (scaleMode.value == 4) {
      boxFit = BoxFit.contain;
      aspectRatio = 4 / 3;
    }

    globalPlayerKey.currentState?.update(
      aspectRatio: aspectRatio,
      fit: boxFit,
    );
  }

  // 应用超分辨率参数
  Future<void> applySuperResolution() async {
    final platform = player.platform;
    if (platform is! NativePlayer) {
      return;
    }
    try {
      // 先应用用户选择的解码方式与 HDR 色调映射
      await applyDecoderSettings();
      if (superResolution.value) {
        // GPU 缩放算法
        await platform.setProperty('scale', 'ewa_lanczossharp');
        await platform.setProperty('cscale', 'ewa_lanczossharp');
        await platform.setProperty('dscale', 'mitchell');
        await platform.setProperty('correct-downscaling', 'yes');
        await platform.setProperty('linear-downscaling', 'no');
        await platform.setProperty('sigmoid-upscaling', 'yes');
        await platform.setProperty('deband', 'yes');
      } else {
        await platform.setProperty('scale', 'bilinear');
        await platform.setProperty('cscale', 'bilinear');
        await platform.setProperty('dscale', 'bilinear');
        await platform.setProperty('correct-downscaling', 'no');
        await platform.setProperty('linear-downscaling', 'yes');
        await platform.setProperty('sigmoid-upscaling', 'no');
        await platform.setProperty('deband', 'no');
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  // 应用硬件解码与 HDR 色调映射（播放开始与设置变更时调用）
  Future<void> applyDecoderSettings() async {
    if (kIsWeb) {
      return;
    }
    final platform = player.platform;
    if (platform is! NativePlayer) {
      return;
    }
    try {
      await platform.setProperty('hwdec', hwdec.value);
      await platform.setProperty('tone-mapping', hdrToneMapping.value);
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  // 切换硬件解码方式并持久化
  void setHwdec(String value) {
    hwdec(value);
    PlayerSettingsStorage.setHwdec(value);
    applyDecoderSettings();
  }

  // 切换 HDR 色调映射并持久化
  void setHdrToneMapping(String value) {
    hdrToneMapping(value);
    PlayerSettingsStorage.setHdrToneMapping(value);
    applyDecoderSettings();
  }

  // 切换超分辨率并持久化
  void toggleSuperResolution(bool value) {
    superResolution(value);
    PlayerSettingsStorage.setSuperResolution(value);
    applySuperResolution();
  }

  // 应用 4K / 超分引擎所需的视频输出尺寸
  Future<void> applyRenderSize() async {
    if (kIsWeb) {
      return;
    }
    if (!(Platform.isWindows ||
        Platform.isLinux ||
        Platform.isMacOS ||
        Platform.isIOS)) {
      return;
    }
    try {
      final engineActive =
          upscaler.value.available && upscaler.value != UpscalerEngine.none;
      final width = player.state.width;
      final height = player.state.height;
      if (render4K.value) {
        await videoController.setSize(width: 3840, height: 2160);
      } else if (engineActive && width != null && height != null) {
        // 着色器只在真正放大时才生效，输出按源分辨率 2 倍（上限 4K）
        await videoController.setSize(
          width: min(width * 2, 3840),
          height: min(height * 2, 2160),
        );
      } else {
        await videoController.setSize();
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  // 切换 4K 渲染并持久化
  void toggleRender4K(bool value) {
    render4K(value);
    PlayerSettingsStorage.setRender4K(value);
    applyRenderSize();
  }

  double upscalerParamValue(UpscalerEngine engine, UpscalerParamSpec spec) {
    return upscalerParams['${engine.id}:${spec.key}'] ?? spec.defaultValue;
  }

  String upscalerChoiceValue(UpscalerEngine engine, String key) {
    return upscalerChoices['${engine.id}:$key'] ??
        anime4kDefaults[key] ??
        'off';
  }

  Map<String, double> _upscalerParamsFor(UpscalerEngine engine) {
    return {
      for (final spec
          in upscalerParamSpecs[engine] ?? const <UpscalerParamSpec>[])
        spec.key: upscalerParamValue(engine, spec),
    };
  }

  Map<String, String> _upscalerChoicesFor(UpscalerEngine engine) {
    if (engine != UpscalerEngine.anime4k) {
      return const {};
    }
    return {
      for (final spec in anime4kChoiceSpecs)
        spec.key: upscalerChoiceValue(engine, spec.key),
    };
  }

  // 应用超分引擎着色器
  Future<void> applyUpscaler() async {
    final engine = upscaler.value;
    await UpscalerShaderManager.apply(
      player,
      engine,
      params: _upscalerParamsFor(engine),
      choices: _upscalerChoicesFor(engine),
    );
  }

  // 切换超分引擎并持久化（着色器需要目标输出尺寸才会真正参与放大）
  void setUpscaler(UpscalerEngine engine) {
    if (!engine.available) {
      SmartDialog.showToast('LS1 为专有算法，无法集成');
      return;
    }
    upscaler(engine);
    PlayerSettingsStorage.setUpscaler(engine.id);
    applyUpscaler();
    applyRenderSize();
  }

  // 修改引擎数值参数；apply 为 false 时只更新 UI，等拖动结束再重载着色器
  void setUpscalerParam(
    UpscalerEngine engine,
    String key,
    double value, {
    bool apply = true,
  }) {
    final storageKey = '${engine.id}:$key';
    upscalerParams[storageKey] = value;
    PlayerSettingsStorage.setUpscalerNumeric(storageKey, value);
    if (apply) {
      applyUpscaler();
    }
  }

  // 修改 Anime4K 组合选项
  void setUpscalerChoice(UpscalerEngine engine, String key, String value) {
    void write(String choiceKey, String choiceValue) {
      final storageKey = '${engine.id}:$choiceKey';
      upscalerChoices[storageKey] = choiceValue;
      PlayerSettingsStorage.setUpscalerChoice(storageKey, choiceValue);
    }

    write(key, value);
    if (key == 'preset' && anime4kPresets.containsKey(value)) {
      // 预设：先套用预设值，其余画质项回到默认
      for (final spec in anime4kChoiceSpecs) {
        if (spec.key == 'preset') {
          continue;
        }
        write(
          spec.key,
          anime4kPresets[value]![spec.key] ?? 'off',
        );
      }
      write('clamp', '1');
    } else if (key != 'preset') {
      write('preset', 'custom');
    }
    applyUpscaler();
  }

  // 恢复当前引擎的默认参数
  void resetUpscalerOptions(UpscalerEngine engine) {
    PlayerSettingsStorage.resetUpscalerOptions('${engine.id}:');
    upscalerParams.assignAll(PlayerSettingsStorage.upscalerNumeric);
    upscalerChoices.assignAll(PlayerSettingsStorage.upscalerChoices);
    applyUpscaler();
  }

  // 超分引擎选择面板
  void showUpscalerPicker() {
    Utils.showBottomSheet(
      title: '超分引擎',
      scrollControlDisabledMaxHeightRatio: 0.7,
      child: Obx(
        () => ListView(
          padding: AppStyle.edgeInsetsV12,
          children: UpscalerEngine.values.map((engine) {
            final selected = upscaler.value == engine;
            final configurable = engine.available && engine.configurable;
            return ListTile(
              enabled: engine.available,
              title: Text(engine.label),
              subtitle: Text(
                engine.available
                    ? engine.description
                    : '${engine.description}（不支持）',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (configurable)
                    IconButton(
                      tooltip: '参数',
                      icon: const Icon(Icons.tune, size: 20),
                      onPressed: () {
                        if (!selected) {
                          setUpscaler(engine);
                        }
                        showUpscalerSettings(engine);
                      },
                    ),
                  if (selected)
                    Icon(Icons.check, color: Get.theme.colorScheme.primary),
                ],
              ),
              onTap: () {
                if (!engine.available) {
                  return;
                }
                setUpscaler(engine);
                Get.back();
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  // 超分参数面板：数值滑块 + Anime4K 模型选项
  // [target] 为空时调整当前引擎，传入时直接调整指定引擎
  void showUpscalerSettings([UpscalerEngine? target]) {
    final engine = target ?? upscaler.value;
    if (!engine.configurable) {
      SmartDialog.showToast('${engine.label} 没有可调参数');
      return;
    }
    Utils.showBottomSheet(
      title: '超分参数 · ${engine.label}',
      scrollControlDisabledMaxHeightRatio: 0.8,
      child: Obx(() => _buildUpscalerSettings(engine)),
    );
  }

  Widget _buildUpscalerSettings(UpscalerEngine engine) {
    final children = <Widget>[];
    if (engine == UpscalerEngine.anime4k) {
      for (final spec in anime4kChoiceSpecs) {
        final current = upscalerChoiceValue(engine, spec.key);
        final value = spec.options.containsKey(current)
            ? current
            : spec.options.keys.first;
        children.add(
          ListTile(
            title: Text(spec.label),
            trailing: DropdownButton<String>(
              value: value,
              isDense: true,
              underline: const SizedBox.shrink(),
              items: spec.options.entries
                  .map(
                    (e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value),
                    ),
                  )
                  .toList(),
              onChanged: (next) {
                if (next != null) {
                  setUpscalerChoice(engine, spec.key, next);
                }
              },
            ),
          ),
        );
      }
      children.add(
        SwitchListTile(
          title: const Text('钳制高光'),
          subtitle: const Text('避免高光溢出，建议开启'),
          value: upscalerChoiceValue(engine, 'clamp') != '0',
          onChanged: (enabled) =>
              setUpscalerChoice(engine, 'clamp', enabled ? '1' : '0'),
        ),
      );
    }
    for (final spec
        in upscalerParamSpecs[engine] ?? const <UpscalerParamSpec>[]) {
      final value = upscalerParamValue(engine, spec);
      if (spec.isDefine && spec.max - spec.min <= 1) {
        children.add(
          SwitchListTile(
            title: Text(spec.label),
            subtitle: Text(spec.key),
            value: value > 0.5,
            onChanged: (enabled) =>
                setUpscalerParam(engine, spec.key, enabled ? 1 : 0),
          ),
        );
        continue;
      }
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(child: Text(spec.label)),
              Text(
                spec.format(value),
                style: TextStyle(color: Get.theme.colorScheme.primary),
              ),
            ],
          ),
        ),
      );
      children.add(
        Slider(
          min: spec.min,
          max: spec.max,
          divisions: spec.divisions,
          value: value.clamp(spec.min, spec.max).toDouble(),
          label: spec.format(value),
          onChanged: (v) => setUpscalerParam(engine, spec.key, v, apply: false),
          onChangeEnd: (v) => setUpscalerParam(engine, spec.key, v),
        ),
      );
    }
    children.add(
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: TextButton.icon(
          onPressed: () => resetUpscalerOptions(engine),
          icon: const Icon(Icons.restart_alt),
          label: const Text('恢复默认参数'),
        ),
      ),
    );
    return ListView(
      padding: AppStyle.edgeInsetsV12,
      children: children,
    );
  }
}

mixin PlayerDanmakuMixin on PlayerStateMixin {
  // 弹幕控制器
  DanmakuController? danmakuController;

  // 弹幕输入框控制器
  FocusNode danmakuTextFieldFocusNode = FocusNode();
  TextEditingController textEditingController = TextEditingController();

  RxDouble danmakuStrokeWidth = 1.0.obs;
  RxInt danmakuFontWeight = FontWeight.bold.index.obs;
  RxBool strokeText = true.obs;

  RxBool textFormatStatus = true.obs;
  RxString danmakuText = ''.obs;
  RxString danmakuColor = '#ffffff'.obs;
  RxInt danmakuTypeIndex = 1.obs;

  void initDanmakuController(DanmakuController e) {
    danmakuController = e;
    danmakuController?.updateOption(
      DanmakuOption(
          fontSize: DanmakuSettingsStorage.danmakuSize.value,
          area: DanmakuSettingsStorage.danmakuArea.value,
          duration: DanmakuSettingsStorage.danmakuSpeed.value,
          opacity: DanmakuSettingsStorage.danmakuOpacity.value,
          strokeWidth: danmakuStrokeWidth.value,
          fontWeight: FontWeight.values[danmakuFontWeight.value],
          strokeText: strokeText.value),
    );
  }

  void updateDanmuOption(DanmakuOption? option) {
    if (danmakuController == null || option == null) return;
    danmakuController!.updateOption(option);
  }

  void disposeDanmakuController() {
    danmakuController?.clear();
  }

  void addDanmaku(List<DanmakuItem> items) {
    if (!showDanmakuState.value) {
      return;
    }
    danmakuController?.addItems(items);
  }

  // 切换弹幕显示并记忆到设置
  void toggleDanmaku() {
    showDanmakuState.value = !showDanmakuState.value;
    DanmakuSettingsStorage.setDanmakuEnable(showDanmakuState.value);
  }
}

mixin PlayerSystemMixin on PlayerMixin, PlayerStateMixin, PlayerDanmakuMixin {
  final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  final screenBrightness = ScreenBrightness();

  final pip = Floating();
  StreamSubscription<PiPStatus>? _pipSubscription;

  // 初始化一些系统状态
  void initSystem() async {
    if (Platform.isAndroid || Platform.isIOS) {
      PerfectVolumeControl.hideUI = true;
    }

    // 屏幕常亮
    WakelockPlus.enable();

    // 开始隐藏计时
    resetHideControlsTimer();
  }

  // 释放一些系统状态
  Future resetSystem() async {
    _pipSubscription?.cancel();
    // pip.dispose();
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );

    await setPortraitOrientation();
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      // 亮度重置,桌面平台可能会报错,暂时不处理桌面平台的亮度
      try {
        await screenBrightness.resetScreenBrightness();
      } catch (e) {
        Log.logPrint(e);
      }
    }

    await WakelockPlus.disable();
  }

  // 进入全屏
  Future<void> enterFullScreen() async {
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
    );
    await landScape();
  }

  //横屏
  Future<void> landScape() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        await AutoOrientation.landscapeAutoMode(forceSensor: true);
      } else if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
        // 用 window_manager 全屏，窗口句柄不变，键盘焦点仍在 Flutter 视图上。
        // media_kit 的原生全屏会改变窗口样式，导致按键事件收不到。
        if (!await windowManager.isFullScreen()) {
          await windowManager.setFullScreen(true);
        }
      }
    } catch (exception, stacktrace) {
      debugPrint(exception.toString());
      debugPrint(stacktrace.toString());
    }
    fullScreenState.value = true;
    danmakuController?.clear();
    _restoreKeyboardFocus();
  }

  // 全屏切换后恢复窗口与 Flutter 焦点，保证快捷键继续生效
  void _restoreKeyboardFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!(Platform.isAndroid || Platform.isIOS)) {
        try {
          await windowManager.focus();
        } catch (e) {
          debugPrint(e.toString());
        }
      }
      if (playerFocusNode.canRequestFocus) {
        playerFocusNode.requestFocus();
      }
    });
  }

  //竖屏
  Future<void> verticalScreen() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }

  // 退出全屏
  Future<void> exitFull() async {
    late SystemUiMode mode = SystemUiMode.edgeToEdge;
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        if (Platform.isAndroid &&
            (await DeviceInfoPlugin().androidInfo).version.sdkInt < 29) {
          mode = SystemUiMode.manual;
        }
        await SystemChrome.setEnabledSystemUIMode(
          mode,
          overlays: SystemUiOverlay.values,
        );
        await SystemChrome.setPreferredOrientations([]);
      } else if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
        if (await windowManager.isFullScreen()) {
          await windowManager.setFullScreen(false);
        }
      }
    } catch (exception, stacktrace) {
      debugPrint(exception.toString());
      debugPrint(stacktrace.toString());
    }
    fullScreenState.value = false;
    danmakuController?.clear();
    _restoreKeyboardFocus();
  }

  Size? _lastWindowSize;
  Offset? _lastWindowPosition;

  //小窗模式()
  void enterSmallWindow() async {
    if (!(Platform.isAndroid || Platform.isIOS)) {
      fullScreenState.value = true;
      smallWindowState.value = true;

      // 读取窗口大小
      _lastWindowSize = await windowManager.getSize();
      _lastWindowPosition = await windowManager.getPosition();

      windowManager.setTitleBarStyle(TitleBarStyle.hidden);
      // 获取视频窗口大小
      var width = player.state.width ?? 16;
      var height = player.state.height ?? 9;

      // 横屏还是竖屏
      if (height > width) {
        var aspectRatio = width / height;
        windowManager.setSize(Size(400, 400 / aspectRatio));
      } else {
        var aspectRatio = height / width;
        windowManager.setSize(Size(280 / aspectRatio, 280));
      }

      windowManager.setAlwaysOnTop(true);
    }
  }

  //退出小窗模式()
  void exitSmallWindow() {
    if (!(Platform.isAndroid || Platform.isIOS)) {
      fullScreenState.value = false;
      smallWindowState.value = false;
      // windowManager.setTitleBarStyle(TitleBarStyle.normal);
      windowManager.setSize(_lastWindowSize!);
      windowManager.setPosition(_lastWindowPosition!);
      windowManager.setAlwaysOnTop(false);
      //windowManager.setAlignment(Alignment.center);
    }
  }

  // 设置横屏
  Future setLandscapeOrientation() async {
    if (await beforeIOS16()) {
      AutoOrientation.landscapeAutoMode();
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  // 设置竖屏
  Future setPortraitOrientation() async {
    if (await beforeIOS16()) {
      AutoOrientation.portraitAutoMode();
    } else {
      await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
  }

  // 是否是IOS16以下
  Future<bool> beforeIOS16() async {
    if (Platform.isIOS) {
      var info = await deviceInfo.iosInfo;
      var version = info.systemVersion;
      var versionInt = int.tryParse(version.split('.').first) ?? 0;
      return versionInt < 16;
    } else {
      return false;
    }
  }

  Future saveScreenshot() async {
    try {
      SmartDialog.showLoading(msg: '正在保存截图');
      //检查相册权限,仅iOS需要
      var permission = await Utils.checkPhotoPermission();
      if (!permission) {
        SmartDialog.showToast('没有相册权限');
        SmartDialog.dismiss(status: SmartStatus.loading);
        return;
      }

      var imageData = await player.screenshot();
      if (imageData == null) {
        SmartDialog.showToast('截图失败,数据为空');
        SmartDialog.dismiss(status: SmartStatus.loading);
        return;
      }

      if (Platform.isIOS || Platform.isAndroid) {
        await ImageGallerySaver.saveImage(
          imageData,
        );
        SmartDialog.showToast('已保存截图至相册');
      } else {
        //选择保存文件夹
        var path = await FilePicker.platform.saveFile(
          allowedExtensions: ['jpg'],
          type: FileType.image,
          fileName: '${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        if (path == null) {
          SmartDialog.showToast('取消保存');
          SmartDialog.dismiss(status: SmartStatus.loading);
          return;
        }
        var file = File(path);
        await file.writeAsBytes(imageData);
        SmartDialog.showToast('已保存截图至${file.path}');
      }
    } catch (e) {
      Log.logPrint(e);
      SmartDialog.showToast('截图失败');
    } finally {
      SmartDialog.dismiss(status: SmartStatus.loading);
    }
  }

  // 开启小窗播放前弹幕状态
  bool danmakuStateBeforePIP = false;

  Future enablePIP() async {
    if (!Platform.isAndroid) {
      return;
    }
    if (await pip.isPipAvailable == false) {
      SmartDialog.showToast('设备不支持小窗播放');
      return;
    }
    danmakuStateBeforePIP = showDanmakuState.value;
    //关闭并清除弹幕
    // if (AppSettingsController.instance.pipHideDanmu.value &&
    //     danmakuStateBeforePIP) {
    //   showDanmakuState.value = false;
    // }
    danmakuController?.clear();
    //关闭控制器
    showControlsState(false);

    await pip.enable(const ImmediatePiP(aspectRatio: Rational.landscape()));

    _pipSubscription ??= pip.pipStatusStream.listen((event) {
      if (event == PiPStatus.disabled) {
        danmakuController?.clear();
        showDanmakuState.value = danmakuStateBeforePIP;
      }
    });
  }
}

mixin PlayerGestureControlMixin
    on PlayerStateMixin, PlayerMixin, PlayerSystemMixin {
  // 单击显示/隐藏控制器
  void onTap() {
    if (showControlsState.value) {
      hideControls();
    } else {
      showControls();
    }
  }

  //桌面端操控
  void onEnter(PointerEnterEvent event) {
    if (!showControlsState.value) {
      showControls();
    }
  }

  void onExit(PointerExitEvent event) {
    if (showControlsState.value) {
      hideControls();
    }
  }

  void onHover(PointerHoverEvent event, BuildContext context) {
    if (Platform.isAndroid || Platform.isIOS) {
      return;
    }
    // final screenHeight = MediaQuery.of(context).size.height;
    // final targetPosition = screenHeight * 0.25; // 计算屏幕顶部25%的位置
    // if (event.position.dy <= targetPosition ||
    //     event.position.dy >= targetPosition * 3) {
    //   if (!showControlsState.value) {
    //     showControls();
    //   }
    // }
    if (!showControlsState.value) {
      showControls();
    }
  }

  // 双击全屏/退出全屏
  void onDoubleTap(TapDownDetails details) {
    if (lockControlsState.value || smallWindowState.value) {
      return;
    }
    if (fullScreenState.value) {
      exitFull();
    } else {
      enterFullScreen();
    }
  }

  bool verticalDragging = false;
  bool leftVerticalDrag = false;
  var _currentVolume = 0.0;
  var _currentBrightness = 1.0;
  var verStartPosition = 0.0;

  DelayedThrottle? throttle;

  // 竖向手势开始
  void onVerticalDragStart(DragStartDetails details) async {
    if (lockControlsState.value && fullScreenState.value) {
      return;
    }

    final dy = details.globalPosition.dy;
    // 开始位置必须是中间2/4的位置
    if (dy < Get.height * 0.25 || dy > Get.height * 0.75) {
      return;
    }

    verStartPosition = dy;
    leftVerticalDrag = details.globalPosition.dx < Get.width / 2;

    throttle = DelayedThrottle(200);

    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }
    verticalDragging = true;
    showGestureTip.value = true;
    if (Platform.isAndroid || Platform.isIOS) {
      _currentVolume = await PerfectVolumeControl.volume;
    }
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      _currentBrightness = await screenBrightness.current;
    }
  }

  // 竖向手势更新
  void onVerticalDragUpdate(DragUpdateDetails e) async {
    if (lockControlsState.value && fullScreenState.value) {
      return;
    }
    if (verticalDragging == false) return;
    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }
    //String text = '';
    //double value = 0.0;

    Log.logPrint('$verStartPosition/${e.globalPosition.dy}');

    if (leftVerticalDrag) {
      setGestureBrightness(e.globalPosition.dy);
    } else {
      setGestureVolume(e.globalPosition.dy);
    }
  }

  int lastVolume = -1; // it's ok to be -1

  void setGestureVolume(double dy) {
    double value = 0.0;
    double seek;
    if (dy > verStartPosition) {
      value = ((dy - verStartPosition) / (Get.height * 0.5));

      seek = _currentVolume - value;
      if (seek < 0) {
        seek = 0;
      }
    } else {
      value = ((dy - verStartPosition) / (Get.height * 0.5));
      seek = value.abs() + _currentVolume;
      if (seek > 1) {
        seek = 1;
      }
    }
    int volume = _convertVolume((seek * 100).round());
    if (volume == lastVolume) {
      return;
    }
    lastVolume = volume;
    // update UI outside throttle to make it more fluent
    gestureTipText.value = '音量 $volume%';
    throttle?.invoke(() async => await _realSetVolume(volume));
  }

  // 0 to 100, 5 step each
  int _convertVolume(int volume) {
    return (volume / 5).round() * 5;
  }

  Future<void> _realSetVolume(int volume) async {
    Log.logPrint(volume);
    return await PerfectVolumeControl.setVolume(volume / 100);
  }

  void setGestureBrightness(double dy) {
    double value = 0.0;
    if (dy > verStartPosition) {
      value = ((dy - verStartPosition) / (Get.height * 0.5));

      var seek = _currentBrightness - value;
      if (seek < 0) {
        seek = 0;
      }
      screenBrightness.setScreenBrightness(seek);

      gestureTipText.value = '亮度 ${(seek * 100).toInt()}%';
      Log.logPrint(value);
    } else {
      value = ((dy - verStartPosition) / (Get.height * 0.5));
      var seek = value.abs() + _currentBrightness;
      if (seek > 1) {
        seek = 1;
      }

      screenBrightness.setScreenBrightness(seek);
      gestureTipText.value = '亮度 ${(seek * 100).toInt()}%';
      Log.logPrint(value);
    }
  }

  // 竖向手势完成
  void onVerticalDragEnd(DragEndDetails details) async {
    if (lockControlsState.value && fullScreenState.value) {
      return;
    }
    throttle = null;
    verticalDragging = false;
    leftVerticalDrag = false;
    showGestureTip.value = false;
  }

  bool horizontalDragging = false;
  bool horizontalDrag = false;
  var horizontalStartPosition = 0.0;
  Duration _currentDuration = Duration.zero;
  double _currentPosition = 0.0;

  // 横向手势开始
  void onHorizontalDragStart(DragStartDetails details) async {
    if (lockControlsState.value && fullScreenState.value) {
      return;
    }

    final dx = details.globalPosition.dx;
    // if (dx < Get.width || dx > Get.width) {
    //   return;
    // }

    horizontalStartPosition = dx;
    horizontalDrag = details.globalPosition.dx < Get.width / 2;

    throttle = DelayedThrottle(200);

    horizontalDragging = true;
    showGestureTip.value = true;
    _currentDuration = player.state.duration;
    // print(
    //     'Horizontal drag start at: ${details.globalPosition} $_currentDuration');
  }

  // 横向手势更新
  void onHorizontalDragUpdate(DragUpdateDetails e) async {
    if (lockControlsState.value && fullScreenState.value) {
      return;
    }
    if (horizontalDragging == false) return;
    //String text = '';
    double value = 0.0;
    value =
        ((e.globalPosition.dx - horizontalStartPosition) / (Get.width * 0.5));
    _currentPosition = max(
        0,
        min(
            player.state.position.inSeconds +
                _currentDuration.inSeconds * (value * 0.5),
            _currentDuration.inSeconds.toDouble()));
    // Log.logPrint('$horizontalStartPosition/${e.globalPosition.dx}');
    // Log.logPrint('$_currentPosition/$value');
    gestureTipText.value =
        '${Duration(seconds: _currentPosition.toInt()).toString().split('.').first}/${_currentDuration.toString().split('.').first}';
  }

  // 横向手势完成
  void onHorizontalDragEnd(DragEndDetails details) async {
    if (lockControlsState.value && fullScreenState.value) {
      return;
    }
    throttle = null;
    horizontalDragging = false;
    horizontalDrag = false;
    showGestureTip.value = false;
    seekTo();
  }

  void seekTo() {
    player.seek(Duration(seconds: _currentPosition.toInt()));
  }
}

class PlayerController extends GetxController
    with
        PlayerMixin,
        PlayerStateMixin,
        PlayerDanmakuMixin,
        PlayerSystemMixin,
        PlayerGestureControlMixin,
        WindowListener {
  // A-B 循环
  RxInt abStart = (-1).obs;
  RxInt abEnd = (-1).obs;
  bool _abSeeking = false;

  // 观看时长统计
  Duration? _lastWatchPosition;
  int _watchMsBuffer = 0;
  StreamSubscription<Duration>? _positionSubscription;

  // 自动全屏只在本页首次进入时触发
  bool _autoFullscreenApplied = false;

  @override
  void onInit() {
    initSystem();
    initStream();
    // 恢复上次的播放偏好
    playerSpeed(PlayerSettingsStorage.speed);
    playerVolume(PlayerSettingsStorage.volume);
    showDanmakuState.value = DanmakuSettingsStorage.danmakuEnable.value;
    updateScaleMode(PlayerSettingsStorage.scaleMode);
    // 播放器快捷键
    HardwareKeyboard.instance.addHandler(_handleShortcut);
    // 监听窗口全屏变化：ESC 等外部方式退出全屏时同步播放器状态
    if (!(Platform.isAndroid || Platform.isIOS)) {
      windowManager.addListener(this);
    }
    super.onInit();
  }

  /// 外部（如 ESC 快捷键）退出全屏时，把播放器界面同步回窗口模式。
  @override
  void onWindowLeaveFullScreen() {
    if (fullScreenState.value && !smallWindowState.value) {
      exitFull();
    }
  }

  /// 进入播放页后按设置自动全屏（仅首次）。
  Future<void> maybeEnterAutoFullscreen() async {
    if (_autoFullscreenApplied ||
        !autoFullscreen.value ||
        fullScreenState.value) {
      return;
    }
    _autoFullscreenApplied = true;
    await Future.delayed(const Duration(milliseconds: 300));
    if (!_closed) {
      await enterFullScreen();
    }
  }

  // A-B 循环
  void setABStart() {
    final position = player.state.position.inSeconds;
    abStart(position);
    if (abEnd.value > 0 && abEnd.value <= position) {
      abEnd(-1);
    }
    _showPlayerTip('A 点：${formatPlaybackTime(Duration(seconds: position))}');
  }

  void setABEnd() {
    final position = player.state.position.inSeconds;
    if (abStart.value < 0 || position <= abStart.value) {
      _showPlayerTip('请先设置 A 点，并在 A 点之后设置 B 点');
      return;
    }
    abEnd(position);
    _showPlayerTip('B 点：${formatPlaybackTime(Duration(seconds: position))}');
  }

  void clearABLoop() {
    abStart(-1);
    abEnd(-1);
    _showPlayerTip('已取消 A-B 循环');
  }

  /// 播放器日志面板：查看、复制、清空最近的播放日志。
  void showPlayerLogs() {
    Utils.showBottomSheet(
      title: '播放器日志',
      scrollControlDisabledMaxHeightRatio: 0.8,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(
                    ClipboardData(text: Log.recentLogs.join('\n')),
                  );
                  SmartDialog.showToast('已复制日志');
                },
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('复制'),
              ),
              TextButton.icon(
                onPressed: Log.clearRecentLogs,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('清空'),
              ),
            ],
          ),
          Expanded(
            child: Obx(() {
              if (Log.recentLogs.isEmpty) {
                return const Center(child: Text('暂无日志'));
              }
              return ListView.builder(
                padding: AppStyle.edgeInsetsV12,
                itemCount: Log.recentLogs.length,
                itemBuilder: (_, index) {
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                    child: SelectableText(
                      Log.recentLogs[index],
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  /// 播放器快捷键：空格暂停/继续，左右方向键快进/快退，上下方向键调音量。
  bool _handleShortcut(KeyEvent event) {
    if (event is KeyUpEvent) {
      return false;
    }
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return false;
    }
    // 输入框获得焦点时不抢按键（弹幕输入框、搜索框等）
    final focus = FocusManager.instance.primaryFocus;
    if (focus?.context?.widget is EditableText ||
        focus?.context?.findAncestorWidgetOfExactType<EditableText>() != null) {
      return false;
    }
    final key = event.logicalKey;
    final ctrlPressed = HardwareKeyboard.instance.logicalKeysPressed.any(
      (pressed) =>
          pressed == LogicalKeyboardKey.controlLeft ||
          pressed == LogicalKeyboardKey.controlRight,
    );
    if (key == LogicalKeyboardKey.space) {
      if (event is KeyRepeatEvent) {
        return false;
      }
      if (player.state.playing) {
        player.pause();
      } else {
        player.play();
      }
      showControls();
      return true;
    }
    // Ctrl + 左右方向键：上一集 / 下一集
    if (ctrlPressed &&
        (key == LogicalKeyboardKey.arrowLeft ||
            key == LogicalKeyboardKey.arrowRight)) {
      if (key == LogicalKeyboardKey.arrowLeft) {
        playPreviousEpisode();
      } else {
        playNextEpisode();
      }
      return true;
    }
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight) {
      _seekRelative(key == LogicalKeyboardKey.arrowLeft ? -5 : 5);
      return true;
    }
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown) {
      final step = key == LogicalKeyboardKey.arrowUp ? 10.0 : -10.0;
      setVolume(playerVolume.value + step);
      // 长按时不重复写磁盘
      if (event is KeyDownEvent) {
        persistVolume();
      }
      _showShortcutTip('音量 ${playerVolume.value.toInt()}%');
      return true;
    }
    // F：全屏切换
    if (key == LogicalKeyboardKey.keyF) {
      if (smallWindowState.value) {
        exitSmallWindow();
      } else if (fullScreenState.value) {
        exitFull();
      } else {
        enterFullScreen();
      }
      return true;
    }
    // M：静音切换
    if (key == LogicalKeyboardKey.keyM) {
      if (playerVolume.value > 0) {
        _volumeBeforeMute = playerVolume.value;
        setVolume(0);
      } else {
        setVolume(_volumeBeforeMute > 0 ? _volumeBeforeMute : 100);
      }
      persistVolume();
      _showShortcutTip(playerVolume.value == 0 ? '已静音' : '音量已恢复');
      return true;
    }
    // [ / ]：倍速调节
    if (key == LogicalKeyboardKey.bracketLeft ||
        key == LogicalKeyboardKey.bracketRight) {
      _stepPlaybackSpeed(key == LogicalKeyboardKey.bracketLeft ? -1 : 1);
      return true;
    }
    // P：桌面端迷你播放器
    if (key == LogicalKeyboardKey.keyP &&
        !(Platform.isAndroid || Platform.isIOS)) {
      if (smallWindowState.value) {
        exitSmallWindow();
      } else {
        enterSmallWindow();
      }
      return true;
    }
    return false;
  }

  // 按倍速列表步进，[ / ] 快捷键使用
  void _stepPlaybackSpeed(int direction) {
    final current = speedsList.indexOf(playerSpeed.value);
    final index = current < 0 ? speedsList.indexOf(1.0) : current;
    final next = (index + direction).clamp(0, speedsList.length - 1);
    setPlaybackSpeed(speedsList[next]);
    _showShortcutTip('${speedsList[next]}X 倍速');
  }

  // 剧集切换：由播放页子类覆盖，普通 PlayerController 没有剧集概念
  void playPreviousEpisode() {}

  void playNextEpisode() {}

  void _seekRelative(int seconds) {
    final duration = player.state.duration;
    var target = player.state.position + Duration(seconds: seconds);
    if (target < Duration.zero) {
      target = Duration.zero;
    }
    if (duration > Duration.zero && target > duration) {
      target = duration;
    }
    player.seek(target);
    _showShortcutTip(
        '${_formatDuration(target)} / ${_formatDuration(duration)}');
  }

  String _formatDuration(Duration duration) {
    return formatPlaybackTime(duration);
  }

  void _showShortcutTip(String text) {
    gestureTipText.value = text;
    showGestureTip.value = true;
    hideSeekTipTimer?.cancel();
    hideSeekTipTimer = Timer(const Duration(milliseconds: 900), () {
      showGestureTip.value = false;
    });
  }

  StreamSubscription<String>? _errorSubscription;
  StreamSubscription? _completedSubscription;
  StreamSubscription? _widthSubscription;
  StreamSubscription? _heightSubscription;
  StreamSubscription? _logSubscription;

  void initStream() {
    _errorSubscription = player.stream.error.listen((event) {
      Log.d('播放器错误：$event');
      // 跳过无音频输出的错误
      // Could not open/initialize audio device -> no sound.
      if (event.contains('no sound.')) {
        return;
      }
      //SmartDialog.showToast(event);
      mediaError(event);
    });

    _completedSubscription = player.stream.completed.listen((event) {
      if (event) {
        mediaEnd();
      }
    });
    _logSubscription = player.stream.log.listen((event) {
      Log.d('播放器日志：$event');
    });
    _positionSubscription = player.stream.position.listen(_onPositionTrack);
    _widthSubscription = player.stream.width.listen((event) {
      Log.d(
          'width:$event  W:${(player.state.width)}  H:${(player.state.height)}');
      isVertical.value =
          (player.state.height ?? 9) > (player.state.width ?? 16);
    });
    _heightSubscription = player.stream.height.listen((event) {
      Log.d(
          'height:$event  W:${(player.state.width)}  H:${(player.state.height)}');
      isVertical.value =
          (player.state.height ?? 9) > (player.state.width ?? 16);
    });
  }

  void disposeStream() {
    _errorSubscription?.cancel();
    _completedSubscription?.cancel();
    _widthSubscription?.cancel();
    _heightSubscription?.cancel();
    _logSubscription?.cancel();
    _positionSubscription?.cancel();
    _pipSubscription?.cancel();
  }

  /// 统一处理进度回调：A-B 循环与观看时长统计。
  void _onPositionTrack(Duration position) {
    if (abStart.value >= 0 &&
        abEnd.value > abStart.value &&
        position.inSeconds >= abEnd.value &&
        !_abSeeking) {
      _abSeeking = true;
      player.seek(Duration(seconds: abStart.value)).whenComplete(() {
        _abSeeking = false;
      });
    }

    final last = _lastWatchPosition;
    _lastWatchPosition = position;
    if (!player.state.playing || last == null) {
      return;
    }
    final delta = position.inMilliseconds - last.inMilliseconds;
    // 只累计正常播放增量，跳转造成的跳变不计入
    if (delta > 0 && delta <= 2000) {
      _watchMsBuffer += delta;
      if (_watchMsBuffer >= 1000) {
        WatchStatsStorage.addMilliseconds(_watchMsBuffer);
        _watchMsBuffer = 0;
      }
    }
  }

  void mediaEnd() {}

  void mediaError(String error) {}

  void showDebugInfo() {
    Utils.showBottomSheet(
      title: '播放信息',
      child: ListView(
        children: [
          ListTile(
            title: const Text('Resolution'),
            subtitle: Text('${player.state.width}x${player.state.height}'),
            onTap: () {
              Clipboard.setData(
                ClipboardData(
                  text:
                      'Resolution\n${player.state.width}x${player.state.height}',
                ),
              );
            },
          ),
          ListTile(
            title: const Text('VideoParams'),
            subtitle: Text(player.state.videoParams.toString()),
            onTap: () {
              Clipboard.setData(
                ClipboardData(
                  text: 'VideoParams\n${player.state.videoParams}',
                ),
              );
            },
          ),
          ListTile(
            title: const Text('AudioParams'),
            subtitle: Text(player.state.audioParams.toString()),
            onTap: () {
              Clipboard.setData(
                ClipboardData(
                  text: 'AudioParams\n${player.state.audioParams}',
                ),
              );
            },
          ),
          ListTile(
            title: const Text('Media'),
            subtitle: Text(player.state.playlist.toString()),
            onTap: () {
              Clipboard.setData(
                ClipboardData(
                  text: 'Media\n${player.state.playlist}',
                ),
              );
            },
          ),
          ListTile(
            title: const Text('AudioTrack'),
            subtitle: Text(player.state.track.audio.toString()),
            onTap: () {
              Clipboard.setData(
                ClipboardData(
                  text: 'AudioTrack\n${player.state.track.audio}',
                ),
              );
            },
          ),
          ListTile(
            title: const Text('VideoTrack'),
            subtitle: Text(player.state.track.video.toString()),
            onTap: () {
              Clipboard.setData(
                ClipboardData(
                  text: 'VideoTrack\n${player.state.track.audio}',
                ),
              );
            },
          ),
          ListTile(
            title: const Text('AudioBitrate'),
            subtitle: Text(player.state.audioBitrate.toString()),
            onTap: () {
              Clipboard.setData(
                ClipboardData(
                  text: 'AudioBitrate\n${player.state.audioBitrate}',
                ),
              );
            },
          ),
          ListTile(
            title: const Text('Volume'),
            subtitle: Text(player.state.volume.toString()),
            onTap: () {
              Clipboard.setData(
                ClipboardData(
                  text: 'Volume\n${player.state.volume}',
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // GetBuilder 的 init 控制器不在 GetX 生命周期内，页面销毁时需要主动调用一次，
  // 用标记保证重复调用安全。
  bool _closed = false;

  @override
  void onClose() async {
    if (_closed) {
      return;
    }
    _closed = true;
    Log.w('播放器关闭');
    HardwareKeyboard.instance.removeHandler(_handleShortcut);
    cancelSleepTimer();
    hideSeekTipTimer?.cancel();
    hideControlsTimer?.cancel();
    if (_watchMsBuffer > 0) {
      WatchStatsStorage.addMilliseconds(_watchMsBuffer);
      _watchMsBuffer = 0;
    }
    WatchStatsStorage.flush();
    if (!(Platform.isAndroid || Platform.isIOS)) {
      windowManager.removeListener(this);
    }
    if (smallWindowState.value) {
      exitSmallWindow();
    }
    textEditingController.dispose();
    danmakuTextFieldFocusNode.dispose();
    playerFocusNode.dispose();
    disposeStream();
    disposeDanmakuController();
    await resetSystem();
    await player.dispose();
    super.onClose();
  }
}
