import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// 桌面端常驻托盘：关闭窗口时隐藏到托盘继续运行，托盘菜单可恢复或退出。
class DesktopLifecycle with WindowListener, TrayListener {
  DesktopLifecycle._();

  static final DesktopLifecycle instance = DesktopLifecycle._();

  static bool get isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  bool _trayReady = false;
  bool _quitting = false;

  Future<void> init() async {
    if (!isDesktop) {
      return;
    }
    windowManager.addListener(this);
    await windowManager.setPreventClose(true);
    try {
      await trayManager.setIcon('assets/images/tray_icon.ico');
      await trayManager.setToolTip('AniCh');
      await trayManager.setContextMenu(
        Menu(
          items: [
            MenuItem(key: 'show', label: '显示主界面'),
            MenuItem.separator(),
            MenuItem(key: 'exit', label: '退出'),
          ],
        ),
      );
      trayManager.addListener(this);
      _trayReady = true;
    } catch (e) {
      debugPrint('托盘初始化失败: $e');
      // 托盘不可用时恢复默认关闭行为，避免窗口无法关闭
      await windowManager.setPreventClose(false);
    }
  }

  Future<void> hideToTray() async {
    if (await windowManager.isFullScreen()) {
      await windowManager.setFullScreen(false);
    }
    await windowManager.hide();
  }

  Future<void> showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> quit() async {
    _quitting = true;
    if (_trayReady) {
      trayManager.removeListener(this);
      await trayManager.destroy();
    }
    windowManager.removeListener(this);
    await windowManager.destroy();
  }

  @override
  void onWindowClose() async {
    if (_quitting) {
      return;
    }
    if (_trayReady) {
      await hideToTray();
    } else {
      await windowManager.destroy();
    }
  }

  @override
  void onTrayIconMouseDown() {
    showWindow();
  }

  @override
  void onTrayIconRightMouseDown() {
    // Windows 下右键只会回调该方法，需要主动弹出菜单
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        showWindow();
        break;
      case 'exit':
        quit();
        break;
    }
  }
}
