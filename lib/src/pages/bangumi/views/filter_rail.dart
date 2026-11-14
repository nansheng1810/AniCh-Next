import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:xs/src/pages/bangumi/controller.dart';

/// 番剧库筛选栏：类型 / 语言 / 年份 / 分类 / 标签。
///
/// 桌面端固定在左侧，手机端放进底部弹层，两者复用同一份实现。
/// 分类与标签默认只显示前 [collapsedCount] 个，避免整栏被标签铺满。
class BangumiFilterRail extends StatefulWidget {
  const BangumiFilterRail({
    super.key,
    required this.controller,
    this.showDone = false,
  });

  final BangumiLibraryController controller;

  /// 手机端弹层里显示「完成」按钮，桌面端不需要。
  final bool showDone;

  @override
  State<BangumiFilterRail> createState() => _BangumiFilterRailState();
}

class _BangumiFilterRailState extends State<BangumiFilterRail> {
  static const int collapsedCount = 9;

  /// 已展开的分组（'genre' / 'mark'）。
  final Set<String> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Obx(() {
      final colorScheme = Theme.of(context).colorScheme;
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '筛选',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                if (controller.hasFilter)
                  TextButton(
                    onPressed: () {
                      setState(_expanded.clear);
                      controller.reset();
                    },
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 30),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('重置', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _section(
              context,
              '类型',
              _chips(
                context,
                entries: BangumiLibraryController.typeList.entries
                    .map((e) => MapEntry(e.key, e.value))
                    .toList(),
                selected: controller.type.value,
                onTap: controller.selectType,
              ),
            ),
            _section(
              context,
              '语言与年份',
              Row(
                children: [
                  Expanded(
                    child: _dropdown<String>(
                      context,
                      value: controller.lang.value,
                      items: BangumiLibraryController.langList.entries
                          .map((e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(
                                    e.key.isEmpty ? '全部语言' : e.value),
                              ))
                          .toList(),
                      onChanged: (value) => controller.selectLang(value ?? ''),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _dropdown<String>(
                      context,
                      value: controller.year.value,
                      items: controller.yearList
                          .map((e) => DropdownMenuItem(
                                value: e,
                                child: Text(e.isEmpty ? '全部年份' : '$e 年'),
                              ))
                          .toList(),
                      onChanged: (value) => controller.selectYear(value ?? ''),
                    ),
                  ),
                ],
              ),
            ),
            _tagSection(
              context,
              'genre',
              '分类',
              entries: controller.genres
                  .map((e) => MapEntry(e.name ?? '', e.name ?? ''))
                  .toList(),
              selected: controller.genre.value,
              onTap: controller.selectGenre,
              done: controller.genresDone.value,
              onLoadMore: () => controller.moreTags('genre'),
            ),
            _tagSection(
              context,
              'mark',
              '标签',
              entries: controller.marks
                  .map((e) => MapEntry(e.name ?? '', e.name ?? ''))
                  .toList(),
              selected: controller.mark.value,
              onTap: controller.selectMark,
              done: controller.marksDone.value,
              onLoadMore: () => controller.moreTags('mark'),
            ),
            if (widget.showDone) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('完成'),
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  Widget _section(BuildContext context, String title, Widget child,
      {Widget? action}) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              if (action != null) action,
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  /// 分类 / 标签：折叠展示，标题右侧提供展开 / 收起。
  Widget _tagSection(
    BuildContext context,
    String key,
    String title, {
    required List<MapEntry<String, String>> entries,
    required String selected,
    required void Function(String) onTap,
    required bool done,
    required VoidCallback onLoadMore,
  }) {
    if (entries.isEmpty) {
      return _section(
        context,
        title,
        Row(
          children: [
            if (!done) ...[
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.6),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              done ? '暂无' : '加载中…',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    final bool expanded = _expanded.contains(key);
    final List<MapEntry<String, String>> visible =
        expanded ? entries : entries.take(collapsedCount).toList();
    final bool canExpand = entries.length > collapsedCount;
    final bool showToggle = canExpand || !done;
    return _section(
      context,
      title,
      _chips(
        context,
        entries: visible,
        selected: selected,
        onTap: onTap,
      ),
      action: showToggle
          ? TextButton(
              onPressed: () {
                setState(() {
                  if (expanded) {
                    _expanded.remove(key);
                  } else {
                    _expanded.add(key);
                  }
                });
                if (!expanded && !done) onLoadMore();
              },
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 24),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                expanded ? '收起' : '展开',
                style: const TextStyle(fontSize: 11),
              ),
            )
          : null,
    );
  }

  Widget _chips(
    BuildContext context, {
    required List<MapEntry<String, String>> entries,
    required String selected,
    required void Function(String) onTap,
  }) {
    final List<Widget> chips = [];
    // 已选但不在候选列表里时补一个，避免看起来没有选中项
    if (selected.isNotEmpty && !entries.any((e) => e.key == selected)) {
      chips.add(_TagChip(
        label: selected,
        selected: true,
        onTap: () => onTap(selected),
      ));
    }
    for (final entry in entries) {
      chips.add(_TagChip(
        label: entry.value,
        selected: entry.key.isEmpty ? selected.isEmpty : selected == entry.key,
        onTap: () => onTap(entry.key),
      ));
    }
    return Wrap(spacing: 6, runSpacing: 6, children: chips);
  }

  Widget _dropdown<T>(
    BuildContext context, {
    required T value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withAlpha(10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          isDense: true,
          borderRadius: BorderRadius.circular(8),
          menuMaxHeight: 340,
          icon: Icon(Icons.expand_more,
              size: 18, color: colorScheme.onSurfaceVariant),
          style: TextStyle(fontSize: 12, color: colorScheme.onSurface),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
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
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? colorScheme.primary.withAlpha(90)
                  : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: selected
                  ? colorScheme.primary
                  : colorScheme.onSurface.withAlpha(200),
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
