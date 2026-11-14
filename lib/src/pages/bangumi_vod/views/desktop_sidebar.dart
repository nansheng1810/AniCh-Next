import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:xs/protobuf/bangumi.pb.dart';
import 'package:xs/src/pages/bangumi_vod/controller.dart';
import 'package:xs/src/utils/time.dart';
import 'package:xs/src/widgets/bangumi_vod_comment/comment_item.dart';
import 'package:xs/src/widgets/bangumi_vod_comment/controller.dart';
import 'package:xs/src/widgets/drag_to_move_bar.dart';
import 'package:xs/src/widgets/expandable_text.dart';
import 'package:xs/src/widgets/reply.dart';

/// 桌面端播放页右侧栏：追番入口 + 简介/评论 + 选集。
class BangumiVodDesktopSidebar extends StatelessWidget {
  const BangumiVodDesktopSidebar({
    super.key,
    required this.controller,
    this.onCollapse,
  });

  final BangumiVodPageController controller;

  /// 点击「隐藏侧栏」按钮时回调
  final VoidCallback? onCollapse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 无边框窗口下提供拖动区域，避免桌面端无法移动窗口
          CustomDragToMoveArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: () {
                            if (controller.fullScreenState.value) {
                              controller.exitFull();
                            }
                            Get.back();
                          },
                          icon:
                              const Icon(Icons.bookmark_add_outlined, size: 18),
                          label: const Text('追番 · 返回番剧详情'),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: '隐藏侧栏',
                        onPressed: onCollapse,
                        icon: const Icon(Icons.keyboard_double_arrow_right,
                            size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${controller.data.title}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '第${controller.getEpisodeData().sort}集 '
                    '${controller.getEpisodeData().title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12, color: theme.colorScheme.primary),
                  ),
                ],
              ),
            ),
          ),
          TabBar(
            controller: controller.tabController,
            tabs: controller.tabs,
            labelColor: theme.colorScheme.primary,
            indicatorColor: theme.colorScheme.primary,
            dividerColor: Colors.transparent,
            labelStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            unselectedLabelStyle: const TextStyle(fontSize: 13),
          ),
          Expanded(
            child: TabBarView(
              controller: controller.tabController,
              children: [
                _OverviewPanel(controller: controller),
                _CommentsPanel(controller: controller),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewPanel extends StatelessWidget {
  const _OverviewPanel({required this.controller});

  final BangumiVodPageController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = controller.data;
    final episode = controller.getEpisodeData();
    final marks = data.marks?.fold<int>(0, (p, e) => p + (e?.count ?? 0)) ?? 0;
    final genres = (data.genres ?? []).whereType<String>().join(' · ');
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            _MetaText(text: '${data.episode ?? controller.episodes.length} 话'),
            if (marks > 0) _MetaText(text: '$marks 人追番'),
            if (genres.isNotEmpty) _MetaText(text: genres),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '本集概况：${episode.overview.isNotEmpty ? episode.overview : '暂无简介'}',
          style: const TextStyle(fontSize: 13, height: 1.5),
        ),
        if (episode.airdate > 0) ...[
          const SizedBox(height: 6),
          Text(
            '放送时间：${Time.dateTimeFormat(episode.airdate.toInt())}',
            style: TextStyle(fontSize: 12, color: theme.hintColor),
          ),
        ],
        if (data.overview != null && data.overview!.isNotEmpty) ...[
          const SizedBox(height: 12),
          ExpandableText(
            '番剧简介：${data.overview}',
            maxLines: 4,
            style: const TextStyle(fontSize: 13, height: 1.5),
          ),
        ],
        const SizedBox(height: 18),
        const Text('选集',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _EpisodeGrid(controller: controller),
      ],
    );
  }
}

class _MetaText extends StatelessWidget {
  const _MetaText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
    );
  }
}

class _EpisodeGrid extends StatelessWidget {
  const _EpisodeGrid({required this.controller});

  final BangumiVodPageController controller;

  @override
  Widget build(BuildContext context) {
    final episodes = controller.episodes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (episodes.isNotEmpty) _episodeWrap(context, episodes),
      ],
    );
  }

  Widget _episodeWrap(
      BuildContext context, List<bangumi_episodes_data_> episodes) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in episodes)
          _episodeItem(context, item.sort, item.title),
      ],
    );
  }

  Widget _episodeItem(BuildContext context, int sort, String title) {
    final theme = Theme.of(context);
    final active = controller.episode == sort;
    return Tooltip(
      message: title,
      waitDuration: const Duration(milliseconds: 400),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          if (active) {
            return;
          }
          controller.changeEpisode(sort);
        },
        child: Container(
          width: 44,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? theme.colorScheme.primary.withAlpha(30)
                : theme.colorScheme.onSurface.withAlpha(10),
            borderRadius: BorderRadius.circular(8),
            border:
                active ? Border.all(color: theme.colorScheme.primary) : null,
          ),
          child: Text(
            '$sort',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: active ? theme.colorScheme.primary : null,
              fontWeight: active ? FontWeight.bold : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _CommentsPanel extends StatefulWidget {
  const _CommentsPanel({required this.controller});

  final BangumiVodPageController controller;

  @override
  State<_CommentsPanel> createState() => _CommentsPanelState();
}

class _CommentsPanelState extends State<_CommentsPanel> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _sending = false;

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _send(CommentController commentController, String id) async {
    final text = _textController.text.trim();
    if (text.isEmpty || _sending) {
      return;
    }
    setState(() => _sending = true);
    final success = await commentController.sendComment({
      'id': id,
      'contents': [
        {'content': '$text\n', 'type': 'text'}
      ],
    });
    if (!mounted) {
      return;
    }
    setState(() => _sending = false);
    if (success) {
      _textController.clear();
      _focusNode.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Obx(() {
      final id = '${widget.controller.id}|${widget.controller.episode}';
      return GetBuilder(
        global: false,
        init: CommentController(),
        builder: (commentController) {
          commentController.id(id);
          // 只在首次或切换剧集时请求，避免重建时重置列表导致「加载更多」失效
          commentController.loadComments(id);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 4, 2),
                child: Row(
                  children: [
                    Text(
                      '全部评论 (${commentController.total.value})',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: '刷新评论',
                      visualDensity: VisualDensity.compact,
                      iconSize: 18,
                      onPressed: () => commentController.getComments(id),
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: commentController.obx(
                  (state) => ListView.builder(
                    padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
                    itemCount: commentController.comments.length + 1,
                    itemBuilder: (context, index) {
                      if (index == commentController.comments.length) {
                        return _buildFooter(context, commentController, id);
                      }
                      final comment = commentController.comments[index];
                      return CommentItem(
                        comment,
                        controller: commentController,
                        replyFn: () {
                          Get.bottomSheet(ReplyNewDialog(
                            id: id,
                            sendFn: (json) async {
                              Get.back();
                              final data = await commentController.replyComment(
                                  json: json,
                                  parent: comment['id'],
                                  reply: null);
                              if (data.isNotEmpty) {
                                final replies = comment['replies'];
                                if (replies is List) {
                                  replies.add(data);
                                } else {
                                  comment['replies'] = [data];
                                }
                                commentController.update();
                              }
                            },
                          ));
                        },
                        likeFn: (id) => commentController.likeComment(id),
                        cancelLikeFn: (id) =>
                            commentController.cancelLikeComment(id),
                      );
                    },
                  ),
                  onLoading: const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  onError: (e) {
                    return Center(
                      child: TextButton(
                        onPressed: () => commentController.getComments(id),
                        child: const Text('评论加载失败，点击重试'),
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: theme.dividerColor.withAlpha(40)),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        focusNode: _focusNode,
                        minLines: 1,
                        maxLines: 3,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(commentController, id),
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: '发一条友善的评论',
                          hintStyle: const TextStyle(fontSize: 13),
                          isDense: true,
                          filled: true,
                          fillColor: theme.colorScheme.onSurface.withAlpha(12),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 9),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 36,
                      child: FilledButton(
                        onPressed: _sending
                            ? null
                            : () => _send(commentController, id),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          minimumSize: const Size(0, 36),
                          textStyle: const TextStyle(fontSize: 13),
                        ),
                        child: _sending
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('发布'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      );
    });
  }

  Widget _buildFooter(
      BuildContext context, CommentController commentController, String id) {
    return Obx(() {
      if (commentController.hasMore.value) {
        if (commentController.commentsLoading.value) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        return Center(
          child: TextButton(
            onPressed: () => commentController.getMoreComments(id),
            child: const Text('加载更多评论'),
          ),
        );
      }
      if (commentController.comments.isEmpty) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: Text('还没有评论，来发第一条吧')),
        );
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text(
            '没有更多评论了',
            style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
          ),
        ),
      );
    });
  }
}
