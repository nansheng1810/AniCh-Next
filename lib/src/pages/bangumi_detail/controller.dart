import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:xs/protobuf/bangumi.pb.dart';
import 'package:xs/src/apis/bangumi.dart';
import 'package:xs/src/pages/bangumi_detail/models/bangumi_detail_model.dart';
import 'package:xs/src/utils/account.dart';
import 'package:xs/src/utils/app_style.dart';
import 'package:xs/src/utils/utils.dart';
import 'package:xs/src/widgets/settings/settings_action.dart';
import 'package:xs/src/widgets/settings/settings_card.dart';
import 'package:xs/src/widgets/subordinate_scroll_controller.dart';

class BangumiDetailController extends GetxController
    with
        StateMixin<BangumiDetailModel>,
        GetTickerProviderStateMixin,
        DetailTabScrollMixin {
  // 导航栏
  final List<Tab> tabs = <Tab>[
    const Tab(
      child: Align(
        alignment: Alignment.center,
        child: Text('详情'),
      ),
    ),
    const Tab(
      child: Align(
        alignment: Alignment.center,
        child: Text('剧集'),
      ),
    ),
    const Tab(
      child: Align(
        alignment: Alignment.center,
        child: Text('角色'),
      ),
    ),
    const Tab(
      child: Align(
        alignment: Alignment.center,
        child: Text('制作人员'),
      ),
    ),
    const Tab(
      child: Align(
        alignment: Alignment.center,
        child: Text('推荐'),
      ),
    ),
  ];

  late TabController tabController;
  late final AnimationController animationController;
  RxInt id = 0.obs;
  RxInt tabIndex = 0.obs;
  List<BangumiDetailModel> result = [];
  RxBool collectStatusLoading = true.obs;
  RxBool collectStatus = false.obs;
  RxInt collectType = 999.obs;
  List collectTypeList = ['wish', 'watch', 'watched'];

  @override
  void onInit() {
    // 路由参数可能已切换（例如从播放页返回），做一次兜底解析
    id(int.tryParse('${Get.arguments is Map ? Get.arguments['id'] : ''}') ??
        int.tryParse('${Get.parameters['id']}') ??
        0);
    get();
    getCollectStatus();
    super.onInit();

    tabController =
        TabController(vsync: this, length: tabs.length, initialIndex: 0);
    tabController.addListener(() {
      tabIndex(tabController.index);
    });

    animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  // 查询数据
  BangumiDetailModel? find(id) {
    try {
      return result.where((i) => i.id == id.value).first;
    } catch (e) {
      return null;
    }
  }

  // 刷新详情与收藏状态（返回页面时静默刷新，不闪加载态）
  Future<bool> reload() async {
    await get(showLoading: false);
    getCollectStatus();
    return true;
  }

  // 获取数据
  Future<void> get({bool showLoading = true}) async {
    try {
      debugPrint('BangumiDetailController-get');
      if (showLoading) {
        change(null, status: RxStatus.loading());
      }
      final response = await BangumiApi.getBangumiDetail(id: id.value);
      if (response.statusCode == 200) {
        final data = BangumiDetailModel.fromJson(response.data);
        final old = find(id.value);
        if (old == null) {
          result.add(data);
        } else {
          result.remove(old);
          result.add(data);
        }
        change(data, status: RxStatus.success());
      } else {
        throw Error();
      }
    } catch (e) {
      debugPrint(e.toString());
      change(null, status: RxStatus.error('error'));
    }
  }

  // 收藏状态
  void getCollectStatus() async {
    try {
      final token = AccountUtil.token();
      if (token.isEmpty) {
        return;
      }
      collectStatusLoading(true);
      debugPrint('BangumiDetailController-getCollectStatus');
      final response = await BangumiApi.collectStatus(id: id.value);
      if (response.statusCode == 200) {
        final data = response.data['data'];
        final type = response.data['type'] ?? 999;
        collectStatus(data);
        collectType(type);
        collectStatusLoading(false);
      } else {
        throw Error();
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  // 收藏状态
  void changeCollect(index) async {
    try {
      final token = AccountUtil.token();
      if (token.isEmpty) {
        return;
      }
      collectStatusLoading(true);
      debugPrint('BangumiDetailController-changeCollect');
      debugPrint('$id ${collectTypeList[index]}');
      final response = await BangumiApi.changeCollect(
          id: id.value, type: collectTypeList[index]);
      if (response.statusCode == 200) {
        final data = response.data['data'];
        collectStatus(data);
        collectType(index);
        collectStatusLoading(false);
        SmartDialog.showToast('操作成功');
      } else {
        throw Error();
      }
    } catch (e) {
      SmartDialog.showToast('操作失败，请重试');
      debugPrint(e.toString());
    }
  }

  // 取消收藏
  void cancelCollect() async {
    try {
      final token = AccountUtil.token();
      if (token.isEmpty) {
        return;
      }
      collectStatusLoading(true);
      debugPrint('BangumiDetailController-cancelCollect');
      final response = await BangumiApi.cancelCollect(id: id.value);
      if (response.statusCode == 200) {
        // final data = response.data['data'];
        // final type = response.data['type'] ?? 999;
        collectStatus(false);
        collectType(999);
        collectStatusLoading(false);
        SmartDialog.showToast('取消成功');
      } else {
        throw Error();
      }
    } catch (e) {
      SmartDialog.showToast('取消失败');
      debugPrint(e.toString());
    }
  }

  void showCollectSheet() {
    Utils.showBottomSheet(
        title: '收藏到...',
        maxHeight: 250,
        child: Container(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              SettingsCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SettingsAction(
                      rightIcon: false,
                      title: '我想看的',
                      onTap: () {
                        Get.back();
                        changeCollect(0);
                      },
                    ),
                    AppStyle.divider,
                    SettingsAction(
                      rightIcon: false,
                      title: '我在看的',
                      onTap: () {
                        Get.back();
                        changeCollect(1);
                      },
                    ),
                    AppStyle.divider,
                    SettingsAction(
                      rightIcon: false,
                      title: '我看过的',
                      onTap: () {
                        Get.back();
                        changeCollect(2);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ));
  }

  void showMarkSheet() {
    Utils.showBottomSheet(
        title: '标记为...',
        maxHeight: 250,
        child: Container(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              SettingsCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Offstage(
                      offstage: collectType.value == 0,
                      child: Column(
                        children: [
                          SettingsAction(
                            rightIcon: false,
                            title: '我想看的',
                            onTap: () {
                              Get.back();
                              changeCollect(0);
                            },
                          ),
                          AppStyle.divider,
                        ],
                      ),
                    ),
                    Offstage(
                      offstage: collectType.value == 1,
                      child: Column(
                        children: [
                          SettingsAction(
                            rightIcon: false,
                            title: '我在看的',
                            onTap: () {
                              Get.back();
                              changeCollect(1);
                            },
                          ),
                          AppStyle.divider,
                        ],
                      ),
                    ),
                    Offstage(
                      offstage: collectType.value == 2,
                      child: Column(
                        children: [
                          SettingsAction(
                            rightIcon: false,
                            title: '我看过的',
                            onTap: () {
                              Get.back();
                              changeCollect(2);
                            },
                          ),
                          AppStyle.divider,
                        ],
                      ),
                    ),
                    Offstage(
                      offstage: false,
                      child: Column(
                        children: [
                          SettingsAction(
                            rightIcon: false,
                            title: '取消收藏',
                            color: Colors.red,
                            onTap: () {
                              Get.back();
                              cancelCollect();
                            },
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ));
  }

  @override
  void dispose() {
    tabController.dispose();
    disposeTabScrollController();
    super.dispose();
  }
}

class BangumiDetailEpisodesController extends GetxController
    with StateMixin<List<bangumi_episodes_data_>>, DetailTabScrollMixin {
  List<bangumi_episodes_data_> result = [];
  RxBool isLoading = false.obs;
  int id = 0;

  @override
  void onInit() {
    id = int.tryParse('${Get.arguments is Map ? Get.arguments['id'] : ''}') ??
        int.tryParse('${Get.parameters['id']}') ??
        0;
    get();
    super.onInit();
  }

  // 获取数据
  void get() async {
    try {
      debugPrint('BangumiDetailEpisodesController-get');
      change(result, status: RxStatus.loading());
      final response = await BangumiApi.getBangumiEpisodes(id: id);
      final data = bangumi_episodes_.fromBuffer(response.data);
      result.addAll(data.data);
      result.sort((a, b) => a.sort.compareTo(b.sort));
      change(result, status: RxStatus.success());
    } catch (e) {
      debugPrint(e.toString());
      change(null, status: RxStatus.error('error'));
    }
  }

  // 加载更多
  // void more() async {
  //   try {
  //     debugPrint('BangumiDetailEpisodesController-more');
  //     isLoading(true);
  //     // final response = await BangumiApi.getBangumiList(skip: result.last.id);
  //     // final data = bangumi_list_.fromBuffer(response.data);
  //     // result.addAll(data.data);
  //     change(result, status: RxStatus.success());
  //   } catch (e) {
  //     debugPrint(e.toString());
  //   }
  //   isLoading(false);
  // }

  // 刷新
  Future<bool> reload() async {
    try {
      debugPrint('BangumiDetailEpisodesController-reload');
      final response = await BangumiApi.getBangumiEpisodes(id: id);
      final data = bangumi_episodes_.fromBuffer(response.data);
      result.clear();
      result.addAll(data.data);
      result.sort((a, b) => a.sort.compareTo(b.sort));
      change(result, status: RxStatus.success());
    } catch (e) {
      debugPrint(e.toString());
    }
    return true;
  }
}

class BangumiDetailRelatedController extends GetxController
    with StateMixin<List<bangumi_related_data_>>, DetailTabScrollMixin {
  List<bangumi_related_data_> result = [];
  RxBool isLoading = false.obs;
  RxInt id = 0.obs;

  @override
  void onInit() {
    id(int.tryParse('${Get.arguments is Map ? Get.arguments['id'] : ''}') ??
        int.tryParse('${Get.parameters['id']}') ??
        0);
    get();
    super.onInit();
  }

  // 获取数据
  void get() async {
    try {
      debugPrint('BangumiDetailRelatedController-get');
      change(result, status: RxStatus.loading());
      final response = await BangumiApi.getBangumiRelated(id: id.value);
      final data = bangumi_related_.fromBuffer(response.data);
      result.addAll(data.data);
      change(result, status: RxStatus.success());
    } catch (e) {
      debugPrint(e.toString());
      change(null, status: RxStatus.error('error'));
    }
  }

  // 加载更多
  // void more() async {
  //   try {
  //     debugPrint('BangumiDetailRelatedController-more');
  //     isLoading(true);
  //     // final response = await BangumiApi.getBangumiList(skip: result.last.id);
  //     // final data = bangumi_list_.fromBuffer(response.data);
  //     // result.addAll(data.data);
  //     change(result, status: RxStatus.success());
  //   } catch (e) {
  //     debugPrint(e.toString());
  //   }
  //   isLoading(false);
  // }

  // 刷新
  Future<bool> reload() async {
    try {
      debugPrint('BangumiDetailRelatedController-reload');
      final response = await BangumiApi.getBangumiRelated(id: id.value);
      final data = bangumi_related_.fromBuffer(response.data);
      result.clear();
      result.addAll(data.data);
      change(result, status: RxStatus.success());
    } catch (e) {
      debugPrint(e.toString());
    }
    return true;
  }
}

class BangumiDetailCharactersController extends GetxController
    with StateMixin<List<bangumi_characters_data_>>, DetailTabScrollMixin {
  List<bangumi_characters_data_> result = [];
  RxBool isLoading = false.obs;
  int id = 0;

  @override
  void onInit() {
    id = int.tryParse('${Get.arguments is Map ? Get.arguments['id'] : ''}') ??
        int.tryParse('${Get.parameters['id']}') ??
        0;
    get();
    super.onInit();
  }

  // 获取数据
  void get() async {
    try {
      debugPrint('BangumiDetailCharactersController-get');
      change(null, status: RxStatus.loading());
      final response = await BangumiApi.getCharacters(id: id);
      final data = bangumi_characters_.fromBuffer(response.data);
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
      debugPrint('BangumiDetailCharactersController-reload');
      final response = await BangumiApi.getCharacters(id: id);
      final data = bangumi_characters_.fromBuffer(response.data);
      result.clear();
      result.addAll(data.data);
      change(result, status: RxStatus.success());
    } catch (e) {
      debugPrint(e.toString());
    }
    return true;
  }
}

class BangumiDetailPersonsController extends GetxController
    with StateMixin<List<bangumi_persons_data_>>, DetailTabScrollMixin {
  List<bangumi_persons_data_> result = [];
  RxBool isLoading = false.obs;
  int id = 0;

  @override
  void onInit() {
    id = int.tryParse('${Get.arguments is Map ? Get.arguments['id'] : ''}') ??
        int.tryParse('${Get.parameters['id']}') ??
        0;
    get();
    super.onInit();
  }

  // 获取数据
  void get() async {
    try {
      debugPrint('BangumiDetailPersonsController-get');
      change(null, status: RxStatus.loading());
      final response = await BangumiApi.getPersons(id: id);
      final data = bangumi_persons_.fromBuffer(response.data);
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
      debugPrint('BangumiDetailPersonsController-reload');
      final response = await BangumiApi.getPersons(id: id);
      final data = bangumi_persons_.fromBuffer(response.data);
      result.clear();
      result.addAll(data.data);
      change(result, status: RxStatus.success());
    } catch (e) {
      debugPrint(e.toString());
    }
    return true;
  }
}
