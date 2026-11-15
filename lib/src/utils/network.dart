import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:xs/src/pages/settings/storage/network_storage.dart';

/// 把设置中的代理写入 Dio，仅桌面端生效。
void applyNetworkSettings(Dio dio) {
  if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    return;
  }
  final adapter = dio.httpClientAdapter;
  if (adapter is! IOHttpClientAdapter) {
    return;
  }
  final proxy = _proxyAddress();
  if (proxy == null) {
    return;
  }
  adapter.createHttpClient = () {
    final client = HttpClient();
    client.findProxy = (uri) => 'PROXY $proxy';
    return client;
  };
}

/// 当前是否配置了可用的自定义代理。
bool get hasCustomProxy => _proxyAddress() != null;

String? _proxyAddress() {
  if (NetworkStorage.proxyMode != 'custom') {
    return null;
  }
  var value = NetworkStorage.proxyUrl.trim();
  if (value.isEmpty) {
    return null;
  }
  if (!value.contains('://')) {
    value = 'http://$value';
  }
  final uri = Uri.tryParse(value);
  if (uri == null || uri.host.isEmpty || uri.port == 0) {
    return null;
  }
  return '${uri.host}:${uri.port}';
}
