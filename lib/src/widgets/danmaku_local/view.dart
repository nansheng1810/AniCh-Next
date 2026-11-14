import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:xs/src/pages/bangumi_vod/controller.dart';
import 'package:xs/src/utils/app_style.dart';
import 'package:xs/src/utils/utils.dart';
import 'package:xs/src/widgets/settings/settings_action.dart';
import 'package:xs/src/widgets/settings/settings_card.dart';
import 'package:xs/src/widgets/settings/settings_switch.dart';

/// 播放器内的本地弹幕增强设置：导入、导出、搜索与显示开关。
class LocalDanmakuSettings extends StatelessWidget {
  const LocalDanmakuSettings({super.key, required this.controller});

  final BangumiVodPageController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            '本地弹幕（增强）',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        SettingsCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Obx(
                () => SettingsSwitch(
                  title: '显示本地弹幕',
                  subtitle: '与当前番剧集数绑定，导入后自动合并去重',
                  value: controller.localDanmakuState.value,
                  onChanged: controller.setLocalDanmakuEnabled,
                ),
              ),
              AppStyle.divider,
              SettingsAction(
                title: '导入弹幕文件',
                subtitle: '支持 JSON / XML（哔哩哔哩、ACFun 格式）',
                onTap: controller.importLocalDanmakuFile,
              ),
              AppStyle.divider,
              SettingsAction(
                title: '导出当前弹幕',
                subtitle: '合并全部来源并去重，支持 JSON / XML',
                onTap: () => _showExportOptions(controller),
              ),
              AppStyle.divider,
              SettingsAction(
                title: '弹幕搜索',
                subtitle: '按关键词搜索并跳转到对应时间',
                onTap: controller.showDanmakuSearch,
              ),
              AppStyle.divider,
              SettingsAction(
                title: '清空本地弹幕',
                subtitle: '仅清除当前集导入的弹幕',
                onTap: () => _confirmClear(controller),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showExportOptions(BangumiVodPageController controller) {
    Utils.showBottomSheet(
      title: '导出弹幕',
      child: ListView(
        padding: AppStyle.edgeInsetsA12,
        children: [
          SettingsCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SettingsAction(
                  title: '导出为 JSON',
                  subtitle: '保留时间、类型、颜色与字号',
                  onTap: () {
                    Get.back();
                    controller.exportDanmakuFile(asXml: false);
                  },
                ),
                AppStyle.divider,
                SettingsAction(
                  title: '导出为 XML',
                  subtitle: '兼容哔哩哔哩弹幕格式，可导入其他播放器',
                  onTap: () {
                    Get.back();
                    controller.exportDanmakuFile(asXml: true);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClear(BangumiVodPageController controller) async {
    final confirm = await Utils.showAlertDialog(
      '将删除当前集所有本地导入弹幕，是否继续？',
      title: '清空本地弹幕',
      confirm: '清空',
    );
    if (confirm) {
      controller.clearLocalDanmaku();
    }
  }
}
