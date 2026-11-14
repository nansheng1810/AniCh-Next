import 'dart:io';
import 'dart:ui';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:logger/logger.dart';
import 'package:media_kit/media_kit.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:window_manager/window_manager.dart';
import 'package:xs/src/apis/account.dart';
import 'package:xs/src/config.dart';
import 'package:xs/src/pages/download/download_manager.dart';
import 'package:xs/src/pages/search/models/search_type.dart';
import 'package:xs/src/pages/settings/storage/play_history_storage.dart';
import 'package:xs/src/pages/settings/storage/theme_storage.dart';
import 'package:xs/src/widgets/danmaku_settings/storage.dart';
import 'package:xs/src/widgets/danmaku_shield/storage.dart';
import 'package:xs/src/router.dart';
import 'package:xs/src/utils/desktop_lifecycle.dart';
import 'package:xs/src/utils/listen_fourth_button.dart';
import 'package:xs/src/utils/log.dart';
import 'package:xs/src/utils/notification.dart';
import 'package:xs/src/utils/app_route_observer.dart';
import 'package:xs/src/utils/utils.dart';
import 'package:xs/src/widgets/app_loadding_widget.dart';
import 'package:xs/src/widgets/window_title_bar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Release 下把渲染错误替换为可读提示，避免整块灰色 ErrorWidget 且无信息
  if (kReleaseMode) {
    ErrorWidget.builder = (details) {
      hadRenderError = true;
      Log.logPrint('渲染错误: ${details.exceptionAsString()}');
      return Container(
        color: const Color(0xFF1E1E1E),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: const Text(
          '页面渲染出错，请返回重试',
          style: TextStyle(color: Colors.white70, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      );
    };
  }
  // 全局快捷键不依赖焦点，桌面端窗口失焦回来后依然可用
  HardwareKeyboard.instance.addHandler(handleShortcut);
  MediaKit.ensureInitialized();
  await GetStorage.init();
  await GetStorage.init('playHistory');
  await initWindow();
  // 桌面端常驻托盘：关闭窗口后继续后台运行
  await DesktopLifecycle.instance.init();
  Utils.packageInfo = await PackageInfo.fromPlatform();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // 状态栏透明
  SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(statusBarColor: Colors.transparent));
  // 图片缓存：移动端内存更紧张，上限低于桌面端
  PaintingBinding.instance.imageCache.maximumSize = 1000000;
  PaintingBinding.instance.imageCache.maximumSizeBytes =
      (Platform.isAndroid || Platform.isIOS ? 100 : 200) << 20;
  // 配置初始化
  AppConfig.init();
  // 主题初始化
  ThemeSettingsStorage.init();
  // 历史记录初始化
  PlayHistoryStorage.init();
  // 弹幕设置初始化
  DanmakuSettingsStorage.init();
  // 初始化弹幕屏蔽词
  DanmakuShieldStorage.init();
  // 桌面端系统通知
  await NotificationService.init();
  // 初始化离线缓存
  await Get.put(DownloadManager()).init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    // 检测更新：桌面版由源码构建，GitHub 上的发布包是移动端安装包，
    // 自动检查只会弹出无法关闭的强制更新弹窗，因此仅在移动端检查。
    if (Platform.isAndroid || Platform.isIOS) {
      Utils.checkUpdate();
    }
    // 获取用户信息
    final box = GetStorage();
    final token = box.read('token');
    if (token != null) {
      AccountApi.init();
    }
    bool isDynamicColor = ThemeSettingsStorage.isDynamic.value;
    Color styleColor = Color(ThemeSettingsStorage.styleColor.value);
    // const defaultDarkColorScheme = ColorScheme.dark();
    return DynamicColorBuilder(
        builder: (lightDynamicColorScheme, darkDynamicColorScheme) {
      ColorScheme? lightColorScheme;
      ColorScheme? darkColorScheme;
      if (lightDynamicColorScheme != null &&
          darkDynamicColorScheme != null &&
          isDynamicColor) {
        lightColorScheme = lightDynamicColorScheme;
        darkColorScheme = darkDynamicColorScheme;
      } else {
        lightColorScheme = ColorScheme.fromSeed(
          seedColor: styleColor,
          brightness: Brightness.light,
        );
        darkColorScheme = ColorScheme.fromSeed(
            seedColor: styleColor, brightness: Brightness.dark);
      }
      return GetMaterialApp(
          debugShowCheckedModeBanner: false,
          themeMode: ThemeMode.values[ThemeSettingsStorage.themeMode.value
              .clamp(0, ThemeMode.values.length - 1)],
          theme: ThemeData(
              fontFamily: 'Ubuntu',
              brightness: Brightness.light,
              colorScheme: lightColorScheme,
              // splashColor: Colors.white,
              scaffoldBackgroundColor: Colors.white,
              useMaterial3: true),
          darkTheme: ThemeData(
              fontFamily: 'Ubuntu',
              brightness: Brightness.dark,
              colorScheme: darkColorScheme,
              // splashColor: Colors.black,
              scaffoldBackgroundColor: Colors.black,
              useMaterial3: true),
          // 未登录时直接把登录页作为首屏，配合 AuthMiddleware 形成强制登录
          initialRoute: token == null ? '/login' : '/',
          getPages: AppRoute.pages,
          defaultTransition: Transition.noTransition,
          scrollBehavior: AppScrollBehavior(),
          logWriterCallback: (text, {bool? isError}) {
            Log.addDebugLog(
                text, (isError ?? false) ? Colors.red : Colors.grey);
            Log.writeLog(text, (isError ?? false) ? Level.error : Level.info);
          },
          navigatorObservers: [FlutterSmartDialog.observer, appRouteObserver],
          builder: FlutterSmartDialog.init(
            loadingBuilder: ((msg) => const AppLoaddingWidget()),
            //字体大小不跟随系统变化
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.0)),
              child: Column(
                children: [
                  if (DesktopLifecycle.isDesktop) const AppWindowTitleBar(),
                  Expanded(
                    child: Stack(
                      children: [
                        //侧键返回
                        RawGestureDetector(
                          excludeFromSemantics: true,
                          gestures: <Type, GestureRecognizerFactory>{
                            FourthButtonTapGestureRecognizer:
                                GestureRecognizerFactoryWithHandlers<
                                    FourthButtonTapGestureRecognizer>(
                              () => FourthButtonTapGestureRecognizer(),
                              (FourthButtonTapGestureRecognizer instance) {
                                instance.onTapDown =
                                    (TapDownDetails details) async {
                                  //如果处于全屏状态，退出全屏
                                  if (!Platform.isAndroid && !Platform.isIOS) {
                                    if (await windowManager.isFullScreen()) {
                                      await windowManager.setFullScreen(false);
                                      return;
                                    }
                                  }
                                  Get.back();
                                };
                              },
                            ),
                          },
                          // 全局快捷键由 HardwareKeyboard 处理器接管，不需要额外焦点节点
                          child: child!,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ));
    });
  }
}

// 鼠标滑动
class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
      };
}

/// 全局快捷键：Ctrl+F 打开搜索，Esc 退出全屏或返回上一页。
bool handleShortcut(KeyEvent event) {
  if (event is! KeyDownEvent) {
    return false;
  }
  final keys = HardwareKeyboard.instance.logicalKeysPressed;
  final ctrl = keys.contains(LogicalKeyboardKey.controlLeft) ||
      keys.contains(LogicalKeyboardKey.controlRight);
  if (ctrl && event.logicalKey == LogicalKeyboardKey.keyF) {
    openSearchPanel();
    return true;
  }
  if (event.logicalKey == LogicalKeyboardKey.escape) {
    handleEscape();
    return true;
  }
  return false;
}

/// 桌面端 Ctrl+F：按当前所在页面打开对应类型的搜索面板。
void openSearchPanel() {
  final route = Get.currentRoute;
  if (route == '/search_panel' || route == '/search') return;
  if (AppRoute.publicRoutes.contains(route)) return;
  final type = route.startsWith('/bangumi') || route.startsWith('/vod')
      ? SearchType.bangumi
      : SearchType.picture;
  Get.toNamed('/search_panel', arguments: {'type': type});
}

/// ESC：全屏时先退出全屏，否则返回上一页。
Future<void> handleEscape() async {
  if (!Platform.isAndroid && !Platform.isIOS) {
    if (await windowManager.isFullScreen()) {
      await windowManager.setFullScreen(false);
      return;
    }
  }
  if (Get.currentRoute != '/') {
    Get.back();
  }
}

Future initWindow() async {
  if (!(Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
    return;
  }
  await windowManager.ensureInitialized();
  WindowOptions windowOptions = const WindowOptions(
      size: Size(1280, 820),
      minimumSize: Size(1000, 640),
      center: true,
      title: 'AniCh',
      titleBarStyle: TitleBarStyle.hidden,
      skipTaskbar: false,
      windowButtonVisibility: false);
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}
