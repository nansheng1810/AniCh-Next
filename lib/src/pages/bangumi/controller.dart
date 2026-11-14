import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:xs/protobuf/bangumi.pb.dart';
import 'package:xs/src/apis/bangumi.dart';

/// 番剧页自身的状态：0 番剧库（筛选 + 网格）、1 最近更新。
class BangumiController extends GetxController {
  final RxInt mode = 0.obs;
}

/// 番剧库：类型 / 语言 / 年份 / 分类 / 标签 一起作为筛选条件，
/// 所有条件都在同一个接口里生效，结果直接展示在右侧网格。
class BangumiLibraryController extends GetxController
    with StateMixin<List<bangumi_list_item_>> {
  final List<bangumi_list_item_> result = [];
  final RxBool isLoading = false.obs;
  final RxBool hasMore = true.obs;

  final RxString type = ''.obs;
  final RxString lang = ''.obs;
  final RxString year = ''.obs;
  final RxString genre = ''.obs;
  final RxString mark = ''.obs;

  final RxList<Tag> genres = <Tag>[].obs;
  final RxList<Tag> marks = <Tag>[].obs;
  final RxBool genresDone = false.obs;
  final RxBool marksDone = false.obs;

  static const Map<String, String> typeList = {
    '': '全部',
    'tv': '正篇',
    'movie': '剧场版',
    'ova': '特别篇',
  };

  static const Map<String, String> langList = {
    '': '全部',
    'ja': '日语',
    'zh': '国语',
    'en': '英语',
    'ko': '韩语',
    'other': '其他',
  };

  /// 第一项为空字符串，表示不限年份。
  final List<String> yearList = [''];

  /// 请求序号：快速连续切换筛选条件时丢弃过期响应。
  int _requestId = 0;

  bool get hasFilter =>
      type.value.isNotEmpty ||
      lang.value.isNotEmpty ||
      year.value.isNotEmpty ||
      genre.value.isNotEmpty ||
      mark.value.isNotEmpty;

  @override
  void onInit() {
    for (int i = 0; i < 35; i++) {
      yearList.add('${DateTime.now().year - i}');
    }
    // 从详情页的分类/标签点进来时预选条件
    final arguments = Get.arguments;
    if (arguments is Map) {
      genre((arguments['genre'] ?? '').toString());
      mark((arguments['mark'] ?? '').toString());
    }
    get();
    loadTags('genre');
    loadTags('mark');
    super.onInit();
  }

  // 拉取第一页（同时用于切换筛选后的刷新）
  Future<void> get() async {
    final requestId = ++_requestId;
    try {
      change(null, status: RxStatus.loading());
      final response = await BangumiApi.getBangumiList(
        type: type.value,
        lang: lang.value,
        year: year.value,
        genre: genre.value,
        mark: mark.value,
      );
      if (requestId != _requestId) return;
      final data = bangumi_list_.fromBuffer(response.data);
      result
        ..clear()
        ..addAll(data.data);
      hasMore(true);
      change(result, status: RxStatus.success());
    } catch (e) {
      if (requestId != _requestId) return;
      debugPrint(e.toString());
      change(null, status: RxStatus.error('加载失败'));
    }
  }

  // 加载更多
  void more() async {
    if (isLoading.value || !hasMore.value || result.isEmpty) return;
    final requestId = _requestId;
    try {
      isLoading(true);
      final response = await BangumiApi.getBangumiList(
        type: type.value,
        lang: lang.value,
        year: year.value,
        genre: genre.value,
        mark: mark.value,
        skip: result.last.id,
      );
      if (requestId != _requestId) return;
      final data = bangumi_list_.fromBuffer(response.data);
      if (data.data.isEmpty) {
        hasMore(false);
      } else {
        result.addAll(data.data);
        change(result, status: RxStatus.success());
      }
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      isLoading(false);
    }
  }

  // 刷新
  Future<bool> reload() async {
    await get();
    return true;
  }

  void selectType(String value) {
    type(value == type.value ? '' : value);
    get();
  }

  void selectLang(String value) {
    lang(value == lang.value ? '' : value);
    get();
  }

  void selectYear(String value) {
    year(value);
    get();
  }

  void selectGenre(String value) {
    genre(value == genre.value ? '' : value);
    get();
  }

  void selectMark(String value) {
    mark(value == mark.value ? '' : value);
    get();
  }

  void reset() {
    type('');
    lang('');
    year('');
    genre('');
    mark('');
    get();
  }

  // 分类 / 标签候选
  void loadTags(String tagType, {int skip = 0}) async {
    try {
      final response = await BangumiApi.getTags(type: tagType, skip: skip);
      final List<Tag> tags =
          List<Tag>.from(response.data.map((e) => Tag.fromJson(e)));
      if (tagType == 'genre') {
        genres.addAll(tags);
        if (tags.isEmpty) genresDone(true);
      } else {
        marks.addAll(tags);
        if (tags.isEmpty) marksDone(true);
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  void moreTags(String tagType) {
    if (tagType == 'genre') {
      if (genresDone.value) return;
      loadTags('genre', skip: genres.length);
    } else {
      if (marksDone.value) return;
      loadTags('mark', skip: marks.length);
    }
  }
}

class BangumiLatestController extends GetxController
    with StateMixin<List<bangumi_latest_item_>> {
  List<bangumi_latest_item_> result = [];
  RxBool isLoading = false.obs;

  @override
  void onInit() {
    get();
    super.onInit();
  }

  // 获取数据
  void get() async {
    try {
      debugPrint('BangumiLatestController-get');
      change(result, status: RxStatus.loading());
      final response = await BangumiApi.getBangumiLatest();
      final data = bangumi_latest_.fromBuffer(response.data);
      result.addAll(data.data);
      change(result, status: RxStatus.success());
    } catch (e) {
      debugPrint(e.toString());
      change(null, status: RxStatus.error('error'));
    }
  }

  // 刷新
  Future<bool> reload() async {
    try {
      debugPrint('BangumiLatestController-reload');
      final response = await BangumiApi.getBangumiLatest();
      final data = bangumi_latest_.fromBuffer(response.data);
      result.clear();
      result.addAll(data.data);
      change(result, status: RxStatus.success());
    } catch (e) {
      debugPrint(e.toString());
    }
    return true;
  }
}

class Tag {
  String? name;
  int? count;
  String? image;

  Tag({
    this.name,
    this.count,
    this.image,
  });
  Tag.fromJson(Map<String, dynamic> json) {
    name = json['name']?.toString();
    count = json['count']?.toInt();
    image = json['image']?.toString();
  }
  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['name'] = name;
    data['count'] = count;
    data['image'] = image;
    return data;
  }
}
