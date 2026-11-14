import 'dart:io';

import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';

late PackageInfo packageInfo;

class AppConfig {
  static RxString version = ''.obs;
  static RxString ua = ''.obs;
  // api.emmmm.eu.org 的证书已失效（TLS 握手直接失败），改回可用的 ani 域名。
  // 注意：列表类接口（/latest、/tags、/bangumi/list 等）现在要求登录态，
  // 未登录访问会返回 500 {"message":"unauthorized"}，登录后由 _ 头携带 token。
  static const baseUrl = 'https://ani.emmmm.eu.org';
  // bili-dm.emmmm.eu.org 证书与主机名不匹配（SEC_E_WRONG_PRINCIPAL），
  // 该弹幕代理已不可用，保留原值以免影响其余逻辑。
  static const bilibiliApiProxyUrl = 'https://bili-dm.emmmm.eu.org';
  static const qqVideoApiUrl = 'https://dm.video.qq.com';

  static init() async {
    packageInfo = await PackageInfo.fromPlatform();
    version(packageInfo.version);
    String platform = '';
    if (Platform.isAndroid) {
      platform = 'Android';
    } else if (Platform.isIOS) {
      platform = 'IOS';
    } else if (Platform.isFuchsia) {
      platform = 'Fuchsia';
    } else if (Platform.isLinux) {
      platform = 'Linux';
    } else if (Platform.isMacOS) {
      platform = 'MacOS';
    } else if (Platform.isWindows) {
      platform = 'Windows';
    }

    ua('${packageInfo.packageName} $platform ${packageInfo.version}');
  }
}
