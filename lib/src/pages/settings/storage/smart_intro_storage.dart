import 'package:get_storage/get_storage.dart';

/// 智能片头学习：记录用户主动快进的落点，重复出现时认定为片头结束点。
class SmartIntroStorage {
  static GetStorage box = GetStorage();

  static const int _maxCandidates = 6;

  static String _key(int bangumiId) => 'smartIntro_$bangumiId';

  static Map<String, dynamic> _read(int bangumiId) {
    final value = box.read(_key(bangumiId));
    if (value is! Map) {
      return {'candidates': <int>[], 'learned': 0};
    }
    return Map<String, dynamic>.from(value);
  }

  static int learned(int bangumiId) {
    final value = _read(bangumiId);
    return (value['learned'] as num?)?.toInt() ?? 0;
  }

  static List<int> candidates(int bangumiId) {
    final value = _read(bangumiId);
    final raw = value['candidates'];
    if (raw is! List) {
      return [];
    }
    return raw
        .whereType<num>()
        .map((e) => e.toInt())
        .where((e) => e > 0)
        .toList();
  }

  /// 记录一次快进落点；连续两次落点接近时返回学习到的片头结束点。
  static int? addCandidate(int bangumiId, int seconds) {
    if (seconds < 10 || seconds > 300) {
      return null;
    }
    final values = candidates(bangumiId)..add(seconds);
    while (values.length > _maxCandidates) {
      values.removeAt(0);
    }
    final data = _read(bangumiId);
    data['candidates'] = values;

    int? learnedValue;
    if (values.length >= 2) {
      final previous = values[values.length - 2];
      final current = values[values.length - 1];
      if ((previous - current).abs() <= 8) {
        learnedValue = ((previous + current) / 2).round();
        data['learned'] = learnedValue;
      }
    }
    box.write(_key(bangumiId), data);
    return learnedValue;
  }

  static void clear(int bangumiId) {
    box.remove(_key(bangumiId));
  }
}
