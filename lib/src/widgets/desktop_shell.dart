import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:xs/src/utils/desktop.dart';
import 'package:xs/src/widgets/drag_to_move_bar.dart';

/// 桌面端应用外壳：左侧固定导航栏 + 右侧页面内容。
///
/// 三个顶级页面（首页 / 番剧 / 我的）在桌面宽度下通过该外壳承载，
/// 手机宽度下仍使用原本的底部悬浮导航。
class DesktopShell extends StatelessWidget {
  const DesktopShell({super.key, required this.index, required this.child});

  /// 当前选中的导航项：0 首页、1 番剧、2 我的。
  final int index;
  final Widget child;

  static const List<String> _routes = ['/', '/bangumi', '/profile'];

  void _onSelected(int i) {
    if (i == index) return;
    final name = _routes[i];
    if (name == '/') {
      Get.offNamed('/');
    } else {
      Get.offNamedUntil(name, (page) => page.settings.name == '/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final expanded = isWideLayout(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Row(
        children: [
          SizedBox(
            width: expanded ? 208 : 88,
            child: Column(
              children: [
                // 无边框窗口：侧栏顶部留出可拖动区域
                const CustomDragToMoveArea(
                  child: SizedBox(height: 36, width: double.infinity),
                ),
                Expanded(
                  child: NavigationRail(
                    selectedIndex: index,
                    extended: expanded,
                    minExtendedWidth: 208,
                    labelType: expanded
                        ? NavigationRailLabelType.none
                        : NavigationRailLabelType.all,
                    groupAlignment: -0.9,
                    onDestinationSelected: _onSelected,
                    leading: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: expanded
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.auto_awesome,
                                    color: colorScheme.primary),
                                const SizedBox(width: 8),
                                Text('AniCh',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                              ],
                            )
                          : Icon(Icons.auto_awesome,
                              color: colorScheme.primary),
                    ),
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.image_outlined),
                        selectedIcon: Icon(Icons.image),
                        label: Text('图片'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.movie_outlined),
                        selectedIcon: Icon(Icons.movie),
                        label: Text('番剧'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.person_outline),
                        selectedIcon: Icon(Icons.person),
                        label: Text('我的'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 1, thickness: 1),
          // 内容区宽度需要覆盖 MediaQuery.size，使瀑布流等按实际可用宽度计算列数
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    size: Size(constraints.maxWidth, constraints.maxHeight),
                  ),
                  child: child,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
