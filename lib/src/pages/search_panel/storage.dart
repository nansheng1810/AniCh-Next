import 'package:get_storage/get_storage.dart';

/// 搜索历史：保存在 GetStorage，同一关键词去重置顶，最多保留 20 条。
class SearchHistoryStorage {
  static GetStorage box = GetStorage();
  static const String _key = 'searchHistory';
  static const int maxCount = 20;

  static List<String> list() {
    final value = box.read(_key);
    if (value is! List) {
      return [];
    }
    return value.whereType<String>().toList();
  }

  static void add(String keyword) {
    final word = keyword.trim();
    if (word.isEmpty) {
      return;
    }
    final data = list()..removeWhere((e) => e == word);
    data.insert(0, word);
    if (data.length > maxCount) {
      data.removeRange(maxCount, data.length);
    }
    box.write(_key, data);
  }

  static void clear() {
    box.remove(_key);
  }
}
