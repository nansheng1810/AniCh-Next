import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:xs/src/pages/bangumi_vod/controller.dart';
import 'package:xs/src/pages/settings/storage/playback_markers.dart';
import 'package:xs/src/pages/settings/storage/player_storage.dart';
import 'package:xs/src/pages/settings/storage/smart_intro_storage.dart';
import 'package:xs/src/utils/app_style.dart';
import 'package:xs/src/utils/utils.dart';
import 'package:xs/src/widgets/player/controller.dart';
import 'package:xs/src/widgets/player/upscaler.dart';
import 'package:xs/src/widgets/settings/settings_card.dart';
import 'package:xs/src/widgets/settings/settings_switch.dart';

/// 播放设置面板，手机与桌面端共用，避免两份设置列表各自维护。
class PlayerSettingsView extends StatefulWidget {
  const PlayerSettingsView({required this.controller, super.key});

  final BangumiVodPageController controller;

  @override
  State<PlayerSettingsView> createState() => _PlayerSettingsViewState();
}

class _PlayerSettingsViewState extends State<PlayerSettingsView> {
  BangumiVodPageController get controller => widget.controller;

  static const List<String> _categories = ['播放', '字幕', '跳过', '画质', '更多'];

  static const Map<String, String> _hwdecLabels = {
    'auto-safe': '自动（推荐）',
    'auto': '硬解优先',
    'no': '软件解码',
  };

  static const Map<String, String> _hwdecDescriptions = {
    'auto-safe': '遇到不兼容的视频自动回退软解',
    'auto': '强制 GPU 硬件解码，兼容性较差',
    'no': '始终使用 CPU 软件解码',
  };

  static const Map<String, String> _toneMappingLabels = {
    'bt.2446a': '自动（bt.2446a）',
    'mobius': '柔和（mobius）',
    'hable': '鲜艳（hable）',
    'clip': '关闭（clip）',
  };

  static const List<List<String>> _shortcuts = [
    ['空格', '播放 / 暂停'],
    ['← →', '快退 / 快进 5 秒'],
    ['↑ ↓', '音量 +10% / -10%'],
    ['F', '进入 / 退出全屏'],
    ['M', '静音 / 恢复音量'],
    ['[ ]', '倍速 - / +'],
    ['Ctrl + ← →', '上一集 / 下一集'],
    ['P', '迷你播放器'],
    ['Ctrl + F', '打开搜索'],
    ['Esc', '退出全屏 / 返回上一页'],
  ];

  int _category = 0;

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  String _markerText(int seconds) {
    return seconds > 0 ? formatPlaybackTime(Duration(seconds: seconds)) : '未设置';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              return Center(
                child: ChoiceChip(
                  label: Text(_categories[index]),
                  selected: _category == index,
                  onSelected: (_) {
                    setState(() => _category = index);
                  },
                ),
              );
            },
          ),
        ),
        Expanded(
          child: ListView(
            padding: AppStyle.edgeInsetsV12,
            children: _categoryChildren(),
          ),
        ),
      ],
    );
  }

  List<Widget> _categoryChildren() {
    switch (_category) {
      case 0:
        return _playbackSections();
      case 1:
        return _subtitleSections();
      case 2:
        return _skipSections();
      case 3:
        return _pictureSections();
      default:
        return _moreSections();
    }
  }

  /// 播放：播放行为、播放速度、A-B 循环
  List<Widget> _playbackSections() {
    return [
      _sectionTitle('播放行为'),
      SettingsCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SettingsSwitch(
              title: '自动全屏',
              subtitle: '进入播放页后自动进入全屏',
              value: controller.autoFullscreen.value,
              onChanged: (value) {
                controller.setAutoFullscreen(value);
                _refresh();
              },
            ),
            AppStyle.divider,
            SettingsSwitch(
              title: '自动连播',
              subtitle: '当前集播完自动播放下一集',
              value: controller.autoPlayNext.value,
              onChanged: (value) {
                controller.setAutoPlayNext(value);
                _refresh();
              },
            ),
            AppStyle.divider,
            SettingsSwitch(
              title: '长按倍速',
              subtitle: '按住画面临时加速，松开恢复',
              value: controller.longPressSpeedEnabled.value,
              onChanged: (value) {
                controller.setLongPressSpeedEnabled(value);
                _refresh();
              },
            ),
            if (controller.longPressSpeedEnabled.value) ...[
              AppStyle.divider,
              ListTile(
                title: const Text('长按倍速值'),
                trailing: Text('${controller.longPressSpeedValue.value}X'),
                onTap: _showLongPressSpeedPicker,
              ),
            ],
            AppStyle.divider,
            Obx(
              () => ListTile(
                title: const Text('睡眠定时'),
                subtitle: Text(controller.sleepTimerLabel),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: _showSleepPicker,
              ),
            ),
          ],
        ),
      ),
      _sectionTitle('播放速度'),
      SettingsCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0;
                index < controller.speedsList.length;
                index++) ...[
              Obx(
                () => SettingsSwitch(
                  title: '${controller.speedsList[index]}X',
                  value: controller.playerSpeed.value ==
                      controller.speedsList[index],
                  onChanged: (e) {
                    controller.setPlaybackSpeed(controller.speedsList[index]);
                  },
                ),
              ),
              if (index != controller.speedsList.length - 1) AppStyle.divider,
            ],
          ],
        ),
      ),
      _sectionTitle('A-B 循环'),
      Obx(
        () => SettingsCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('循环区间'),
                subtitle: Text(
                  'A：${_markerText(controller.abStart.value)}    '
                  'B：${_markerText(controller.abEnd.value)}',
                ),
              ),
              AppStyle.divider,
              Padding(
                padding: const EdgeInsets.all(8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: controller.setABStart,
                      child: const Text('设置 A 点'),
                    ),
                    OutlinedButton(
                      onPressed: controller.setABEnd,
                      child: const Text('设置 B 点'),
                    ),
                    TextButton(
                      onPressed: controller.clearABLoop,
                      child: const Text('取消循环'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  /// 字幕：外挂字幕加载与样式
  List<Widget> _subtitleSections() {
    return [
      _sectionTitle('外挂字幕'),
      SettingsCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Obx(
              () => ListTile(
                title: const Text('字幕文件'),
                subtitle: Text(
                  controller.subtitlePath.value.isEmpty
                      ? '支持 SRT / ASS / SSA / VTT'
                      : controller.subtitlePath.value
                          .split(RegExp(r'[\\/]'))
                          .last,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (controller.subtitlePath.value.isNotEmpty)
                      IconButton(
                        tooltip: '清除字幕',
                        onPressed: () async {
                          await controller.clearSubtitle();
                          _refresh();
                        },
                        icon: const Icon(Icons.close, size: 20),
                      ),
                    const Icon(Icons.chevron_right, size: 20),
                  ],
                ),
                onTap: () async {
                  await controller.pickSubtitleFile();
                  _refresh();
                },
              ),
            ),
            AppStyle.divider,
            _sliderTile(
              title: '字幕字号',
              value: controller.subtitleFontSize.value,
              min: 16,
              max: 64,
              divisions: 24,
              label: '${controller.subtitleFontSize.value.round()}',
              onChanged: (value) {
                controller.setSubtitleFontSize(value);
                _refresh();
              },
            ),
            AppStyle.divider,
            _sliderTile(
              title: '字幕描边',
              value: controller.subtitleOutline.value,
              min: 0,
              max: 4,
              divisions: 8,
              label: controller.subtitleOutline.value.toStringAsFixed(1),
              onChanged: (value) {
                controller.setSubtitleOutline(value);
                _refresh();
              },
            ),
            AppStyle.divider,
            _sliderTile(
              title: '字幕底部距离',
              value: controller.subtitleBottomPadding.value,
              min: 0,
              max: 160,
              divisions: 16,
              label: '${controller.subtitleBottomPadding.value.round()}',
              onChanged: (value) {
                controller.setSubtitleBottomPadding(value);
                _refresh();
              },
            ),
            AppStyle.divider,
            SettingsSwitch(
              title: '字幕加粗',
              value: controller.subtitleBold.value,
              onChanged: (value) {
                controller.setSubtitleBold(value);
                _refresh();
              },
            ),
            AppStyle.divider,
            ListTile(
              title: const Text('字幕延迟'),
              subtitle: Text(_delayText(controller.subtitleDelay.value)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: '提前 0.5 秒',
                    onPressed: () {
                      controller.setSubtitleDelay(
                          controller.subtitleDelay.value - 0.5);
                      _refresh();
                    },
                    icon: const Icon(Icons.remove, size: 20),
                  ),
                  IconButton(
                    tooltip: '延后 0.5 秒',
                    onPressed: () {
                      controller.setSubtitleDelay(
                          controller.subtitleDelay.value + 0.5);
                      _refresh();
                    },
                    icon: const Icon(Icons.add, size: 20),
                  ),
                  IconButton(
                    tooltip: '重置',
                    onPressed: () {
                      controller.setSubtitleDelay(0);
                      _refresh();
                    },
                    icon: const Icon(Icons.restart_alt, size: 20),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ];
  }

  /// 跳过：片头片尾标记与智能学习
  List<Widget> _skipSections() {
    final markers = PlaybackMarkersStorage.read(controller.id);
    return [
      _sectionTitle('片头片尾'),
      SettingsCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SettingsSwitch(
              title: '自动跳过片头',
              subtitle: '播放到片头范围时自动跳到片头结束',
              value: PlayerSettingsStorage.skipIntro,
              onChanged: (value) {
                PlayerSettingsStorage.setSkipIntro(value);
                _refresh();
              },
            ),
            AppStyle.divider,
            SettingsSwitch(
              title: '自动跳过片尾',
              subtitle: '到达片尾时直接播放下一集',
              value: PlayerSettingsStorage.skipOutro,
              onChanged: (value) {
                PlayerSettingsStorage.setSkipOutro(value);
                _refresh();
              },
            ),
            AppStyle.divider,
            ListTile(
              title: const Text('片头结束'),
              subtitle: Text(_markerText(markers.introEnd)),
              onTap: () => _setMarker(intro: true),
            ),
            AppStyle.divider,
            ListTile(
              title: const Text('片尾开始'),
              subtitle: Text(_markerText(markers.outroStart)),
              onTap: () => _setMarker(intro: false),
            ),
            AppStyle.divider,
            Padding(
              padding: const EdgeInsets.all(8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _setMarker(intro: true),
                    icon: const Icon(Icons.flag, size: 16),
                    label: const Text('标记片头'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _setMarker(intro: false),
                    icon: const Icon(Icons.flag_outlined, size: 16),
                    label: const Text('标记片尾'),
                  ),
                  TextButton(
                    onPressed: () {
                      PlaybackMarkersStorage.clear(controller.id);
                      _refresh();
                      SmartDialog.showToast('已清除片头片尾标记');
                    },
                    child: const Text('清除标记'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      _sectionTitle('智能片头'),
      SettingsCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SettingsSwitch(
              title: '智能学习片头',
              subtitle: '记录你从片头区域快进到的位置，重复两次后自动跳过',
              value: PlayerSettingsStorage.smartSkipIntro,
              onChanged: (value) {
                PlayerSettingsStorage.setSmartSkipIntro(value);
                _refresh();
              },
            ),
            AppStyle.divider,
            ListTile(
              title: const Text('已学习片头结束'),
              subtitle: Text(
                SmartIntroStorage.learned(controller.id) > 0
                    ? _markerText(SmartIntroStorage.learned(controller.id))
                    : '暂无，多看几集后自动学习',
              ),
            ),
            AppStyle.divider,
            TextButton.icon(
              onPressed: () {
                SmartIntroStorage.clear(controller.id);
                _refresh();
                SmartDialog.showToast('已清除智能片头学习记录');
              },
              icon: const Icon(Icons.restart_alt, size: 16),
              label: const Text('清除学习记录'),
            ),
          ],
        ),
      ),
    ];
  }

  /// 画质：超分辨率、4K、超分引擎与参数、画面尺寸
  List<Widget> _pictureSections() {
    return [
      _sectionTitle('超分辨率'),
      Obx(
        () => SettingsCard(
          child: SettingsSwitch(
            title: '超分辨率',
            subtitle: 'GPU 硬件解码 + 高质量缩放',
            value: controller.superResolution.value,
            onChanged: controller.toggleSuperResolution,
          ),
        ),
      ),
      Obx(
        () => SettingsCard(
          child: SettingsSwitch(
            title: '4K 渲染',
            subtitle: '固定 3840×2160 视频输出（需要 GPU 性能）',
            value: controller.render4K.value,
            onChanged: controller.toggleRender4K,
          ),
        ),
      ),
      Obx(
        () => SettingsCard(
          child: ListTile(
            title: const Text('超分引擎'),
            subtitle: Text(
              controller.upscaler.value.description,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            trailing: Text(controller.upscaler.value.label),
            onTap: controller.showUpscalerPicker,
          ),
        ),
      ),
      Obx(
        () => controller.upscaler.value.configurable
            ? SettingsCard(
                child: ListTile(
                  title: const Text('超分参数'),
                  subtitle: Text(
                    '调整 ${controller.upscaler.value.label} 的模型与参数',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: controller.showUpscalerSettings,
                ),
              )
            : const SizedBox.shrink(),
      ),
      _sectionTitle('解码与 HDR'),
      SettingsCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Obx(
              () => ListTile(
                title: const Text('硬件解码'),
                subtitle: Text(
                  '${_hwdecLabels[controller.hwdec.value]} · '
                  '${_hwdecDescriptions[controller.hwdec.value]}',
                ),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: _showHwdecPicker,
              ),
            ),
            AppStyle.divider,
            Obx(
              () => ListTile(
                title: const Text('HDR 色调映射'),
                subtitle: Text(
                  '${_toneMappingLabels[controller.hdrToneMapping.value]} · '
                  '把 HDR 画面映射到显示器',
                ),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: _showToneMappingPicker,
              ),
            ),
          ],
        ),
      ),
      _sectionTitle('画面尺寸'),
      SettingsCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Obx(
              () => SettingsSwitch(
                title: '适应',
                value: controller.scaleMode.value == 0,
                onChanged: (e) => controller.updateScaleMode(0),
              ),
            ),
            AppStyle.divider,
            Obx(
              () => SettingsSwitch(
                title: '拉伸',
                value: controller.scaleMode.value == 1,
                onChanged: (e) => controller.updateScaleMode(1),
              ),
            ),
            AppStyle.divider,
            Obx(
              () => SettingsSwitch(
                title: '铺满',
                value: controller.scaleMode.value == 2,
                onChanged: (e) => controller.updateScaleMode(2),
              ),
            ),
            AppStyle.divider,
            Obx(
              () => SettingsSwitch(
                title: '16:9',
                value: controller.scaleMode.value == 3,
                onChanged: (e) => controller.updateScaleMode(3),
              ),
            ),
            AppStyle.divider,
            Obx(
              () => SettingsSwitch(
                title: '4:3',
                value: controller.scaleMode.value == 4,
                onChanged: (e) => controller.updateScaleMode(4),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  /// 更多：线路、投屏、日志与播放信息
  List<Widget> _moreSections() {
    return [
      _sectionTitle('线路'),
      Obx(
        () => SettingsCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SettingsSwitch(
                title: '自动选择最快线路',
                subtitle: '进入剧集时测试全部线路并自动切换',
                value: PlayerSettingsStorage.autoFastestLine,
                onChanged: (value) {
                  PlayerSettingsStorage.setAutoFastestLine(value);
                  _refresh();
                },
              ),
              AppStyle.divider,
              ListTile(
                title: const Text('手动测速'),
                subtitle: Text('当前共 ${controller.playUrls.length} 条线路'),
                onTap: () {
                  controller.testLineSpeeds();
                  SmartDialog.showToast('开始测速，可在线路列表中查看结果');
                },
              ),
            ],
          ),
        ),
      ),
      _sectionTitle('投屏'),
      SettingsCard(
        child: ListTile(
          title: const Text('投屏到电视（DLNA）'),
          subtitle: const Text('搜索局域网内的电视/盒子并推送当前视频'),
          trailing: const Icon(Icons.chevron_right),
          onTap: controller.showDlnaSheet,
        ),
      ),
      _sectionTitle('其他'),
      SettingsCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('快捷键'),
              subtitle: const Text('桌面端播放快捷键一览'),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: _showShortcuts,
            ),
            AppStyle.divider,
            ListTile(
              title: const Text('播放器日志'),
              subtitle: const Text('查看、复制或清空最近的播放日志'),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: controller.showPlayerLogs,
            ),
            AppStyle.divider,
            ListTile(
              title: const Text('播放信息'),
              subtitle: const Text('分辨率、轨道、码率等调试信息'),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: controller.showDebugInfo,
            ),
          ],
        ),
      ),
    ];
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: AppStyle.edgeInsetsA12.copyWith(top: 12),
      child: Text(title, style: Get.textTheme.titleSmall),
    );
  }

  Widget _sliderTile({
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String label,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title)),
              Text(
                label,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  String _delayText(double value) {
    if (value == 0) {
      return '无延迟';
    }
    return value > 0
        ? '延后 ${value.toStringAsFixed(1)} 秒'
        : '提前 ${value.abs().toStringAsFixed(1)} 秒';
  }

  void _setMarker({required bool intro}) {
    final position = controller.player.state.position.inSeconds;
    if (position <= 0) {
      SmartDialog.showToast('请先播放到需要标记的位置');
      return;
    }
    if (intro) {
      PlaybackMarkersStorage.setIntroEnd(controller.id, position);
      SmartDialog.showToast('片头结束已设为 ${_markerText(position)}');
    } else {
      PlaybackMarkersStorage.setOutroStart(controller.id, position);
      SmartDialog.showToast('片尾开始已设为 ${_markerText(position)}');
    }
    _refresh();
  }

  void _showHwdecPicker() {
    Utils.showBottomSheet(
      title: '硬件解码',
      child: Obx(
        () => ListView(
          children: _hwdecLabels.entries.map((entry) {
            return ListTile(
              title: Text(entry.value),
              subtitle: Text(_hwdecDescriptions[entry.key] ?? ''),
              trailing: controller.hwdec.value == entry.key
                  ? Icon(Icons.check, color: Get.theme.colorScheme.primary)
                  : null,
              onTap: () {
                controller.setHwdec(entry.key);
                Get.back();
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showToneMappingPicker() {
    Utils.showBottomSheet(
      title: 'HDR 色调映射',
      child: Obx(
        () => ListView(
          children: _toneMappingLabels.entries.map((entry) {
            return ListTile(
              title: Text(entry.value),
              trailing: controller.hdrToneMapping.value == entry.key
                  ? Icon(Icons.check, color: Get.theme.colorScheme.primary)
                  : null,
              onTap: () {
                controller.setHdrToneMapping(entry.key);
                Get.back();
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showShortcuts() {
    Utils.showBottomSheet(
      title: '播放快捷键',
      child: ListView(
        padding: AppStyle.edgeInsetsV12,
        children: _shortcuts.map((item) {
          return ListTile(
            dense: true,
            leading: SizedBox(
              width: 96,
              child: Text(
                item[0],
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
            title: Text(item[1]),
          );
        }).toList(),
      ),
    );
  }

  void _showLongPressSpeedPicker() {
    const values = [2.0, 2.5, 3.0, 4.0];
    Utils.showBottomSheet(
      title: '长按倍速值',
      child: ListView(
        children: values.map((value) {
          return ListTile(
            title: Text('${value}X'),
            trailing: controller.longPressSpeedValue.value == value
                ? Icon(Icons.check, color: Get.theme.colorScheme.primary)
                : null,
            onTap: () {
              controller.setLongPressSpeedValue(value);
              Get.back();
              _refresh();
            },
          );
        }).toList(),
      ),
    );
  }

  void _showSleepPicker() {
    Utils.showBottomSheet(
      title: '睡眠定时',
      child: ListView(
        children: [
          ListTile(
            title: const Text('关闭'),
            trailing: controller.sleepRemaining.value == 0 &&
                    !controller.sleepAtEpisodeEnd.value
                ? Icon(Icons.check, color: Get.theme.colorScheme.primary)
                : null,
            onTap: () {
              controller.cancelSleepTimer();
              Get.back();
              _refresh();
            },
          ),
          for (final minutes in [15, 30, 45, 60, 90])
            ListTile(
              title: Text('$minutes 分钟'),
              onTap: () {
                controller.setSleepTimer(Duration(minutes: minutes));
                Get.back();
                _refresh();
              },
            ),
          ListTile(
            title: const Text('本集结束后暂停'),
            trailing: controller.sleepAtEpisodeEnd.value
                ? Icon(Icons.check, color: Get.theme.colorScheme.primary)
                : null,
            onTap: () {
              controller.setSleepAtEpisodeEnd(true);
              Get.back();
              _refresh();
            },
          ),
        ],
      ),
    );
  }
}
