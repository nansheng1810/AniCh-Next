import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/painting.dart';
import 'package:get_storage/get_storage.dart';
import 'package:path_provider/path_provider.dart';

/// 应用缓存目录管理。
class CacheUtil {
  static Future<int> size() async {
    try {
      final directory = await getApplicationCacheDirectory();
      if (!await directory.exists()) {
        return 0;
      }
      var total = 0;
      await for (final entity in directory.list(recursive: true)) {
        if (entity is File) {
          try {
            total += await entity.length();
          } catch (_) {
            // 忽略正在被占用的文件
          }
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> clear() async {
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    try {
      final directory = await getApplicationCacheDirectory();
      if (!await directory.exists()) {
        return;
      }
      await for (final entity in directory.list()) {
        try {
          await entity.delete(recursive: true);
        } catch (_) {
          // 被播放器占用的文件跳过
        }
      }
    } catch (_) {
      // 缓存目录不可用时忽略
    }
  }
}

/// 设置与历史记录的导出/导入（不包含登录 token）。
class BackupService {
  static const String appTag = 'AniCh-Next';
  static const Set<String> _excludedKeys = {'token'};

  static Future<String?> export() async {
    final box = GetStorage();
    final data = <String, dynamic>{};
    for (final rawKey in box.getKeys()) {
      final key = rawKey.toString();
      if (_excludedKeys.contains(key)) {
        continue;
      }
      final value = box.read(key);
      if (value != null) {
        data[key] = value;
      }
    }
    final now = DateTime.now();
    final stamp = '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    final content = const JsonEncoder.withIndent('  ').convert({
      'app': appTag,
      'exportedAt': now.toIso8601String(),
      'data': data,
    });
    final path = await FilePicker.platform.saveFile(
      dialogTitle: '导出设置与历史',
      fileName: 'AniCh-Backup-$stamp.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (path == null || path.isEmpty) {
      return null;
    }
    final target = path.toLowerCase().endsWith('.json') ? path : '$path.json';
    await File(target).writeAsString(content);
    return target;
  }

  /// 返回导入的设置项数量；用户取消时返回 null。
  static Future<int?> import() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: '选择备份文件',
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }
    final file = result.files.single;
    final content = file.bytes != null
        ? utf8.decode(file.bytes!)
        : await File(file.path!).readAsString();
    final decoded = jsonDecode(content);
    if (decoded is! Map) {
      throw const FormatException('备份文件格式不正确');
    }
    final root = Map<String, dynamic>.from(decoded);
    if (root['app'] != appTag || root['data'] is! Map) {
      throw const FormatException('不是 AniCh 备份文件');
    }
    final data = Map<String, dynamic>.from(root['data'] as Map);
    final box = GetStorage();
    var count = 0;
    for (final entry in data.entries) {
      if (_excludedKeys.contains(entry.key)) {
        continue;
      }
      if (entry.value == null) {
        box.remove(entry.key);
      } else {
        box.write(entry.key, entry.value);
      }
      count++;
    }
    return count;
  }
}
