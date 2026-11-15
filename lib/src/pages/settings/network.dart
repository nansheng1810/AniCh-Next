import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:xs/src/pages/settings/storage/network_storage.dart';
import 'package:xs/src/utils/app_style.dart';
import 'package:xs/src/utils/data_backup.dart';
import 'package:xs/src/utils/desktop.dart';
import 'package:xs/src/utils/utils.dart';
import 'package:xs/src/widgets/drag_to_move_bar.dart';
import 'package:xs/src/widgets/settings/settings_action.dart';
import 'package:xs/src/widgets/settings/settings_card.dart';

/// 网络与数据：代理、请求超时/重试、缓存清理、备份恢复。
class NetworkSettingsPage extends StatefulWidget {
  const NetworkSettingsPage({super.key});

  @override
  State<NetworkSettingsPage> createState() => _NetworkSettingsPageState();
}

class _NetworkSettingsPageState extends State<NetworkSettingsPage> {
  int _cacheSize = 0;
  bool _cacheLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCacheSize();
  }

  Future<void> _loadCacheSize() async {
    final size = await CacheUtil.size();
    if (!mounted) {
      return;
    }
    setState(() {
      _cacheSize = size;
      _cacheLoading = false;
    });
  }

  String _sizeText(int bytes) {
    if (bytes >= 1 << 30) {
      return '${(bytes / (1 << 30)).toStringAsFixed(1)} GB';
    }
    if (bytes >= 1 << 20) {
      return '${(bytes / (1 << 20)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '$bytes B';
  }

  String get _proxyModeText {
    return NetworkStorage.proxyMode == 'custom' ? '自定义代理' : '不使用代理';
  }

  String get _proxyValueText {
    final url = NetworkStorage.proxyUrl;
    return url.isEmpty ? '未填写' : url;
  }

  void _showProxyModePicker() {
    Utils.showBottomSheet(
      title: '代理模式',
      child: ListView(
        children: [
          ListTile(
            title: const Text('不使用代理'),
            subtitle: const Text('直连，适合大多数情况'),
            trailing: NetworkStorage.proxyMode != 'custom'
                ? Icon(Icons.check, color: Get.theme.colorScheme.primary)
                : null,
            onTap: () {
              NetworkStorage.setProxyMode('none');
              setState(() {});
              Get.back();
            },
          ),
          ListTile(
            title: const Text('自定义代理'),
            subtitle: const Text('通过 HTTP 代理访问接口与下载'),
            trailing: NetworkStorage.proxyMode == 'custom'
                ? Icon(Icons.check, color: Get.theme.colorScheme.primary)
                : null,
            onTap: () {
              NetworkStorage.setProxyMode('custom');
              setState(() {});
              Get.back();
              if (NetworkStorage.proxyUrl.isEmpty) {
                _editProxy();
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _editProxy() async {
    final controller = TextEditingController(text: NetworkStorage.proxyUrl);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('代理地址'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '例如 127.0.0.1:7890',
              helperText: '支持 host:port 或 http://host:port',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (result != null) {
      NetworkStorage.setProxyUrl(result);
      if (mounted) {
        setState(() {});
      }
      SmartDialog.showToast('代理已保存，重启应用后生效');
    }
  }

  void _showOptionPicker({
    required String title,
    required List<int> options,
    required String Function(int) label,
    required int current,
    required void Function(int) onSelected,
  }) {
    Utils.showBottomSheet(
      title: title,
      child: ListView(
        children: options.map((value) {
          return ListTile(
            title: Text(label(value)),
            trailing: current == value
                ? Icon(Icons.check, color: Get.theme.colorScheme.primary)
                : null,
            onTap: () {
              onSelected(value);
              setState(() {});
              Get.back();
            },
          );
        }).toList(),
      ),
    );
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('清理缓存'),
          content: const Text('将清理临时文件与图片内存缓存，不会删除离线缓存的视频。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('清理'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    setState(() => _cacheLoading = true);
    await CacheUtil.clear();
    await _loadCacheSize();
    SmartDialog.showToast('缓存已清理');
  }

  Future<void> _exportBackup() async {
    try {
      final path = await BackupService.export();
      if (path != null) {
        SmartDialog.showToast('已导出到 $path');
      }
    } catch (e) {
      SmartDialog.showToast('导出失败：$e');
    }
  }

  Future<void> _importBackup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('导入备份'),
          content: const Text('导入会覆盖同名的本地设置与历史记录（登录状态不受影响），导入后建议重启应用。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('选择文件'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    try {
      final count = await BackupService.import();
      if (count != null) {
        SmartDialog.showToast('已导入 $count 项，重启应用后生效');
        await _loadCacheSize();
      }
    } catch (e) {
      SmartDialog.showToast('导入失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DesktopCentered(
        child: SafeArea(
          top: true,
          bottom: false,
          child: Column(
            children: [
              const CustomDragToMoveArea(
                child: SizedBox(height: 24, width: double.infinity),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 4),
                    Text('网络与数据', style: Get.textTheme.titleMedium),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: AppStyle.edgeInsetsA12,
                  children: [
                    _sectionTitle('网络代理'),
                    SettingsCard(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SettingsAction(
                            title: '代理模式',
                            value: _proxyModeText,
                            onTap: _showProxyModePicker,
                          ),
                          if (NetworkStorage.proxyMode == 'custom') ...[
                            AppStyle.divider,
                            SettingsAction(
                              title: '代理地址',
                              value: _proxyValueText,
                              onTap: _editProxy,
                            ),
                          ],
                          AppStyle.divider,
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text(
                              '代理会同时用于接口请求与离线下载，修改后需重启应用生效。',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _sectionTitle('请求'),
                    SettingsCard(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SettingsAction(
                            title: '请求超时',
                            subtitle: '连接、发送与接收的超时时间',
                            value: '${NetworkStorage.timeoutSeconds} 秒',
                            onTap: () => _showOptionPicker(
                              title: '请求超时',
                              options: NetworkStorage.timeoutOptions,
                              label: (value) => '$value 秒',
                              current: NetworkStorage.timeoutSeconds,
                              onSelected: NetworkStorage.setTimeoutSeconds,
                            ),
                          ),
                          AppStyle.divider,
                          SettingsAction(
                            title: '失败重试',
                            subtitle: '仅对 GET 请求自动重试',
                            value: '${NetworkStorage.retryCount} 次',
                            onTap: () => _showOptionPicker(
                              title: '失败重试',
                              options: NetworkStorage.retryOptions,
                              label: (value) => value == 0 ? '不重试' : '$value 次',
                              current: NetworkStorage.retryCount,
                              onSelected: NetworkStorage.setRetryCount,
                            ),
                          ),
                          AppStyle.divider,
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text(
                              '修改超时或重试次数后需重启应用生效。',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _sectionTitle('存储'),
                    SettingsCard(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SettingsAction(
                            title: '缓存占用',
                            subtitle: '临时文件与图片缓存',
                            value:
                                _cacheLoading ? '计算中…' : _sizeText(_cacheSize),
                            onTap: _cacheLoading ? null : _clearCache,
                          ),
                          AppStyle.divider,
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text(
                              '清理缓存不会删除已缓存的离线视频，也不会影响追番记录。',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _sectionTitle('数据备份'),
                    SettingsCard(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SettingsAction(
                            title: '导出设置与历史',
                            subtitle: '保存为 JSON 文件，便于迁移或恢复',
                            onTap: _exportBackup,
                          ),
                          AppStyle.divider,
                          SettingsAction(
                            title: '导入备份',
                            subtitle: '覆盖本机同名设置与历史记录',
                            onTap: _importBackup,
                          ),
                          AppStyle.divider,
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text(
                              '备份包含播放设置、追番记录、本地媒体库与播放历史，不包含登录凭证。',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: AppStyle.edgeInsetsA12.copyWith(top: 12),
      child: Text(title, style: Get.textTheme.titleSmall),
    );
  }
}
