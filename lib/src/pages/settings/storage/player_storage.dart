import 'package:get_storage/get_storage.dart';

/// 播放器偏好：倍速、音量、画面尺寸、超分辨率。
class PlayerSettingsStorage {
  static GetStorage box = GetStorage();

  // 播放倍速
  static double get speed {
    final value = (box.read('playerSpeed') as num?)?.toDouble() ?? 1.0;
    return value >= 0.25 && value <= 2.0 ? value : 1.0;
  }

  static void setSpeed(double value) {
    box.write('playerSpeed', value);
  }

  // 音量（0-100）
  static double get volume {
    final value = (box.read('playerVolume') as num?)?.toDouble() ?? 100.0;
    return value.clamp(0.0, 100.0);
  }

  static void setVolume(double value) {
    box.write('playerVolume', value.clamp(0.0, 100.0));
  }

  // 画面尺寸：0 适应、1 拉伸、2 铺满、3 16:9、4 4:3
  static int get scaleMode {
    final value = (box.read('playerScaleMode') as num?)?.toInt() ?? 0;
    return value >= 0 && value <= 4 ? value : 0;
  }

  static void setScaleMode(int value) {
    box.write('playerScaleMode', value);
  }

  // 超分辨率（mpv 高质量缩放）
  static bool get superResolution {
    return box.read('playerSuperResolution') as bool? ?? false;
  }

  static void setSuperResolution(bool value) {
    box.write('playerSuperResolution', value);
  }

  // 4K 渲染（固定 3840x2160 视频输出）
  static bool get render4K {
    return box.read('playerRender4K') as bool? ?? false;
  }

  static void setRender4K(bool value) {
    box.write('playerRender4K', value);
  }

  // 超分引擎 id（见 UpscalerEngine.id）
  static String get upscaler {
    return box.read('playerUpscaler') as String? ?? 'none';
  }

  static void setUpscaler(String value) {
    box.write('playerUpscaler', value);
  }

  // 超分引擎数值参数，键为 "引擎id:参数名"
  static Map<String, double> get upscalerNumeric {
    final raw = box.read('upscalerNumeric');
    if (raw is Map) {
      return raw.map(
        (key, value) => MapEntry(
          key.toString(),
          value is num ? value.toDouble() : 0,
        ),
      );
    }
    return {};
  }

  static void setUpscalerNumeric(String key, double value) {
    final map = upscalerNumeric;
    map[key] = value;
    box.write('upscalerNumeric', map);
  }

  // 超分引擎选项，键为 "引擎id:选项名"
  static Map<String, String> get upscalerChoices {
    final raw = box.read('upscalerChoices');
    if (raw is Map) {
      return raw.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    }
    return {};
  }

  static void setUpscalerChoice(String key, String value) {
    final map = upscalerChoices;
    map[key] = value;
    box.write('upscalerChoices', map);
  }

  static void resetUpscalerOptions(String prefix) {
    final numeric = upscalerNumeric
      ..removeWhere((key, value) => key.startsWith(prefix));
    final choices = upscalerChoices
      ..removeWhere((key, value) => key.startsWith(prefix));
    box.write('upscalerNumeric', numeric);
    box.write('upscalerChoices', choices);
  }

  // 进入播放页自动全屏
  static bool get autoFullscreen {
    return box.read('playerAutoFullscreen') as bool? ?? false;
  }

  static void setAutoFullscreen(bool value) {
    box.write('playerAutoFullscreen', value);
  }

  // 当前集播完自动播放下一集
  static bool get autoPlayNext {
    return box.read('playerAutoPlayNext') as bool? ?? true;
  }

  static void setAutoPlayNext(bool value) {
    box.write('playerAutoPlayNext', value);
  }

  // 长按画面临时倍速
  static bool get longPressSpeed {
    return box.read('playerLongPressSpeed') as bool? ?? false;
  }

  static void setLongPressSpeed(bool value) {
    box.write('playerLongPressSpeed', value);
  }

  static double get longPressSpeedValue {
    final value =
        (box.read('playerLongPressSpeedValue') as num?)?.toDouble() ?? 2.0;
    return value.clamp(1.5, 4.0);
  }

  static void setLongPressSpeedValue(double value) {
    box.write('playerLongPressSpeedValue', value.clamp(1.5, 4.0));
  }

  // 自动跳过片头 / 片尾
  static bool get skipIntro {
    return box.read('playerSkipIntro') as bool? ?? false;
  }

  static void setSkipIntro(bool value) {
    box.write('playerSkipIntro', value);
  }

  static bool get skipOutro {
    return box.read('playerSkipOutro') as bool? ?? false;
  }

  static void setSkipOutro(bool value) {
    box.write('playerSkipOutro', value);
  }

  // 智能学习片头：根据用户重复快进的落点自动确定片头结束位置
  static bool get smartSkipIntro {
    return box.read('playerSmartSkipIntro') as bool? ?? false;
  }

  static void setSmartSkipIntro(bool value) {
    box.write('playerSmartSkipIntro', value);
  }

  // 多线路自动测速并切换到最快线路
  static bool get autoFastestLine {
    return box.read('playerAutoFastestLine') as bool? ?? false;
  }

  static void setAutoFastestLine(bool value) {
    box.write('playerAutoFastestLine', value);
  }

  // 外挂字幕样式
  static double get subtitleFontSize {
    final value =
        (box.read('playerSubtitleFontSize') as num?)?.toDouble() ?? 32.0;
    return value.clamp(16.0, 64.0);
  }

  static void setSubtitleFontSize(double value) {
    box.write('playerSubtitleFontSize', value.clamp(16.0, 64.0));
  }

  static double get subtitleOutline {
    final value =
        (box.read('playerSubtitleOutline') as num?)?.toDouble() ?? 2.0;
    return value.clamp(0.0, 4.0);
  }

  static void setSubtitleOutline(double value) {
    box.write('playerSubtitleOutline', value.clamp(0.0, 4.0));
  }

  static double get subtitleBottomPadding {
    final value =
        (box.read('playerSubtitleBottomPadding') as num?)?.toDouble() ?? 24.0;
    return value.clamp(0.0, 160.0);
  }

  static void setSubtitleBottomPadding(double value) {
    box.write('playerSubtitleBottomPadding', value.clamp(0.0, 160.0));
  }

  static bool get subtitleBold {
    return box.read('playerSubtitleBold') as bool? ?? false;
  }

  static void setSubtitleBold(bool value) {
    box.write('playerSubtitleBold', value);
  }

  // 字幕延迟（秒），正数表示字幕延后显示
  static double get subtitleDelay {
    final value = (box.read('playerSubtitleDelay') as num?)?.toDouble() ?? 0.0;
    return value.clamp(-10.0, 10.0);
  }

  static void setSubtitleDelay(double value) {
    box.write('playerSubtitleDelay', value.clamp(-10.0, 10.0));
  }
}
