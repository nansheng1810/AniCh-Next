import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:xs/src/apis/bangumi.dart';

class CommentController extends GetxController
    with StateMixin, WidgetsBindingObserver, GetTickerProviderStateMixin {
  RxString id = ''.obs;
  RxList comments = [].obs;
  RxInt total = 0.obs;
  RxBool hasMore = false.obs;
  RxBool commentsLoading = true.obs;
  RxList commentReplies = [].obs;
  RxBool commentRepliesLoading = true.obs;

  // 分页游标（接口返回的 next，本质是已加载条数）
  int? _next;

  // 已经请求过的评论 id，避免 GetBuilder 每次重建都重复请求
  String? _loadedId;

  @override
  void onInit() {
    WidgetsBinding.instance.addObserver(this);
    super.onInit();
  }

  // 首次进入/切换剧集时加载；已加载过的 id 不再重复请求
  Future<void> loadComments(String id) async {
    if (_loadedId == id) {
      return;
    }
    await getComments(id);
  }

  // 获取评论列表
  Future<void> getComments(id) async {
    try {
      _loadedId = '$id';
      change(null, status: RxStatus.loading());
      comments.clear();
      total(0);
      hasMore(false);
      _next = null;
      commentsLoading(true);
      debugPrint('CommentController-getComments');
      final response = await BangumiApi.getComments(id: id);
      if (response.statusCode == 200) {
        final body = response.data['body'];
        comments.addAll((body['data'] as List).toList());
        _applyPagination(body);
        change(comments, status: RxStatus.success());
      } else {
        throw Error();
      }
    } catch (e) {
      debugPrint(e.toString());
      _loadedId = null;
      change(null, status: RxStatus.error('error'));
    }
    commentsLoading(false);
  }

  void _applyPagination(dynamic body) {
    total((body['total'] is num)
        ? (body['total'] as num).toInt()
        : comments.length);
    final next = body['next'];
    if (next is num) {
      _next = next.toInt();
      hasMore(true);
    } else {
      _next = null;
      hasMore(false);
    }
  }

  // 评论列表加载更多
  void getMoreComments(id) async {
    if (!hasMore.value || _next == null || commentsLoading.isTrue) {
      return;
    }
    try {
      commentsLoading(true);
      debugPrint('CommentController-getMoreComments');
      final response = await BangumiApi.getComments(id: id, skip: _next);
      if (response.statusCode == 200) {
        final body = response.data['body'];
        final existing = comments.map((e) => e['id']).toSet();
        for (final item in (body['data'] as List)) {
          if (!existing.contains(item['id'])) {
            comments.add(item);
          }
        }
        _applyPagination(body);
        update();
      } else {
        throw Error();
      }
    } catch (e) {
      debugPrint(e.toString());
    }
    commentsLoading(false);
  }

  // 发送评论
  Future<bool> sendComment(json) async {
    try {
      debugPrint('CommentController-sendComment');
      final response = await BangumiApi.postComment(
          id: json['id'], contents: json['contents']);
      if (response.statusCode == 200) {
        final body = response.data['body'];
        if (body is Map) {
          // 服务端返回的新评论缺少部分展示字段，补全后再插入列表
          body['like'] ??= false;
          body['likes_count'] ??= 0;
          body['replies'] ??= [];
          comments.insert(0, body);
          total(total.value + 1);
        }
        update();
        SmartDialog.showToast('发送成功');
        return true;
      } else {
        throw Error();
      }
    } catch (e) {
      debugPrint(e.toString());
      SmartDialog.showToast('发送失败');
    }
    return false;
  }

  // 回复评论
  Future<Map> replyComment({json, parent, reply}) async {
    try {
      debugPrint('CommentController-replyComment');
      final response = await BangumiApi.postComment(
          id: json['id'],
          parent: parent,
          reply: reply,
          contents: json['contents']);
      if (response.statusCode == 200) {
        // comments.insert(0, response.data['body']);
        SmartDialog.showToast('回复成功');
        return response.data['body'];
      } else {
        throw Error();
      }
    } catch (e) {
      debugPrint(e.toString());
      SmartDialog.showToast('回复失败');
    }
    return {};
  }

  // 评论点赞
  Future<bool> likeComment(id) async {
    try {
      debugPrint('CommentController-likeComment');
      final response = await BangumiApi.likeComment(id: id);
      if (response.statusCode == 200) {
        return true;
      } else {
        throw Error();
      }
    } catch (e) {
      debugPrint(e.toString());
    }
    return false;
  }

  // 评论取消点赞
  Future<bool> cancelLikeComment(id) async {
    try {
      debugPrint('CommentController-cancelLikeComment');
      final response = await BangumiApi.cancelLikeComment(id: id);
      if (response.statusCode == 200) {
        return true;
      } else {
        throw Error();
      }
    } catch (e) {
      debugPrint(e.toString());
    }
    return false;
  }

  // 获取评论回复列表
  void getCommentReplies(id) async {
    try {
      commentReplies.clear();
      commentRepliesLoading(true);
      debugPrint('CommentController-getCommentReplies');
      final response = await BangumiApi.getCommentReplies(id: id);
      if (response.statusCode == 200) {
        commentReplies.addAll(response.data['body']['data'].toList());
      } else {
        throw Error();
      }
    } catch (e) {
      debugPrint(e.toString());
    }
    commentRepliesLoading(false);
  }

  // 评论回复加载更多
  void getMoreCommentReplies(id) async {
    try {
      commentRepliesLoading(true);
      debugPrint('CommentController-getMoreCommentReplies');
      final response = await BangumiApi.getCommentReplies(
          id: id, skip: commentReplies.last['id']);
      if (response.statusCode == 200) {
        commentReplies.addAll(response.data['body']['data'].toList());
      } else {
        throw Error();
      }
    } catch (e) {
      debugPrint(e.toString());
    }
    commentRepliesLoading(false);
  }
}
