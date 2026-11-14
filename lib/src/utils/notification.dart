import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:local_notifier/local_notifier.dart';

/// 系统通知：桌面端走原生通知，其余平台或初始化失败时回退到应用内提示。
class NotificationService {
  static bool _ready = false;

  static Future<void> init() async {
    if (!(Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      return;
    }
    try {
      await localNotifier.setup(appName: 'AniCh Next');
      _ready = true;
    } catch (e) {
      debugPrint('系统通知初始化失败: $e');
    }
  }

  static Future<void> show(String title, String body) async {
    if (_ready) {
      try {
        final notification = LocalNotification(title: title, body: body);
        await notification.show();
        return;
      } catch (e) {
        debugPrint('系统通知发送失败: $e');
      }
    }
    try {
      SmartDialog.showToast('$title：$body');
    } catch (_) {
      // 应用尚未启动完成时忽略
    }
  }
}
