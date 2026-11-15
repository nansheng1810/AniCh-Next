import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:xs/src/pages/follow/follow_service.dart';
import 'package:xs/src/pages/follow/follow_storage.dart';
import 'package:xs/src/pages/follow/models/followed_anime.dart';
import 'package:xs/src/utils/app_style.dart';
import 'package:xs/src/utils/desktop.dart';
import 'package:xs/src/utils/utils.dart';
import 'package:xs/src/widgets/drag_to_move_bar.dart';
import 'package:xs/src/widgets/settings/settings_card.dart';
import 'package:xs/src/widgets/settings/settings_switch.dart';

/// 追番自动化：设置定时检查，查看新集与追番列表。
class FollowPage extends StatelessWidget {
  const FollowPage({super.key});

  FollowService get service => FollowService.instance;

  String _intervalLabel(int minutes) {
    if (minutes < 60) {
      return '$minutes 分钟';
    }
    return '${minutes ~/ 60} 小时';
  }

  String _lastCheckText(int time) {
    if (time <= 0) {
      return '尚未检查';
    }
    final diff =
        DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(time));
    if (diff.inMinutes < 1) {
      return '刚刚检查';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} 分钟前检查';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} 小时前检查';
    }
    return '${diff.inDays} 天前检查';
  }

  Future<void> _check() async {
    final result = await service.checkNow();
    if (result.error != null) {
      SmartDialog.showToast(result.error!);
      return;
    }
    SmartDialog.showToast(
      result.newCount > 0 ? '发现 ${result.newCount} 部新集' : '已是最新',
    );
  }

  void _showIntervalPicker() {
    Utils.showBottomSheet(
      title: '检查间隔',
      child: Obx(
        () => ListView(
          children: FollowStorage.intervalOptions.map((minutes) {
            return ListTile(
              title: Text(_intervalLabel(minutes)),
              trailing: service.intervalMinutes.value == minutes
                  ? Icon(Icons.check, color: Get.theme.colorScheme.primary)
                  : null,
              onTap: () {
                service.setIntervalMinutes(minutes);
                Get.back();
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _openDetail(FollowedAnime anime) {
    service.markRead(anime.id);
    Get.toNamed('/bangumi/${anime.id}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DesktopCentered(
        child: SafeArea(
          top: true,
          bottom: false,
          maintainBottomViewPadding: false,
          child: Column(
            children: [
              const CustomDragToMoveArea(
                child: SizedBox(height: 24, width: double.infinity),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '追番自动化',
                      style: Get.textTheme.titleMedium,
                    ),
                    const Spacer(),
                    Obx(
                      () => service.checking.value
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : IconButton(
                              tooltip: '立即检查',
                              onPressed: _check,
                              icon: const Icon(Icons.refresh),
                            ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Obx(
                  () => RefreshIndicator(
                    onRefresh: _check,
                    child: ListView(
                      padding: AppStyle.edgeInsetsA12,
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        _sectionTitle('自动化'),
                        SettingsCard(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SettingsSwitch(
                                title: '自动检查新集',
                                subtitle: '按设定间隔检查「我在看」的番剧更新',
                                value: service.enabled.value,
                                onChanged: service.setEnabled,
                              ),
                              AppStyle.divider,
                              ListTile(
                                title: const Text('检查间隔'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _intervalLabel(
                                          service.intervalMinutes.value),
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right, size: 20),
                                  ],
                                ),
                                onTap: _showIntervalPicker,
                              ),
                              AppStyle.divider,
                              SettingsSwitch(
                                title: '新集系统通知',
                                subtitle: '发现新集时发送桌面通知',
                                value: service.notify.value,
                                onChanged: service.setNotify,
                              ),
                              AppStyle.divider,
                              SettingsSwitch(
                                title: '自动缓存新集',
                                subtitle: '发现新集时自动用第一条线路缓存',
                                value: service.autoCache.value,
                                onChanged: service.setAutoCache,
                              ),
                              AppStyle.divider,
                              ListTile(
                                title: const Text('立即检查'),
                                subtitle: Text(
                                    _lastCheckText(service.lastCheck.value)),
                                trailing:
                                    const Icon(Icons.chevron_right, size: 20),
                                onTap: _check,
                              ),
                            ],
                          ),
                        ),
                        _sectionTitle('我追的番（${service.items.length}）'),
                        if (service.items.isEmpty)
                          SettingsCard(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                children: [
                                  Icon(Icons.movie_filter_outlined,
                                      size: 40,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant),
                                  const SizedBox(height: 12),
                                  const Text('还没有追番'),
                                  const SizedBox(height: 4),
                                  const Text(
                                    '在番剧详情页将状态设为「在看」后，这里会自动同步',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else ...[
                          if (service.items.any((e) => e.hasNew))
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: service.markAllRead,
                                child: const Text('全部标记已读'),
                              ),
                            ),
                          SettingsCard(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (var i = 0;
                                    i < service.items.length;
                                    i++) ...[
                                  _animeTile(
                                    context,
                                    service.items[i],
                                  ),
                                  if (i != service.items.length - 1)
                                    AppStyle.divider,
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _animeTile(BuildContext context, FollowedAnime anime) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 48,
          height: 64,
          child: anime.image.isEmpty
              ? Container(color: colorScheme.surfaceContainerHighest)
              : Image.network(
                  anime.image,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) {
                    return Container(
                        color: colorScheme.surfaceContainerHighest);
                  },
                ),
        ),
      ),
      title: Text(
        anime.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        anime.progressText,
        style: const TextStyle(fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (anime.hasNew)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.error,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                anime.newCount > 1 ? '新 ${anime.newCount}' : '新',
                style: TextStyle(
                  color: colorScheme.onError,
                  fontSize: 10,
                ),
              ),
            ),
          const Icon(Icons.chevron_right, size: 20),
        ],
      ),
      onTap: () => _openDetail(anime),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: AppStyle.edgeInsetsA12.copyWith(top: 12),
      child: Text(title, style: Get.textTheme.titleSmall),
    );
  }
}
