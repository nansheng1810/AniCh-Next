import 'package:get_storage/get_storage.dart';

/// 本地观看统计：累计时长、本周时长、已看完集数。
class WatchStatsStorage {
  static GetStorage box = GetStorage();

  static const String _totalKey = 'watchStatsTotalSeconds';
  static const String _weekKey = 'watchStatsWeekSeconds';
  static const String _weekStartKey = 'watchStatsWeekStart';
  static const String _completedKey = 'watchStatsCompletedEpisodes';

  /// 毫秒缓冲，避免播放器高频回调频繁写盘。
  static int _bufferMs = 0;

  static String get _currentWeekStart {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return '${monday.year}-${monday.month.toString().padLeft(2, '0')}-'
        '${monday.day.toString().padLeft(2, '0')}';
  }

  static int get totalSeconds {
    return (box.read(_totalKey) as num?)?.toInt() ?? 0;
  }

  static int get weekSeconds {
    if (box.read(_weekStartKey) != _currentWeekStart) {
      return 0;
    }
    return (box.read(_weekKey) as num?)?.toInt() ?? 0;
  }

  static int get completedCount {
    final value = box.read(_completedKey);
    if (value is List) {
      return value.length;
    }
    return 0;
  }

  /// 播放器按毫秒累计，内部缓冲后统一落盘。
  static void addMilliseconds(int milliseconds) {
    if (milliseconds <= 0) {
      return;
    }
    _bufferMs += milliseconds;
    if (_bufferMs >= 5000) {
      flush();
    }
  }

  static void flush() {
    final seconds = _bufferMs ~/ 1000;
    if (seconds <= 0) {
      return;
    }
    _bufferMs -= seconds * 1000;
    final weekStart = _currentWeekStart;
    if (box.read(_weekStartKey) != weekStart) {
      box.write(_weekStartKey, weekStart);
      box.write(_weekKey, seconds);
    } else {
      box.write(_weekKey, weekSeconds + seconds);
    }
    box.write(_totalKey, totalSeconds + seconds);
  }

  /// 记录一集已播完（同一集只计一次）。
  static void addCompleted(int bangumiId, int episode) {
    final key = '$bangumiId-$episode';
    final value = box.read(_completedKey);
    final list = value is List ? List<String>.from(value) : <String>[];
    if (list.contains(key)) {
      return;
    }
    list.add(key);
    box.write(_completedKey, list);
  }

  /// 清空统计（不影响观看记录）。
  static void reset() {
    _bufferMs = 0;
    box.remove(_totalKey);
    box.remove(_weekKey);
    box.remove(_weekStartKey);
    box.remove(_completedKey);
  }
}
