enum DownloadStatus {
  queued,
  downloading,
  paused,
  completed,
  failed,
}

class DownloadTask {
  final int bangumiId;
  final int episode;
  final String title;
  final String episodeTitle;
  final String image;
  final int lineIndex;
  final String url;
  final String filePath;
  final int received;
  final int total;
  final DownloadStatus status;
  final int createdAt;

  const DownloadTask({
    required this.bangumiId,
    required this.episode,
    required this.title,
    required this.episodeTitle,
    required this.image,
    required this.lineIndex,
    required this.url,
    required this.filePath,
    required this.received,
    required this.total,
    required this.status,
    required this.createdAt,
  });

  String get key => '${bangumiId}_$episode';

  double get progress {
    if (total <= 0) {
      return 0;
    }
    return (received / total).clamp(0.0, 1.0);
  }

  bool get isCompleted => status == DownloadStatus.completed;

  String get sizeText {
    final bytes = total > 0 ? total : received;
    if (bytes <= 0) {
      return '';
    }
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var index = 0;
    while (value >= 1024 && index < units.length - 1) {
      value /= 1024;
      index += 1;
    }
    return '${value.toStringAsFixed(index == 0 ? 0 : 1)}${units[index]}';
  }

  DownloadTask copyWith({
    int? received,
    int? total,
    DownloadStatus? status,
    String? filePath,
  }) {
    return DownloadTask(
      bangumiId: bangumiId,
      episode: episode,
      title: title,
      episodeTitle: episodeTitle,
      image: image,
      lineIndex: lineIndex,
      url: url,
      filePath: filePath ?? this.filePath,
      received: received ?? this.received,
      total: total ?? this.total,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bangumiId': bangumiId,
      'episode': episode,
      'title': title,
      'episodeTitle': episodeTitle,
      'image': image,
      'lineIndex': lineIndex,
      'url': url,
      'filePath': filePath,
      'received': received,
      'total': total,
      'status': status.name,
      'createdAt': createdAt,
    };
  }

  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    return DownloadTask(
      bangumiId: (json['bangumiId'] as num?)?.toInt() ?? 0,
      episode: (json['episode'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? '',
      episodeTitle: json['episodeTitle'] as String? ?? '',
      image: json['image'] as String? ?? '',
      lineIndex: (json['lineIndex'] as num?)?.toInt() ?? 0,
      url: json['url'] as String? ?? '',
      filePath: json['filePath'] as String? ?? '',
      received: (json['received'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
      status: DownloadStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => DownloadStatus.paused,
      ),
      createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
    );
  }
}
