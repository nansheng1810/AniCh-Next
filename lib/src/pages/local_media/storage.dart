import 'package:get_storage/get_storage.dart';

/// 本地视频条目
class LocalVideo {
  const LocalVideo({
    required this.path,
    required this.name,
    required this.folder,
    required this.size,
  });

  final String path;
  final String name;
  final String folder;
  final int size;

  String get sizeText {
    if (size >= 1 << 30) {
      return '${(size / (1 << 30)).toStringAsFixed(1)} GB';
    }
    if (size >= 1 << 20) {
      return '${(size / (1 << 20)).toStringAsFixed(1)} MB';
    }
    return '${(size / 1024).toStringAsFixed(0)} KB';
  }
}

/// 本地播放进度
class LocalPlayProgress {
  const LocalPlayProgress({
    required this.position,
    required this.duration,
    required this.updatedAt,
  });

  final int position;
  final int duration;
  final int updatedAt;

  bool get hasProgress {
    return position > 5000 && duration > 0 && position < duration * 0.95;
  }

  double get ratio {
    if (duration <= 0) {
      return 0;
    }
    return (position / duration).clamp(0.0, 1.0);
  }

  factory LocalPlayProgress.fromJson(Map<String, dynamic> json) {
    return LocalPlayProgress(
      position: (json['position'] as num?)?.toInt() ?? 0,
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'position': position,
      'duration': duration,
      'updatedAt': updatedAt,
    };
  }
}

/// 本地媒体库：监控文件夹与续播进度。
class LocalMediaStorage {
  static GetStorage box = GetStorage();

  static const List<String> videoExtensions = [
    'mp4',
    'mkv',
    'avi',
    'mov',
    'webm',
    'flv',
    'ts',
    'm2ts',
    'm4v',
    'wmv',
  ];

  static List<String> get folders {
    final raw = box.read('localMediaFolders');
    if (raw is List) {
      return raw.whereType<String>().toList();
    }
    return [];
  }

  static void addFolder(String path) {
    if (folders.contains(path)) {
      return;
    }
    box.write('localMediaFolders', [...folders, path]);
  }

  static void removeFolder(String path) {
    box.write(
      'localMediaFolders',
      folders.where((folder) => folder != path).toList(),
    );
  }

  static Map<String, LocalPlayProgress> get progress {
    final raw = box.read('localMediaProgress');
    if (raw is Map) {
      return raw.map((key, value) {
        return MapEntry(
          key.toString(),
          LocalPlayProgress.fromJson(Map<String, dynamic>.from(value as Map)),
        );
      });
    }
    return {};
  }

  static LocalPlayProgress? progressOf(String path) {
    return progress[path];
  }

  static void saveProgress(String path, int position, int duration) {
    if (duration <= 0) {
      return;
    }
    final map = progress;
    map[path] = LocalPlayProgress(
      position: position,
      duration: duration,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    box.write(
      'localMediaProgress',
      map.map((key, value) => MapEntry(key, value.toJson())),
    );
  }

  static void clearProgress(String path) {
    final map = progress;
    map.remove(path);
    box.write(
      'localMediaProgress',
      map.map((key, value) => MapEntry(key, value.toJson())),
    );
  }
}
