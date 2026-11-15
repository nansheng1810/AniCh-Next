import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:xs/protobuf/bangumi.pb.dart';
import 'package:xs/src/apis/bangumi.dart';
import 'package:xs/src/pages/bangumi_collection/models/bangumi_collection_model.dart'
    as collection;
import 'package:xs/src/pages/download/download_manager.dart';
import 'package:xs/src/pages/follow/follow_storage.dart';
import 'package:xs/src/pages/follow/models/followed_anime.dart';
import 'package:xs/src/utils/account.dart';
import 'package:xs/src/utils/notification.dart';

class FollowCheckResult {
  const FollowCheckResult({
    this.checked = 0,
    this.newCount = 0,
    this.error,
  });

  /// 本次检查到的追番数量
  final int checked;

  /// 本次发现更新的番剧数量
  final int newCount;

  /// 出错信息，正常时为 null
  final String? error;
}

/// 追番自动化：定时读取「我在看」列表，检测新集并通知/自动缓存。
class FollowService {
  FollowService._();

  static final FollowService instance = FollowService._();

  final RxList<FollowedAnime> items = <FollowedAnime>[].obs;
  final RxBool checking = false.obs;
  final RxInt lastCheck = 0.obs;

  final RxBool enabled = FollowStorage.enabled.obs;
  final RxInt intervalMinutes = FollowStorage.intervalMinutes.obs;
  final RxBool notify = FollowStorage.notify.obs;
  final RxBool autoCache = FollowStorage.autoCache.obs;

  Timer? _timer;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    _load();
    applySchedule();
    // 启动时若已超过检查间隔，延迟一小段时间再检查，避免和首屏请求抢带宽
    final elapsed =
        DateTime.now().millisecondsSinceEpoch - FollowStorage.lastCheck;
    if (FollowStorage.enabled &&
        elapsed >= FollowStorage.intervalMinutes * 60 * 1000) {
      Timer(const Duration(seconds: 20), checkNow);
    }
  }

  void _load() {
    items.assignAll(
      FollowStorage.snapshots.map(FollowedAnime.fromJson).toList(),
    );
    lastCheck(FollowStorage.lastCheck);
  }

  /// 根据当前设置启动或停止定时器。
  void applySchedule() {
    _timer?.cancel();
    if (!enabled.value) {
      return;
    }
    _timer = Timer.periodic(
      Duration(minutes: intervalMinutes.value),
      (_) => checkNow(),
    );
  }

  void setEnabled(bool value) {
    enabled(value);
    FollowStorage.setEnabled(value);
    applySchedule();
    if (value && items.isEmpty) {
      checkNow();
    }
  }

  void setIntervalMinutes(int value) {
    intervalMinutes(value);
    FollowStorage.setIntervalMinutes(value);
    applySchedule();
  }

  void setNotify(bool value) {
    notify(value);
    FollowStorage.setNotify(value);
  }

  void setAutoCache(bool value) {
    autoCache(value);
    FollowStorage.setAutoCache(value);
  }

  /// 立即检查一次追番列表。
  Future<FollowCheckResult> checkNow() async {
    if (checking.value) {
      return const FollowCheckResult();
    }
    if (AccountUtil.token().isEmpty) {
      return const FollowCheckResult(error: '请先登录后再检查追番');
    }
    checking(true);
    try {
      final all = <collection.Data>[];
      for (var page = 1; page <= 20; page++) {
        final response = await BangumiApi.getCollect(page: page, type: 'watch');
        if (response.statusCode != 200 || response.data is! Map) {
          return const FollowCheckResult(error: '读取追番列表失败');
        }
        final parsed = collection.BangumiCollection.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
        final body = parsed.body;
        if (body == null || (body.data?.isEmpty ?? true)) {
          break;
        }
        all.addAll(body.data!);
        if (!(body.next ?? false)) {
          break;
        }
      }

      final previous = {for (final item in items) item.id: item};
      final next = <FollowedAnime>[];
      final updates = <FollowedAnime>[];
      for (final data in all) {
        final id = data.id;
        if (id == null) {
          continue;
        }
        final old = previous[id];
        final episode = data.episode ?? 0;
        final anime = FollowedAnime(
          id: id,
          title: data.title ?? old?.title ?? '',
          image: data.image ?? old?.image ?? '',
          episode: episode,
          total: data.episodesTotal ?? old?.total ?? 0,
          updatedAt: data.date ?? old?.updatedAt ?? 0,
          // 首次记录时以当前集数为基线，不产生新集提醒
          notifiedEpisode: old?.notifiedEpisode ?? episode,
        );
        if (old != null && episode > old.episode) {
          updates.add(anime);
        }
        next.add(anime);
      }
      next.sort((a, b) {
        if (a.hasNew != b.hasNew) {
          return a.hasNew ? -1 : 1;
        }
        return b.updatedAt.compareTo(a.updatedAt);
      });

      items.assignAll(next);
      _persist();
      final now = DateTime.now().millisecondsSinceEpoch;
      lastCheck(now);
      FollowStorage.setLastCheck(now);

      if (updates.isNotEmpty) {
        if (notify.value) {
          await _notifyUpdates(updates);
        }
        if (autoCache.value) {
          for (final anime in updates) {
            await _autoCache(anime);
          }
        }
      }
      return FollowCheckResult(checked: next.length, newCount: updates.length);
    } catch (e) {
      debugPrint('追番检查失败: $e');
      return const FollowCheckResult(error: '检查失败，请稍后重试');
    } finally {
      checking(false);
    }
  }

  /// 标记单部番剧已读，清除新集标记。
  void markRead(int id) {
    final index = items.indexWhere((e) => e.id == id);
    if (index < 0) {
      return;
    }
    final item = items[index];
    if (!item.hasNew) {
      return;
    }
    items[index] = item.copyWith(notifiedEpisode: item.episode);
    _persist();
  }

  void markAllRead() {
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item.hasNew) {
        items[i] = item.copyWith(notifiedEpisode: item.episode);
      }
    }
    _persist();
  }

  void _persist() {
    FollowStorage.saveSnapshots(items.map((e) => e.toJson()).toList());
  }

  Future<void> _notifyUpdates(List<FollowedAnime> updates) async {
    if (updates.length == 1) {
      final anime = updates.first;
      await NotificationService.show(
        '追番更新',
        '《${anime.title}》更新至第 ${anime.episode} 集',
      );
      return;
    }
    final titles = updates.take(3).map((e) => '《${e.title}》').join('、');
    await NotificationService.show(
      '${updates.length} 部追番更新',
      '$titles${updates.length > 3 ? ' 等' : ''}已更新',
    );
  }

  /// 自动缓存新集：取第一条线路创建下载任务。
  Future<void> _autoCache(FollowedAnime anime) async {
    try {
      final manager = Get.isRegistered<DownloadManager>()
          ? DownloadManager.instance
          : Get.put(DownloadManager());
      if (manager.localPath(anime.id, anime.episode) != null) {
        return;
      }
      final response = await BangumiApi.getBangumiEpisodeVod(
        id: anime.id,
        episode: anime.episode,
      );
      if (response.statusCode != 200) {
        return;
      }
      final data = vod_.fromBuffer(response.data.cast<int>());
      if (data.data.isEmpty) {
        return;
      }
      final url = _decodeUrl(data.data.first.url);
      if (url.isEmpty) {
        return;
      }
      await manager.addTask(
        bangumiId: anime.id,
        episode: anime.episode,
        title: anime.title,
        episodeTitle: '第${anime.episode}集',
        image: anime.image,
        lineIndex: 0,
        url: url,
      );
    } catch (e) {
      debugPrint('自动缓存失败: $e');
    }
  }

  String _decodeUrl(String value) {
    try {
      return utf8.decode(
        base64.decode(
            base64.normalize(value.substring(0, 3) + value.substring(4))),
      );
    } catch (_) {
      return '';
    }
  }
}
