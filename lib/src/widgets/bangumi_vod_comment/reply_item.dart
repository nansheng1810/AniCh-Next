import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:xs/src/utils/app_style.dart';
import 'package:xs/src/utils/time.dart';
import 'package:xs/src/widgets/bangumi_vod_comment/comment_content.dart';
import 'package:xs/src/widgets/bangumi_vod_comment/controller.dart';
import 'package:xs/src/widgets/reply.dart';

class ReplyItem extends StatelessWidget {
  final Map reply;
  final Map comment;
  final CommentController controller;
  const ReplyItem(this.reply,
      {super.key, required this.controller, required this.comment});

  @override
  Widget build(BuildContext context) {
    RxInt likeCount = 0.obs;
    RxBool like = false.obs;
    if (reply['like'] != null) {
      like(reply['like']);
    }
    if (reply['likes_count'] != null) {
      likeCount(reply['likes_count']);
    }
    final userName = commentUserName(reply);
    final avatar = commentAvatar(reply);
    final createdAt = commentCreatedAt(reply);
    final to = reply['to'];
    final toName = to is Map ? '${to['name'] ?? ''}'.trim() : '';
    return Obx(() {
      return Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: InkWell(
          onTap: () {},
          child: Container(
            padding:
                const EdgeInsets.only(top: 5, bottom: 0, left: 10, right: 10),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(50),
                      child: Container(
                        width: 40,
                        height: 40,
                        color: commentAvatarColor(reply),
                        child: avatar != null
                            ? Image.network(avatar)
                            : Center(
                                child: Text(
                                  userName.substring(0, 1),
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 20),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(
                      width: 5,
                    ),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            style: const TextStyle(fontSize: 16),
                          ),
                          Opacity(
                            opacity: 0.6,
                            child: Row(
                              children: [
                                if (createdAt != null)
                                  Text(
                                    Time.dateFormat(createdAt),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                if (toName.isNotEmpty) ...[
                                  const SizedBox(width: 5),
                                  Text(
                                    '回复: @$toName',
                                    style: const TextStyle(fontSize: 12),
                                  )
                                ]
                              ],
                            ),
                          ),
                          Text.rich(
                            TextSpan(
                              style: const TextStyle(fontSize: 16),
                              children: commentSpans(reply),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(7),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () async {
                                      if (!like.value) {
                                        bool iSlike = await controller
                                            .likeComment(reply['id']);
                                        if (iSlike) {
                                          like(true);
                                          likeCount(likeCount.value + 1);
                                        } else {
                                          like(false);
                                        }
                                      } else {
                                        bool iSlike = await controller
                                            .cancelLikeComment(reply['id']);
                                        if (iSlike) {
                                          like(false);
                                          likeCount(likeCount.value - 1);
                                        } else {
                                          like(true);
                                        }
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(5),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.thumb_up,
                                            size: 14,
                                            color: like.value
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                : null,
                                          ),
                                          Text(
                                            likeCount.value > 0
                                                ? '${likeCount.value}'
                                                : '点赞',
                                            style: TextStyle(
                                              color: like.value
                                                  ? Theme.of(context)
                                                      .colorScheme
                                                      .primary
                                                  : null,
                                            ),
                                          )
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(7),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () async {
                                      Get.bottomSheet(ReplyNewDialog(
                                        id: controller.id.value,
                                        sendFn: (json) async {
                                          Get.back();
                                          final data =
                                              await controller.replyComment(
                                                  json: json,
                                                  parent: comment['id'],
                                                  reply: reply['id']);
                                          if (data.isNotEmpty) {
                                            controller.commentReplies.add(data);
                                            controller.update();
                                          }
                                        },
                                      ));
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(5),
                                      child: const Row(
                                        children: [
                                          Icon(
                                            Icons.reply,
                                            size: 14,
                                          ),
                                          Text('回复')
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            ],
                          ),
                        ],
                      ),
                    )
                  ],
                ),
                AppStyle.divider
              ],
            ),
          ),
        ),
      );
    });
  }
}
