import 'package:get_storage/get_storage.dart';

/// 网络与数据相关设置。
class NetworkStorage {
  static GetStorage box = GetStorage();

  // 代理模式：none 不使用、custom 自定义
  static String get proxyMode {
    final value = box.read('networkProxyMode') as String?;
    return value == 'custom' ? 'custom' : 'none';
  }

  static void setProxyMode(String value) {
    box.write('networkProxyMode', value);
  }

  // 自定义代理地址，支持 host:port 或 http://host:port
  static String get proxyUrl {
    return box.read('networkProxyUrl') as String? ?? '';
  }

  static void setProxyUrl(String value) {
    box.write('networkProxyUrl', value.trim());
  }

  // 请求超时（秒）
  static const List<int> timeoutOptions = [10, 20, 30, 60];

  static int get timeoutSeconds {
    final value = (box.read('networkTimeout') as num?)?.toInt() ?? 10;
    return timeoutOptions.contains(value) ? value : 10;
  }

  static void setTimeoutSeconds(int value) {
    box.write('networkTimeout', value);
  }

  // GET 失败重试次数
  static const List<int> retryOptions = [0, 1, 2, 3];

  static int get retryCount {
    final value = (box.read('networkRetry') as num?)?.toInt() ?? 1;
    return retryOptions.contains(value) ? value : 1;
  }

  static void setRetryCount(int value) {
    box.write('networkRetry', value);
  }
}
