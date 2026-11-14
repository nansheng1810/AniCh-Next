import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:xs/src/apis/search.dart';
import 'package:xs/src/pages/search/models/search_type.dart';
import 'package:xs/src/pages/search_panel/storage.dart';

/// 一条搜索联想结果
class SearchSuggestion {
  const SearchSuggestion({required this.keyword, this.subtitle});

  final String keyword;
  final String? subtitle;
}

class SearchPanelController extends GetxController
    with StateMixin, WidgetsBindingObserver, GetTickerProviderStateMixin {
  final FocusNode searchFocusNode = FocusNode();
  Rx<TextEditingController> controller = TextEditingController().obs;
  RxString searchKeyWord = ''.obs;
  String hintText = '搜索';
  // 搜索历史，来自本地存储
  RxList<String> historyList = SearchHistoryStorage.list().obs;
  // 搜索联想，输入后自动加载
  RxList<SearchSuggestion> suggestList = <SearchSuggestion>[].obs;
  SearchType searchType = SearchType.picture;
  Timer? _suggestTimer;
  int _suggestSeq = 0;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    searchType = (args is Map ? args['type'] : null) as SearchType? ??
        SearchType.picture;
    // 其他页面跳转过来
    if (Get.parameters.keys.isNotEmpty) {
      if (Get.parameters['keyword'] != null) {
        onClickKeyword(Get.parameters['keyword']!);
      }
      if (Get.parameters['hintText'] != null) {
        hintText = Get.parameters['hintText']!;
        searchKeyWord.value = hintText;
      }
    }
  }

  // 搜索
  void submit() {
    final keyword = searchKeyWord.value.trim();
    if (keyword.isEmpty) {
      return;
    }
    SearchHistoryStorage.add(keyword);
    historyList.value = SearchHistoryStorage.list();
    // 移动光标
    searchFocusNode.unfocus();
    Get.offAndToNamed(
      '/search',
      arguments: {'type': searchType, 'keyword': keyword},
    );
  }

  // 点击热搜关键词
  void onClickKeyword(String keyword) {
    searchKeyWord.value = keyword;
    controller.value.text = keyword;
    // 移动光标
    controller.value.selection = TextSelection.fromPosition(
      TextPosition(offset: controller.value.text.length),
    );
    submit();
  }

  void onChange(value) {
    searchKeyWord.value = value;
    suggestList.value = [];
    _suggestTimer?.cancel();
    if (value == '') {
      return;
    }
    // 输入停顿后再请求联想，避免每次按键都发请求
    _suggestTimer = Timer(const Duration(milliseconds: 300), () {
      querySuggest(value);
    });
  }

  // 加载搜索联想，忽略过期请求的结果
  void querySuggest(String keyword) async {
    final seq = ++_suggestSeq;
    try {
      List<SearchSuggestion> data = [];
      if (searchType == SearchType.bangumi) {
        final titles = await SearchApi.bangumiAutocomplete(keyword: keyword);
        data = titles.map((e) => SearchSuggestion(keyword: e)).toList();
      } else {
        final items = await SearchApi.autocomplete(keyword: keyword);
        data = items
            .map((e) => SearchSuggestion(
                  keyword: e.name,
                  subtitle: e.translate.isEmpty ? null : e.translate,
                ))
            .where((e) => e.keyword.isNotEmpty)
            .toList();
      }
      if (seq == _suggestSeq && searchKeyWord.value.trim() == keyword.trim()) {
        suggestList.value = data;
      }
    } catch (e) {
      debugPrint('SearchPanelController-querySuggest $e');
    }
  }

  void onClear() {
    if (searchKeyWord.value.isNotEmpty && controller.value.text != '') {
      controller.value.clear();
      searchKeyWord.value = '';
      suggestList.value = [];
      _suggestTimer?.cancel();
    } else {
      Get.back();
    }
  }

  // 清空搜索历史
  void clearHistory() {
    SearchHistoryStorage.clear();
    historyList.value = [];
  }

  @override
  void dispose() {
    _suggestTimer?.cancel();
    super.dispose();
  }
}
