import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:xs/src/utils/utils.dart';

/// 续播信息：最近观看的一集及其进度（秒）。
class PlayResume {
  const PlayResume({required this.episode, required this.position});

  final int episode;
  final int position;
}

class PlayHistoryStorage {
  static GetStorage box = GetStorage('playHistory');

  /// 观看记录版本号，供 Obx 订阅以避免直接监听动态列表。
  static final RxInt revision = 0.obs;

  static void init() {
    history(box.getValues().toList());
    revision.value++;
  }

  // 历史记录
  static dynamic history = [].obs;

  // 写入观看记录，同时刷新可观察列表（播放页每 5 秒调用一次）
  // notify 为 false 时只落盘不通知 UI，避免播放页在后台每 5 秒触发详情页重建
  static void save(int id, Map item, {bool notify = true}) {
    box.write(id.toString(), item);
    if (!notify) {
      return;
    }
    history(box.getValues().toList());
    revision.value++;
  }

  // 最近观看的一集，没有记录时返回 null
  static PlayResume? resume(int id) {
    for (final item in history) {
      if (item is! Map || item['id'].toString() != id.toString()) {
        continue;
      }
      final episodes = item['episodes'];
      if (episodes is! List || episodes.isEmpty) {
        return null;
      }
      Map? latest;
      for (final episode in episodes) {
        if (episode is! Map) continue;
        final date = int.tryParse(episode['date'].toString()) ?? 0;
        if (latest == null ||
            date > (int.tryParse(latest['date'].toString()) ?? 0)) {
          latest = episode;
        }
      }
      if (latest == null) {
        return null;
      }
      final number = int.tryParse(latest['episode'].toString()) ?? 0;
      if (number <= 0) {
        return null;
      }
      return PlayResume(
          episode: number,
          position: int.tryParse(latest['position'].toString()) ?? 0);
    }
    return null;
  }

  // 清空历史记录
  static void clean() async {
    var result = await Utils.showAlertDialog('确定要清空观看记录吗?', title: '清空观看记录');
    if (!result) {
      return;
    }
    box.erase();
    history(box.getValues().toList());
    revision.value++;
  }

  // 删除历史记录
  static void remove(id) async {
    box.remove(id.toString());
    history(box.getValues().toList());
    revision.value++;
  }

  // 获取历史记录
  static int getLastPosition(id, episode) {
    try {
      final history = box.read(id.toString());
      if (history is! Map) {
        return 0;
      }
      final episodes = history['episodes'];
      if (episodes is! List) {
        return 0;
      }
      final item = episodes.firstWhere(
          (e) => e is Map && e['episode'].toString() == episode.toString(),
          orElse: () => {});
      return int.tryParse('${item['position'] ?? 0}') ?? 0;
    } catch (e) {
      return 0;
    }
  }
}
