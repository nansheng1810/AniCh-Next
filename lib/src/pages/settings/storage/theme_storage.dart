import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class ThemeSettingsStorage {
  static GetStorage box = GetStorage();
  static TextEditingController textEditingController = TextEditingController();

  static void init() {
    final storedMode = box.read('themeMode');
    themeMode(storedMode is int
        ? storedMode.clamp(0, ThemeMode.values.length - 1)
        : 0);
    isDynamic(box.read('isDynamic') ?? true);
    styleColor(box.read('styleColor') ?? 0xff3498db);
  }

  // 主题模式
  static RxInt themeMode = 0.obs;
  static void setThemeMode(int e) {
    final index = e.clamp(0, ThemeMode.values.length - 1);
    themeMode.value = index;
    box.write('themeMode', index);
    final mode = ThemeMode.values[index];
    Get.changeThemeMode(mode);
  }

  // 动态取色
  static RxBool isDynamic = true.obs;
  static void setIsDynamic(bool e) {
    isDynamic.value = e;
    box.write('isDynamic', e);
  }

  // 主题颜色
  static RxInt styleColor = 0xff3498db.obs;
  static void setStyleColor(int e) {
    styleColor.value = e;
    box.write('styleColor', e);
  }
}
