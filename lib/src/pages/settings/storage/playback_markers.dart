import 'package:get_storage/get_storage.dart';

/// 单部番剧的片头结束、片尾开始标记（秒）。
class PlaybackMarkers {
  const PlaybackMarkers({this.introEnd = 0, this.outroStart = 0});

  final int introEnd;
  final int outroStart;

  bool get hasIntro => introEnd > 0;
  bool get hasOutro => outroStart > 0;
  bool get isEmpty => introEnd <= 0 && outroStart <= 0;
}

/// 按番剧 id 保存片头片尾标记，换集/重进播放页后仍然有效。
class PlaybackMarkersStorage {
  static GetStorage box = GetStorage();

  static String _key(int id) => 'playbackMarkers_$id';

  static PlaybackMarkers read(int id) {
    final value = box.read(_key(id));
    if (value is! Map) {
      return const PlaybackMarkers();
    }
    return PlaybackMarkers(
      introEnd: int.tryParse('${value['introEnd'] ?? 0}') ?? 0,
      outroStart: int.tryParse('${value['outroStart'] ?? 0}') ?? 0,
    );
  }

  static void write(int id, PlaybackMarkers markers) {
    box.write(_key(id), {
      'introEnd': markers.introEnd,
      'outroStart': markers.outroStart,
    });
  }

  static void setIntroEnd(int id, int seconds) {
    final markers = read(id);
    write(
        id,
        PlaybackMarkers(
          introEnd: seconds.clamp(0, 24 * 3600),
          outroStart: markers.outroStart,
        ));
  }

  static void setOutroStart(int id, int seconds) {
    final markers = read(id);
    write(
        id,
        PlaybackMarkers(
          introEnd: markers.introEnd,
          outroStart: seconds.clamp(0, 24 * 3600),
        ));
  }

  static void clear(int id) {
    box.remove(_key(id));
  }
}
