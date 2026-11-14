import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:xs/src/widgets/ns_danmaku/models/danmaku_item.dart';

/// 弹幕搜索结果。
class DanmakuSearchResult {
  const DanmakuSearchResult({
    required this.time,
    required this.text,
    required this.source,
  });

  final double time;
  final String text;
  final String source;

  Duration get position => Duration(milliseconds: (time * 1000).round());
}

/// 本地弹幕条目，时间单位为秒，颜色为十进制 RGB。
class LocalDanmakuItem {
  const LocalDanmakuItem({
    required this.time,
    required this.text,
    this.type = DanmakuItemType.scroll,
    this.color = 0xFFFFFF,
    this.size = 25,
  });

  final double time;
  final String text;
  final DanmakuItemType type;
  final int color;
  final double size;

  String get key => '${time.toStringAsFixed(1)}|${type.name}|$text';

  Map<String, dynamic> toJson() {
    return {
      'time': time,
      'text': text,
      'type': type.name,
      'color': color,
      'size': size,
    };
  }

  factory LocalDanmakuItem.fromJson(Map<String, dynamic> json) {
    return LocalDanmakuItem(
      time: (json['time'] as num?)?.toDouble() ?? 0,
      text: json['text'] as String? ?? '',
      type: DanmakuItemType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => DanmakuItemType.scroll,
      ),
      color: (json['color'] as num?)?.toInt() ?? 0xFFFFFF,
      size: (json['size'] as num?)?.toDouble() ?? 25,
    );
  }

  DanmakuItem toDanmakuItem() {
    return DanmakuItem(
      text,
      time: time,
      type: type,
      color: Color.fromARGB(
        255,
        (color >> 16) & 0xFF,
        (color >> 8) & 0xFF,
        color & 0xFF,
      ),
    );
  }
}

/// 按番剧 + 集数持久化本地弹幕。
class LocalDanmakuStorage {
  static GetStorage box = GetStorage();

  static String _key(int bangumiId, int episode) =>
      'localDanmaku_${bangumiId}_$episode';

  static bool get enabled => box.read('localDanmakuEnabled') as bool? ?? true;

  static void setEnabled(bool value) {
    box.write('localDanmakuEnabled', value);
  }

  static List<LocalDanmakuItem> load(int bangumiId, int episode) {
    final raw = box.read(_key(bangumiId, episode));
    if (raw is! List) {
      return [];
    }
    return raw
        .whereType<Map>()
        .map((e) => LocalDanmakuItem.fromJson(Map<String, dynamic>.from(e)))
        .where((e) => e.text.isNotEmpty)
        .toList()
      ..sort((a, b) => a.time.compareTo(b.time));
  }

  static void save(int bangumiId, int episode, List<LocalDanmakuItem> items) {
    box.write(
      _key(bangumiId, episode),
      items.map((e) => e.toJson()).toList(),
    );
  }

  /// 合并并去重，返回新增条数。
  static int merge(
      int bangumiId, int episode, Iterable<LocalDanmakuItem> items) {
    final merged = <String, LocalDanmakuItem>{
      for (final item in load(bangumiId, episode)) item.key: item,
    };
    var added = 0;
    for (final item in items) {
      if (item.text.isEmpty || merged.containsKey(item.key)) {
        continue;
      }
      merged[item.key] = item;
      added += 1;
    }
    final result = merged.values.toList()
      ..sort((a, b) => a.time.compareTo(b.time));
    save(bangumiId, episode, result);
    return added;
  }

  static int count(int bangumiId, int episode) =>
      load(bangumiId, episode).length;

  static void clear(int bangumiId, int episode) {
    box.remove(_key(bangumiId, episode));
  }
}

/// 弹幕文件解析与导出：支持 JSON（哔哩哔哩接口结构/通用数组）与 XML（哔哩哔哩 d 标签）。
class DanmakuFileCodec {
  static final RegExp _xmlPattern = RegExp(
    r'<d\s+p="([^"]*)"[^>]*>([\s\S]*?)</d>',
    caseSensitive: false,
  );

  static List<LocalDanmakuItem> decode(String content) {
    final text = content.replaceFirst('\uFEFF', '').trim();
    if (text.isEmpty) {
      return [];
    }
    if (text.startsWith('<')) {
      return _decodeXml(text);
    }
    return _decodeJson(text);
  }

  static List<LocalDanmakuItem> _decodeXml(String content) {
    final result = <LocalDanmakuItem>[];
    for (final match in _xmlPattern.allMatches(content)) {
      final params = (match.group(1) ?? '').split(',');
      if (params.length < 4) {
        continue;
      }
      final time = double.tryParse(params[0]) ?? 0;
      int mode;
      double size;
      int color;
      final second = int.tryParse(params[1]) ?? 1;
      if (second > 8) {
        // 兼容 ACFun 的 p="时间,颜色,模式,字号" 顺序
        color = _parseColor(second);
        mode = int.tryParse(params[2]) ?? 1;
        size = double.tryParse(params[3]) ?? 25;
      } else {
        // 哔哩哔哩：p="时间,模式,字号,颜色,..."
        mode = second;
        size = double.tryParse(params[2]) ?? 25;
        color = int.tryParse(params[3]) ?? 0xFFFFFF;
      }
      final text = _unescapeXml(match.group(2) ?? '').trim();
      if (text.isEmpty) {
        continue;
      }
      result.add(LocalDanmakuItem(
        time: time,
        text: text,
        type: _bilibiliType(mode),
        color: _parseColor(color),
        size: size.clamp(12, 48),
      ));
    }
    return result;
  }

  static List<LocalDanmakuItem> _decodeJson(String content) {
    dynamic data;
    try {
      data = jsonDecode(content);
    } catch (_) {
      return [];
    }
    List<dynamic> list = [];
    if (data is List) {
      list = data;
    } else if (data is Map) {
      for (final key in [
        'elems',
        'danmaku',
        'danmakus',
        'comments',
        'list',
        'data',
        'items',
      ]) {
        final value = data[key];
        if (value is List) {
          list = value;
          break;
        }
        // 兼容 { code: 0, data: { elems: [...] } } 结构
        if (value is Map) {
          final nested = value['elems'] ?? value['list'] ?? value['items'];
          if (nested is List) {
            list = nested;
            break;
          }
        }
      }
    }
    final result = <LocalDanmakuItem>[];
    for (final raw in list) {
      if (raw is! Map) {
        continue;
      }
      try {
        final item = _decodeJsonItem(Map<String, dynamic>.from(raw));
        if (item != null) {
          result.add(item);
        }
      } catch (_) {
        // 单条格式异常时跳过，不影响其他弹幕导入
      }
    }
    return result;
  }

  static LocalDanmakuItem? _decodeJsonItem(Map<String, dynamic> map) {
    var text = map['text'] ??
        map['content'] ??
        map['m'] ??
        map['message'] ??
        map['body'] ??
        '';
    if (text is! String || text.trim().isEmpty) {
      return null;
    }
    double time = 0;
    DanmakuItemType type = DanmakuItemType.scroll;
    double size = 25;
    int color = 0xFFFFFF;

    // ACFun：c="时间,颜色,模式,字号,..."，m 为内容
    final c = map['c'];
    if (c is String && c.contains(',')) {
      final parts = c.split(',');
      if (parts.length >= 4) {
        time = double.tryParse(parts[0]) ?? 0;
        color = _parseColor(parts[1]);
        type = _bilibiliType(int.tryParse(parts[2]) ?? 1);
        size = (double.tryParse(parts[3]) ?? 25).clamp(12, 48);
        return LocalDanmakuItem(
          time: time.clamp(0, 24 * 3600).toDouble(),
          text: text.trim(),
          type: type,
          color: color,
          size: size,
        );
      }
    }

    if (map.containsKey('time')) {
      time = _toDouble(map['time']);
      // 少数导出文件使用毫秒
      if (time > 100000) {
        time /= 1000;
      }
    } else if (map.containsKey('progress')) {
      // 哔哩哔哩接口：毫秒
      time = _toDouble(map['progress']) / 1000;
    } else if (map.containsKey('t') || map.containsKey('timestamp')) {
      time = _toDouble(map['t'] ?? map['timestamp']) / 1000;
    }

    if (map.containsKey('type')) {
      type = _parseType(map['type']);
    } else if (map.containsKey('mode')) {
      type = _bilibiliType(_toInt(map['mode'], 1));
    }
    color = _parseColor(map['color'] ?? map['colorDecimal']);
    size = _toDouble(map['size'] ?? map['fontsize'], 25).clamp(12, 48);

    return LocalDanmakuItem(
      time: time.clamp(0, 24 * 3600).toDouble(),
      text: text.trim(),
      type: type,
      color: color,
      size: size,
    );
  }

  static String encodeJson(List<LocalDanmakuItem> items) {
    return const JsonEncoder.withIndent('  ').convert(
      items.map((e) => e.toJson()).toList(),
    );
  }

  static String encodeXml(List<LocalDanmakuItem> items) {
    final buffer = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln('<i>');
    for (final item in items) {
      final mode = switch (item.type) {
        DanmakuItemType.scroll => 1,
        DanmakuItemType.bottom => 4,
        DanmakuItemType.top => 5,
      };
      final time = item.time.toStringAsFixed(2);
      buffer.writeln(
        '<d p="$time,$mode,${item.size.toInt()},${item.color},0,0,0,0">'
        '${_escapeXml(item.text)}</d>',
      );
    }
    buffer.writeln('</i>');
    return buffer.toString();
  }

  static DanmakuItemType _bilibiliType(int mode) {
    if (mode == 4) {
      return DanmakuItemType.bottom;
    }
    if (mode == 5) {
      return DanmakuItemType.top;
    }
    return DanmakuItemType.scroll;
  }

  static DanmakuItemType _parseType(dynamic value) {
    if (value is String) {
      final name = value.toLowerCase();
      if (name == 'top' || name == '5') {
        return DanmakuItemType.top;
      }
      if (name == 'bottom' || name == '4') {
        return DanmakuItemType.bottom;
      }
      final parsed = int.tryParse(name);
      if (parsed != null) {
        return _parseType(parsed);
      }
      return DanmakuItemType.scroll;
    }
    if (value is num) {
      // 兼容 xs 的 2=顶部、3=底部
      if (value.toInt() == 3) {
        return DanmakuItemType.bottom;
      }
      if (value.toInt() == 2) {
        return DanmakuItemType.top;
      }
    }
    return DanmakuItemType.scroll;
  }

  static int _parseColor(dynamic value) {
    if (value == null) {
      return 0xFFFFFF;
    }
    if (value is int) {
      return value & 0xFFFFFF;
    }
    if (value is num) {
      return value.toInt() & 0xFFFFFF;
    }
    if (value is String) {
      var text = value.trim();
      if (text.startsWith('#')) {
        text = text.substring(1);
      }
      if (text.length == 8) {
        text = text.substring(2);
      }
      return int.tryParse(text, radix: 16) ?? 0xFFFFFF;
    }
    return 0xFFFFFF;
  }

  static double _toDouble(dynamic value, [double fallback = 0]) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim()) ?? fallback;
    }
    return fallback;
  }

  static int _toInt(dynamic value, [int fallback = 0]) {
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim()) ?? fallback;
    }
    return fallback;
  }

  static String _unescapeXml(String text) {
    return text
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&#39;', "'")
        .replaceAllMapped(
          RegExp(r'&#x([0-9a-fA-F]+);'),
          (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)),
        )
        .replaceAllMapped(
          RegExp(r'&#(\d+);'),
          (m) => String.fromCharCode(int.parse(m.group(1)!)),
        )
        .replaceAll('&amp;', '&');
  }

  static String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
