import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:xs/src/config.dart';
import 'package:xs/protobuf/account.pb.dart';
import 'package:xs/src/utils/account.dart';

/// 账号类接口不使用本地 token：带过期/无效的 `_` 头会被服务端直接拒绝（402），
/// 登录、注册、改密本身只需要表单里的凭证。/init 需要鉴权，单独显式传 `_`。
final api = createApiDio(baseUrl: AppConfig.baseUrl, withAuth: false);
final box = GetStorage();

class AccountApi {
  // 登录
  static Future<Response> login(
      {required String user, required String password}) async {
    const url = '/login';
    login_request_ userData = login_request_(user: user, password: password);
    // 成功返回 protobuf 字节，失败返回 JSON 信封；交给控制器按字节判断
    final response = await api.post(url,
        data: {'data': userData.writeToBuffer().join(',')},
        options: Options(
            responseType: ResponseType.bytes,
            contentType: 'application/x-www-form-urlencoded'));
    return response;
  }

  // 获取验证码
  static Future<Response> getCode({required String email}) async {
    const url = '/code';
    final response = await api.post(url, data: {'email': email});
    return response;
  }

  // 修改密码
  static Future<Response> changePassword(
      {required String email,
      required String code,
      required String password}) async {
    const url = '/change_password';
    change_password_request_ userData =
        change_password_request_(email: email, code: code, password: password);
    final response = await api.post(url,
        data: {'data': userData.writeToBuffer().join(',')},
        options: Options(
            responseType: ResponseType.bytes,
            contentType: 'application/x-www-form-urlencoded'));
    return response;
  }

  // 检测邮箱可用性
  static Future<Response> checkEmail({required String email}) async {
    const url = '/user/check';
    final response = await api.post(url, data: {'email': email});
    return response;
  }

  // 检测用户名可用性
  static Future<Response> checkName({required String name}) async {
    const url = '/user/check';
    final response = await api.post(url, data: {'name': name});
    return response;
  }

  // 注册
  static Future<Response> register(
      {required String email,
      required String code,
      required String name,
      required String password}) async {
    const url = '/register';
    register_request_ userData = register_request_(
        email: email, code: code, name: name, password: password);
    final response = await api.post(url,
        data: {'data': userData.writeToBuffer().join(',')},
        options: Options(
            responseType: ResponseType.bytes,
            contentType: 'application/x-www-form-urlencoded'));
    return response;
  }

  // 获取用户数据
  static void init() async {
    try {
      const url = '/init';
      final response = await api.get(url,
          options: Options(
              responseType: ResponseType.bytes,
              headers: {'_': AccountUtil.token()}));
      final bytes = response.data as List<int>;
      Object? decoded;
      try {
        decoded = jsonDecode(utf8.decode(bytes));
      } catch (_) {
        decoded = init_.fromBuffer(bytes).toProto3Json();
      }
      final body = decoded is Map ? decoded['body'] : null;
      if (body is Map && body['user'] != null) {
        box.write('user', Map<String, dynamic>.from(body)['user']);
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }
}
