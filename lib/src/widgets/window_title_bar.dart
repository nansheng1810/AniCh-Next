import 'package:flutter/material.dart';
import 'package:xs/src/utils/desktop_lifecycle.dart';
import 'package:window_manager/window_manager.dart';

/// 自绘窗口标题栏：拖动移动窗口，右侧提供最小化/最大化/关闭按钮。
class AppWindowTitleBar extends StatefulWidget {
  const AppWindowTitleBar({super.key});

  @override
  State<AppWindowTitleBar> createState() => _AppWindowTitleBarState();
}

class _AppWindowTitleBarState extends State<AppWindowTitleBar>
    with WindowListener {
  bool _maximized = false;
  bool _fullScreen = false;

  @override
  void initState() {
    super.initState();
    if (!DesktopLifecycle.isDesktop) {
      return;
    }
    windowManager.addListener(this);
    windowManager.isMaximized().then((value) {
      if (mounted) {
        setState(() => _maximized = value);
      }
    });
    windowManager.isFullScreen().then((value) {
      if (mounted) {
        setState(() => _fullScreen = value);
      }
    });
  }

  @override
  void dispose() {
    if (DesktopLifecycle.isDesktop) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  Future<void> _toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  @override
  void onWindowMaximize() {
    if (mounted) {
      setState(() => _maximized = true);
    }
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) {
      setState(() => _maximized = false);
    }
  }

  @override
  void onWindowEnterFullScreen() {
    if (mounted) {
      setState(() => _fullScreen = true);
    }
  }

  @override
  void onWindowLeaveFullScreen() {
    if (mounted) {
      setState(() => _fullScreen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 全屏播放时隐藏标题栏，避免占用视频区域
    if (_fullScreen) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Material(
      color: theme.scaffoldBackgroundColor,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => windowManager.startDragging(),
        onDoubleTap: _toggleMaximize,
        child: Container(
          height: 32,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: theme.dividerColor.withAlpha(30)),
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Image.asset('assets/images/icon.png', width: 16, height: 16),
              const SizedBox(width: 8),
              Text(
                'AniCh',
                style: TextStyle(fontSize: 12, color: theme.hintColor),
              ),
              const Spacer(),
              _TitleBarButton(
                icon: Icons.remove,
                onPressed: () => windowManager.minimize(),
              ),
              _TitleBarButton(
                icon: _maximized ? Icons.filter_none : Icons.crop_square,
                iconSize: 15,
                onPressed: _toggleMaximize,
              ),
              _TitleBarButton(
                icon: Icons.close,
                danger: true,
                onPressed: () => windowManager.close(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TitleBarButton extends StatefulWidget {
  const _TitleBarButton({
    required this.icon,
    required this.onPressed,
    this.iconSize = 16,
    this.danger = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final double iconSize;
  final bool danger;

  @override
  State<_TitleBarButton> createState() => _TitleBarButtonState();
}

class _TitleBarButtonState extends State<_TitleBarButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent =
        widget.danger ? const Color(0xFFE81123) : theme.colorScheme.primary;
    // 悬停用主色底 + 主色图标，深色/浅色主题下都有明显反馈
    final hoverBackground = widget.danger
        ? accent
        : (theme.brightness == Brightness.dark
            ? accent.withAlpha(72)
            : accent.withAlpha(48));
    final foreground = _hover && widget.danger
        ? Colors.white
        : (_hover ? accent : theme.colorScheme.onSurface);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: Container(
          width: 46,
          height: 32,
          alignment: Alignment.center,
          color: _hover ? hoverBackground : Colors.transparent,
          child: Icon(widget.icon, size: widget.iconSize, color: foreground),
        ),
      ),
    );
  }
}
