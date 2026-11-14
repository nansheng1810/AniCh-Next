import 'package:flutter/material.dart';

/// 桌面布局断点：窗口宽度大于该值时使用左侧导航栏 + 宽屏内容区。
const double desktopBreakpoint = 900;

/// 宽屏断点：用于展开导航栏文字、启用左右分栏等更宽松的布局。
const double wideBreakpoint = 1180;

/// 详情类页面在桌面上居中的最大内容宽度。
const double pageMaxWidth = 1080;

/// 表单/设置类页面在桌面上居中的最大内容宽度。
const double formMaxWidth = 760;

/// 当前窗口是否应使用桌面布局。
bool isDesktopLayout(BuildContext context) =>
    MediaQuery.of(context).size.width >= desktopBreakpoint;

/// 当前窗口是否为宽屏桌面。
bool isWideLayout(BuildContext context) =>
    MediaQuery.of(context).size.width >= wideBreakpoint;

/// 在桌面上把内容限制在 [maxWidth] 内并水平居中，窄窗口保持原样。
class DesktopCentered extends StatelessWidget {
  const DesktopCentered({
    super.key,
    required this.child,
    this.maxWidth = formMaxWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    if (!isDesktopLayout(context)) return child;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
