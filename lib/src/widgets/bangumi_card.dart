import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

/// 番剧网格统一卡片。
///
/// 所有番剧网格都使用这一个卡片，保证封面比例、标题行数、元信息行高一致：
/// 封面区撑满剩余高度，标题固定两行，元信息固定一行。
class BangumiCard extends StatelessWidget {
  const BangumiCard({
    super.key,
    required this.title,
    required this.image,
    required this.onTap,
    this.badge,
    this.meta,
    this.resumeLabel,
    this.onResume,
    this.onSecondaryTap,
  });

  final String title;
  final String image;
  final VoidCallback onTap;

  /// 封面右下角的角标，例如「更新至第 8 集」。
  final String? badge;

  /// 封面下方的一行说明，例如「正篇 · 2026年10月」。
  final String? meta;

  /// 封面左上角的续播角标，例如「续看第 5 集」。
  final String? resumeLabel;

  /// 点击续播角标时直接进入对应剧集。
  final VoidCallback? onResume;

  /// 右键菜单回调，参数为全局坐标。
  final ValueChanged<Offset>? onSecondaryTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final Widget placeholder = SvgPicture.asset(
      'assets/images/no_image.svg',
      fit: BoxFit.cover,
    );
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onSecondaryTapDown: onSecondaryTap == null
            ? null
            : (details) => onSecondaryTap!(details.globalPosition),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: colorScheme.onSurface.withAlpha(12)),
                    image.isEmpty
                        ? placeholder
                        : Image.network(
                            image,
                            fit: BoxFit.cover,
                            // 按卡片实际显示尺寸解码，避免把原图整张留在内存里
                            cacheWidth:
                                (MediaQuery.of(context).devicePixelRatio * 180)
                                    .round(),
                            errorBuilder: (context, error, stackTrace) =>
                                placeholder,
                          ),
                    if (resumeLabel != null && resumeLabel!.isNotEmpty)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Material(
                          color: Colors.black.withAlpha(145),
                          borderRadius: BorderRadius.circular(6),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: onResume,
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(5, 3, 7, 3),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.play_arrow,
                                      size: 12, color: Colors.white),
                                  const SizedBox(width: 1),
                                  Text(
                                    resumeLabel!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (badge != null && badge!.isNotEmpty)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(10, 22, 10, 7),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withAlpha(150),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: Text(
                            badge!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 34,
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.25,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(
              height: 16,
              child: Text(
                meta ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 与 [BangumiCard] 尺寸一致的骨架占位。
class BangumiCardSkeleton extends StatelessWidget {
  const BangumiCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface.withAlpha(12);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _bar(color, height: 12, widthFactor: 0.85),
        const SizedBox(height: 6),
        _bar(color, height: 12, widthFactor: 0.5),
        const SizedBox(height: 8),
        _bar(color, height: 10, widthFactor: 0.35),
      ],
    );
  }

  Widget _bar(Color color, {required double height, required double widthFactor}) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

/// 给骨架占位加呼吸动画，提示正在加载。
class SkeletonPulse extends StatefulWidget {
  const SkeletonPulse({super.key, required this.child});

  final Widget child;

  @override
  State<SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<SkeletonPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  )..repeat(reverse: true);

  late final Animation<double> _opacity = Tween<double>(begin: 0.4, end: 1)
      .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _opacity, child: widget.child);
  }
}

/// 加载中的文字提示 + 小转圈。
class BangumiLoadingHint extends StatelessWidget {
  const BangumiLoadingHint({super.key, this.text = '正在加载番剧…'});

  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}
