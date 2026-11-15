/// 本地保存的追番快照：用于检测新集与展示更新状态。
class FollowedAnime {
  const FollowedAnime({
    required this.id,
    required this.title,
    required this.image,
    required this.episode,
    required this.total,
    required this.updatedAt,
    required this.notifiedEpisode,
  });

  final int id;
  final String title;
  final String image;

  /// 服务端当前更新到的集数
  final int episode;

  /// 总集数，未知时为 0
  final int total;

  /// 服务端更新时间（原样保存，通常为时间戳）
  final int updatedAt;

  /// 用户已经知道的集数，低于 [episode] 时显示新集标记
  final int notifiedEpisode;

  bool get hasNew => episode > notifiedEpisode;

  int get newCount => episode - notifiedEpisode;

  String get progressText {
    if (total > 0) {
      return '更新至第 $episode 集 / 共 $total 集';
    }
    return '更新至第 $episode 集';
  }

  FollowedAnime copyWith({
    String? title,
    String? image,
    int? episode,
    int? total,
    int? updatedAt,
    int? notifiedEpisode,
  }) {
    return FollowedAnime(
      id: id,
      title: title ?? this.title,
      image: image ?? this.image,
      episode: episode ?? this.episode,
      total: total ?? this.total,
      updatedAt: updatedAt ?? this.updatedAt,
      notifiedEpisode: notifiedEpisode ?? this.notifiedEpisode,
    );
  }

  factory FollowedAnime.fromJson(Map<String, dynamic> json) {
    final episode = (json['episode'] as num?)?.toInt() ?? 0;
    return FollowedAnime(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? '',
      image: json['image']?.toString() ?? '',
      episode: episode,
      total: (json['total'] as num?)?.toInt() ?? 0,
      updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
      notifiedEpisode: (json['notifiedEpisode'] as num?)?.toInt() ?? episode,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'image': image,
      'episode': episode,
      'total': total,
      'updatedAt': updatedAt,
      'notifiedEpisode': notifiedEpisode,
    };
  }
}
