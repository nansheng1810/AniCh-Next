import 'dart:io';

import 'package:dio/dio.dart';
import 'package:get_storage/get_storage.dart';
import 'package:xs/protobuf/account.pb.dart';
import 'package:xs/src/config.dart';
import 'package:xs/src/pages/settings/storage/network_storage.dart';
import 'package:xs/src/utils/network.dart';

final box = GetStorage();

class AccountUtil {
  static String token() {
    final token = box.read('token');
    if (token != null) {
      final timestamp = DateTime.now().millisecondsSinceEpoch + 1000 * 60;
      final key = token_(token: token, time: timestamp.toRadixString(16));
      return key.writeToBuffer().join(',');
    }
    return '';
  }
}

/// 统一创建 API 使用的 Dio：UA 头 + 动态 `_` 鉴权头。
///
/// 服务端的列表类接口（/latest、/tags、/bangumi/list 等）现在要求登录态，
/// 缺少 `_` 头会直接返回 500 {"message":"unauthorized"}。
/// token 每次请求重新生成（内含 60 秒有效期），因此不能在创建 Dio 时写死。
/// 同时统一设置超时，并对 GET 请求做一次自动重试，避免弱网时一直卡在加载中。
Dio createApiDio({String? baseUrl, bool withAuth = true}) {
  final timeout = Duration(seconds: NetworkStorage.timeoutSeconds);
  final retryCount = NetworkStorage.retryCount;
  final dio = Dio(BaseOptions(
      baseUrl: baseUrl ?? '',
      connectTimeout: timeout,
      receiveTimeout: timeout,
      sendTimeout: timeout,
      headers: {HttpHeaders.userAgentHeader: AppConfig.ua}));
  applyNetworkSettings(dio);
  if (withAuth) {
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      final value = AccountUtil.token();
      if (value.isNotEmpty) {
        options.headers['_'] = value;
      }
      handler.next(options);
    }));
  }
  dio.interceptors.add(InterceptorsWrapper(onError: (error, handler) async {
    // 只重试幂等的 GET 请求，次数由「网络与数据」设置决定
    final options = error.requestOptions;
    final attempts = (options.extra['apiAttempt'] as num?)?.toInt() ?? 0;
    final status = error.response?.statusCode ?? 0;
    final retryable = error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError ||
        status == 408 ||
        status == 429 ||
        status >= 500;
    if (options.method == 'GET' && retryable && attempts < retryCount) {
      options.extra['apiAttempt'] = attempts + 1;
      await Future.delayed(const Duration(milliseconds: 400));
      try {
        final response = await dio.fetch(options);
        handler.resolve(response);
        return;
      } catch (_) {
        // 重试仍失败时交回原始错误
      }
    }
    handler.next(error);
  }));
  return dio;
}
