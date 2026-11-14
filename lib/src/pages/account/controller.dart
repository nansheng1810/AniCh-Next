import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart' hide Response;
import 'package:get_storage/get_storage.dart';
import 'package:xs/protobuf/account.pb.dart';
import 'package:xs/src/apis/account.dart';

/// 账号接口的响应有两种格式：
/// - 失败：JSON 信封 `{"error": bool, "message": string, "body": {...}}`
/// - 成功：protobuf 消息（login_ / register_ / change_password_）的原始字节
///
/// 这里按字节处理：先尝试 UTF-8 + JSON，失败再交给调用方按 protobuf 解码。
Map<String, dynamic>? _readEnvelope(Response response,
    {Map<String, dynamic>? Function(List<int> bytes)? fromProto}) {
  final data = response.data;
  if (data is Map) return Map<String, dynamic>.from(data);
  final bytes =
      data is String ? utf8.encode(data) : (data is List<int> ? data : null);
  if (bytes == null) return null;
  try {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } catch (_) {
    // 不是 JSON 信封，继续按 protobuf 解码
  }
  if (fromProto != null) {
    try {
      return fromProto(bytes);
    } catch (e) {
      debugPrint(e.toString());
    }
  }
  return null;
}

/// 优先使用服务端返回的 message，便于把「验证码不正确」等原因透出到界面。
String _messageOf(Map<String, dynamic>? data, String fallback) {
  final message = data?['message'];
  if (message is String && message.trim().isNotEmpty) return message;
  return fallback;
}

Map<String, dynamic> _bodyOf(Map<String, dynamic>? data) {
  final body = data?['body'];
  if (body is Map) return Map<String, dynamic>.from(body);
  return <String, dynamic>{};
}

class LoginController extends GetxController with StateMixin {
  final box = GetStorage();
  final user = ''.obs;
  final password = ''.obs;
  final message = ''.obs;
  SmartDialogController smartDialogController = SmartDialogController();

  Future<bool> login() async {
    message('');
    SmartDialog.showLoading();
    change(null, status: RxStatus.loading());
    try {
      final response =
          await AccountApi.login(user: user.value, password: password.value);
      final data = _readEnvelope(response,
          fromProto: (bytes) =>
              login_.fromBuffer(bytes).toProto3Json() as Map<String, dynamic>);
      if (data == null) {
        message('服务器返回数据异常');
      } else if (response.statusCode != 200 || data['error'] == true) {
        message(_messageOf(data, '账号或密码错误，请重试'));
      } else {
        final body = _bodyOf(data);
        box.write('token', body['token']);
        box.write('user', body['user']);
        change(data, status: RxStatus.success());
        return true;
      }
    } catch (e) {
      debugPrint(e.toString());
      message('网络异常，请稍后重试');
    } finally {
      SmartDialog.dismiss();
      if (message.value.isNotEmpty) {
        change(null, status: RxStatus.error(message.value));
      }
    }
    return false;
  }
}

class RegisterController extends GetxController with StateMixin {
  final box = GetStorage();
  final email = ''.obs;
  final code = ''.obs;
  final name = ''.obs;
  final password = ''.obs;
  final message = ''.obs;

  Future<bool> getCode() async {
    change(false, status: RxStatus.loading());
    try {
      final response = await AccountApi.getCode(email: email.value);
      final data = _readEnvelope(response);
      if (response.statusCode != 200 || data == null || data['error'] == true) {
        message(_messageOf(data, '验证码获取失败，请重试'));
        change(false, status: RxStatus.error(message.value));
        return false;
      }
      change(true, status: RxStatus.success());
      return true;
    } catch (e) {
      debugPrint(e.toString());
    }
    change(false, status: RxStatus.error('error'));
    return false;
  }

  Future<bool> checkEmail() async {
    change(false, status: RxStatus.loading());
    try {
      final response = await AccountApi.checkEmail(email: email.value);
      final data = _readEnvelope(response);
      final exist = _bodyOf(data)['exist'];
      if (response.statusCode == 200 && data != null && exist is bool) {
        change(exist, status: RxStatus.success());
        return exist;
      }
    } catch (e) {
      debugPrint(e.toString());
    }
    change(false, status: RxStatus.error('error'));
    return false;
  }

  Future<bool> checkName() async {
    change(false, status: RxStatus.loading());
    try {
      final response = await AccountApi.checkName(name: name.value);
      final data = _readEnvelope(response);
      final exist = _bodyOf(data)['exist'];
      if (response.statusCode == 200 && data != null && exist is bool) {
        change(exist, status: RxStatus.success());
        return exist;
      }
    } catch (e) {
      debugPrint(e.toString());
    }
    change(false, status: RxStatus.error('error'));
    return false;
  }

  Future<bool> register() async {
    message('');
    SmartDialog.showLoading();
    change(false, status: RxStatus.loading());
    try {
      final response = await AccountApi.register(
          email: email.value,
          code: code.value,
          name: name.value,
          password: password.value);
      final data = _readEnvelope(response,
          fromProto: (bytes) =>
              register_.fromBuffer(bytes).toProto3Json()
                  as Map<String, dynamic>);
      if (data == null) {
        message('服务器返回数据异常');
      } else if (response.statusCode != 200 || data['error'] == true) {
        message(_messageOf(data, '注册失败，请重试'));
      } else {
        final body = _bodyOf(data);
        box.write('token', body['token']);
        box.write('user', body['user']);
        change(true, status: RxStatus.success());
        return true;
      }
    } catch (e) {
      debugPrint(e.toString());
      message('网络异常，请稍后重试');
    } finally {
      SmartDialog.dismiss();
      if (message.value.isNotEmpty) {
        change(false, status: RxStatus.error(message.value));
      }
    }
    return false;
  }
}

class ChangePasswordController extends GetxController with StateMixin {
  final box = GetStorage();
  final email = ''.obs;
  final code = ''.obs;
  final password = ''.obs;
  final message = ''.obs;

  Future<bool> getCode() async {
    change(false, status: RxStatus.loading());
    try {
      final response = await AccountApi.getCode(email: email.value);
      final data = _readEnvelope(response);
      if (response.statusCode != 200 || data == null || data['error'] == true) {
        message(_messageOf(data, '验证码获取失败，请重试'));
        change(false, status: RxStatus.error(message.value));
        return false;
      }
      change(true, status: RxStatus.success());
      return true;
    } catch (e) {
      debugPrint(e.toString());
    }
    change(false, status: RxStatus.error('error'));
    return false;
  }

  Future<bool> changePassword() async {
    message('');
    SmartDialog.showLoading();
    change(false, status: RxStatus.loading());
    try {
      final response = await AccountApi.changePassword(
          email: email.value, code: code.value, password: password.value);
      final data = _readEnvelope(response,
          fromProto: (bytes) =>
              change_password_.fromBuffer(bytes).toProto3Json()
                  as Map<String, dynamic>);
      if (data == null) {
        message('服务器返回数据异常');
      } else if (response.statusCode != 200 || data['error'] == true) {
        message(_messageOf(data, '密码修改失败，请重试'));
      } else {
        final body = _bodyOf(data);
        box.write('token', body['token']);
        box.write('user', body['user']);
        change(true, status: RxStatus.success());
        return true;
      }
    } catch (e) {
      debugPrint(e.toString());
      message('网络异常，请稍后重试');
    } finally {
      SmartDialog.dismiss();
      if (message.value.isNotEmpty) {
        change(false, status: RxStatus.error(message.value));
      }
    }
    return false;
  }
}
