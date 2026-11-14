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
}
