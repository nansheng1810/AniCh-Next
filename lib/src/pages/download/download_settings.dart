import 'package:get_storage/get_storage.dart';

/// 离线缓存偏好：并发数、缓存目录与完成通知。
class DownloadSettingsStorage {
  static GetStorage box = GetStorage();

  static const int _defaultConcurrent = 3;

  static int get maxConcurrent {
    final value = (box.read('downloadMaxConcurrent') as num?)?.toInt() ??
        _defaultConcurrent;
    return value.clamp(1, 6);
  }

  static void setMaxConcurrent(int value) {
    box.write('downloadMaxConcurrent', value.clamp(1, 6));
  }

  /// 自定义缓存目录，空字符串表示使用应用数据目录。
  static String get directory => box.read('downloadDirectory') as String? ?? '';

  static void setDirectory(String value) {
    box.write('downloadDirectory', value);
  }

  static bool get notifyOnComplete =>
      box.read('downloadNotifyOnComplete') as bool? ?? true;

  static void setNotifyOnComplete(bool value) {
    box.write('downloadNotifyOnComplete', value);
  }
}
