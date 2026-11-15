import 'package:get_storage/get_storage.dart';

/// 追番自动化的设置与本地快照。
class FollowStorage {
  static GetStorage box = GetStorage();

  // 自动检查新集
  static bool get enabled {
    return box.read('followAutoCheck') as bool? ?? false;
  }

  static void setEnabled(bool value) {
    box.write('followAutoCheck', value);
  }

  // 检查间隔（分钟）
  static const List<int> intervalOptions = [30, 60, 180, 360, 720];

  static int get intervalMinutes {
    final value = (box.read('followInterval') as num?)?.toInt() ?? 60;
    return intervalOptions.contains(value) ? value : 60;
  }

  static void setIntervalMinutes(int value) {
    box.write('followInterval', value);
  }

  // 新集系统通知
  static bool get notify {
    return box.read('followNotify') as bool? ?? true;
  }

  static void setNotify(bool value) {
    box.write('followNotify', value);
  }

  // 自动缓存新集
  static bool get autoCache {
    return box.read('followAutoCache') as bool? ?? false;
  }

  static void setAutoCache(bool value) {
    box.write('followAutoCache', value);
  }

  // 上次检查时间（毫秒时间戳）
  static int get lastCheck {
    return (box.read('followLastCheck') as num?)?.toInt() ?? 0;
  }

  static void setLastCheck(int value) {
    box.write('followLastCheck', value);
  }

  // 追番快照列表
  static List<Map<String, dynamic>> get snapshots {
    final raw = box.read('followSnapshots');
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  static void saveSnapshots(List<Map<String, dynamic>> value) {
    box.write('followSnapshots', value);
  }
}
