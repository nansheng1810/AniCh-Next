import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:xs/src/pages/bangumi/controller.dart';
import 'package:xs/src/pages/bangumi/views/filter_rail.dart';
import 'package:xs/src/pages/bangumi/views/latest.dart';
import 'package:xs/src/pages/bangumi/views/library.dart';
import 'package:xs/src/pages/search/models/search_type.dart';
import 'package:xs/src/utils/desktop.dart';
import 'package:xs/src/widgets/desktop_shell.dart';
import 'package:xs/src/widgets/drag_to_move_bar.dart';
import 'package:xs/src/widgets/search_bar.dart';

class BangumiPage extends StatelessWidget {
  const BangumiPage({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<BangumiController>(
        init: BangumiController(),
        builder: (controller) {
          final desktop = isDesktopLayout(context);
          final scaffold = Scaffold(
            extendBody: true,
            body: SafeArea(
              top: true,
              bottom: false,
              child: Column(
                children: [
                  _Header(controller: controller),
                  Expanded(
                    child: Obx(
                      () => IndexedStack(
                        index: controller.mode.value,
                        children: [
                          _LibraryBody(desktop: desktop),
                          const BangumiLatestView(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
          if (desktop) {
            return DesktopShell(index: 1, child: scaffold);
          }
          return scaffold;
        });
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.controller});

  final BangumiController controller;

  @override
  Widget build(BuildContext context) {
    return CustomDragToMoveArea(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            constraints: const BoxConstraints(minHeight: 50),
            child: Row(
              children: [
                Text(
                  '番剧库',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 12),
                const CustomSearchBar(
                  placeholder: '搜索番剧',
                  searchType: SearchType.bangumi,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            child: Obx(
              () => Row(
                children: [
                  _ModeTab(
                    label: '番剧库',
                    selected: controller.mode.value == 0,
                    onTap: () => controller.mode(0),
                  ),
                  const SizedBox(width: 8),
                  _ModeTab(
                    label: '最近更新',
                    selected: controller.mode.value == 1,
                    onTap: () => controller.mode(1),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? colorScheme.primary.withAlpha(28)
          : colorScheme.onSurface.withAlpha(10),
      borderRadius: BorderRadius.circular(50),
      child: InkWell(
        borderRadius: BorderRadius.circular(50),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              color: selected
                  ? colorScheme.primary
                  : colorScheme.onSurface.withAlpha(190),
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

/// 桌面端：左侧固定筛选栏 + 右侧结果网格。
class _LibraryBody extends StatelessWidget {
  const _LibraryBody({required this.desktop});

  final bool desktop;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<BangumiLibraryController>(
      init: BangumiLibraryController(),
      builder: (controller) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (desktop) ...[
              SizedBox(
                width: 232,
                child: Material(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: BangumiFilterRail(controller: controller),
                ),
              ),
              const VerticalDivider(width: 1, thickness: 1),
            ],
            Expanded(
              child: BangumiLibraryView(
                controller: controller,
                desktop: desktop,
              ),
            ),
          ],
        );
      },
    );
  }
}
