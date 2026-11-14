import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:xs/src/pages/bangumi_detail/controller.dart';
import 'package:xs/src/pages/bangumi_detail/models/bangumi_detail_model.dart';
import 'package:xs/src/widgets/expandable_text.dart';
import 'package:xs/src/widgets/keepalive.dart';

class BangumiDetailIndexView extends StatelessWidget {
  const BangumiDetailIndexView({
    super.key,
    required this.controller,
    this.active = false,
    this.data,
  });

  final BangumiDetailController controller;
  final bool active;
  final BangumiDetailModel? data;

  @override
  Widget build(BuildContext context) {
    Brightness currentBrightness = MediaQuery.of(context).platformBrightness;
    // 设置状态栏图标的亮度
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarIconBrightness: currentBrightness == Brightness.light
          ? Brightness.dark
          : Brightness.light,
    ));
    final data = this.data;
    if (data == null) {
      return const SizedBox.shrink();
    }
    final genres = data.genres ?? const <String?>[];
    final marks = data.marks ?? const <BangumiDetailModelMarks?>[];
    return SafeArea(
      top: false,
      bottom: false,
      maintainBottomViewPadding: true,
      child: Builder(builder: (context) {
        final scrollController = controller.tabScrollController(context, active);
        return KeepAliveWrapper(
          child: RefreshIndicator(
            displacement: 60,
            edgeOffset: 80,
            onRefresh: () async {
              await controller.reload();
            },
            child: CustomScrollView(
              key: const PageStorageKey('bangumi-detail-index'),
              controller: scrollController,
              shrinkWrap: true,
              slivers: [
                SliverOverlapInjector(
                    handle:
                        NestedScrollView.sliverOverlapAbsorberHandleFor(context)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionTitle('简介'),
                        const SizedBox(height: 6),
                        ExpandableText(
                          (data.overview ?? '').trim().isEmpty
                              ? '暂无简介'
                              : data.overview!,
                          maxLines: 3,
                          style: const TextStyle(fontSize: 13, height: 1.55),
                        ),
                        if (genres.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          const _SectionTitle('分类'),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final genre in genres)
                                if (genre != null && genre.isNotEmpty)
                                  _TagChip(
                                    label: genre,
                                    onTap: () {
                                      Get.offNamedUntil('/bangumi',
                                          (page) =>
                                              page.settings.name == '/',
                                          arguments: {'genre': genre});
                                    },
                                  ),
                            ],
                          ),
                        ],
                        if (marks.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          const _SectionTitle('标签'),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final mark in marks)
                                if (mark?.name != null &&
                                    mark!.name!.isNotEmpty)
                                  _TagChip(
                                    label: mark.name!,
                                    count: mark.count,
                                    onTap: () {
                                      Get.offNamedUntil('/bangumi',
                                          (page) =>
                                              page.settings.name == '/',
                                          arguments: {'mark': mark.name});
                                    },
                                  ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// 分类 / 标签使用的紧凑胶囊按钮。
class _TagChip extends StatelessWidget {
  const _TagChip({required this.label, this.count, required this.onTap});

  final String label;
  final int? count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.onSurface.withAlpha(18),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              if (count != null && count! > 0) ...[
                const SizedBox(width: 5),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
