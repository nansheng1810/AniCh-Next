import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';

/// 播放器超分/放大引擎。
///
/// 除 [UpscalerEngine.none] 与专有的 [UpscalerEngine.ls1] 外，其余引擎都以
/// mpv 用户着色器（`glsl-shaders`）的形式加载并参与渲染。
enum UpscalerEngine {
  none,
  ls1,
  fsr,
  nis,
  sgsr,
  bcas,
  anime4k,
  xbr,
  sharpBilinear,
}

extension UpscalerEngineInfo on UpscalerEngine {
  String get id {
    switch (this) {
      case UpscalerEngine.none:
        return 'none';
      case UpscalerEngine.ls1:
        return 'ls1';
      case UpscalerEngine.fsr:
        return 'fsr';
      case UpscalerEngine.nis:
        return 'nis';
      case UpscalerEngine.sgsr:
        return 'sgsr';
      case UpscalerEngine.bcas:
        return 'bcas';
      case UpscalerEngine.anime4k:
        return 'anime4k';
      case UpscalerEngine.xbr:
        return 'xbr';
      case UpscalerEngine.sharpBilinear:
        return 'sharp_bilinear';
    }
  }

  String get label {
    switch (this) {
      case UpscalerEngine.none:
        return '关闭';
      case UpscalerEngine.ls1:
        return 'LS1';
      case UpscalerEngine.fsr:
        return 'FSR';
      case UpscalerEngine.nis:
        return 'NIS';
      case UpscalerEngine.sgsr:
        return 'SGSR';
      case UpscalerEngine.bcas:
        return 'BCAS';
      case UpscalerEngine.anime4k:
        return 'Anime4K';
      case UpscalerEngine.xbr:
        return 'xBR';
      case UpscalerEngine.sharpBilinear:
        return 'Sharp Bilinear';
    }
  }

  String get description {
    switch (this) {
      case UpscalerEngine.none:
        return '不加载额外着色器';
      case UpscalerEngine.ls1:
        return 'Lossless Scaling 专有算法';
      case UpscalerEngine.fsr:
        return 'AMD FidelityFX FSR1：EASU 边缘重建 + RCAS 锐化';
      case UpscalerEngine.nis:
        return 'NVIDIA Image Scaling：方向性缩放 + 自适应锐化';
      case UpscalerEngine.sgsr:
        return '高通 Snapdragon GSR：边缘方向插值';
      case UpscalerEngine.bcas:
        return 'AMD 双边对比度自适应锐化';
      case UpscalerEngine.anime4k:
        return 'Anime4K CNN：线稿修复 + 2 倍放大';
      case UpscalerEngine.xbr:
        return 'Super-xBR：像素边缘插值';
      case UpscalerEngine.sharpBilinear:
        return '锐化双线性：低开销通用放大';
    }
  }

  /// 是否可用：LS1 为闭源算法，无法以着色器形式集成
  bool get available => this != UpscalerEngine.ls1;

  /// 该引擎需要加载的着色器资源（按渲染顺序）
  List<String> get shaderAssets {
    switch (this) {
      case UpscalerEngine.fsr:
        return const ['assets/shaders/fsr/AMD_FSR1_RT.glsl'];
      case UpscalerEngine.nis:
        return const ['assets/shaders/nis/NVScaler_RT.glsl'];
      case UpscalerEngine.sgsr:
        return const ['assets/shaders/sgsr/QCOM_SGSR_RT.glsl'];
      case UpscalerEngine.bcas:
        return const ['assets/shaders/bcas/AMD_BCAS_RT.glsl'];
      case UpscalerEngine.anime4k:
        return const [
          'assets/shaders/anime4k/Anime4K_Clamp_Highlights.glsl',
          'assets/shaders/anime4k/Anime4K_Restore_CNN_M.glsl',
          'assets/shaders/anime4k/Anime4K_Upscale_CNN_x2_M.glsl',
        ];
      case UpscalerEngine.xbr:
        return const ['assets/shaders/xbr/superxbr.glsl'];
      case UpscalerEngine.sharpBilinear:
        return const ['assets/shaders/sharp_bilinear/sharp_bilinear.glsl'];
      case UpscalerEngine.none:
      case UpscalerEngine.ls1:
        return const [];
    }
  }
}

/// 负责把着色器资源释放到磁盘，并通过 mpv 属性加载它们。
class UpscalerShaderManager {
  static final Map<UpscalerEngine, List<String>> _resolved = {};

  /// 将 assets 中的着色器写入应用目录，返回可被 mpv 读取的绝对路径。
  static Future<List<String>> resolve(UpscalerEngine engine) async {
    final cached = _resolved[engine];
    if (cached != null) {
      return cached;
    }
    final support = await getApplicationSupportDirectory();
    final dir = Directory(
      '${support.path}${Platform.pathSeparator}shaders'
      '${Platform.pathSeparator}${engine.id}',
    );
    await dir.create(recursive: true);
    final paths = <String>[];
    for (final asset in engine.shaderAssets) {
      final file = File(
        '${dir.path}${Platform.pathSeparator}${asset.split('/').last}',
      );
      final data = await rootBundle.load(asset);
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
      paths.add(file.path);
    }
    _resolved[engine] = paths;
    return paths;
  }

  /// 应用引擎：先清空旧着色器，再逐个追加，避免路径分隔符在 Windows 上的歧义。
  static Future<void> apply(Player player, UpscalerEngine engine) async {
    final platform = player.platform;
    if (platform is! NativePlayer) {
      return;
    }
    var paths = const <String>[];
    if (engine.available && engine != UpscalerEngine.none) {
      try {
        paths = await resolve(engine);
      } catch (e) {
        debugPrint('释放超分着色器失败: $e');
        return;
      }
    }
    try {
      await platform.command(['change-list', 'glsl-shaders', 'clr', '']);
      for (final path in paths) {
        await platform.command(['change-list', 'glsl-shaders', 'append', path]);
      }
    } catch (e) {
      // 老版本 mpv 不支持 change-list 时回退到列表属性
      debugPrint('通过 change-list 加载失败，回退 glsl-shaders: $e');
      try {
        await platform.setProperty(
          'glsl-shaders',
          paths.join(Platform.isWindows ? ';' : ':'),
        );
      } catch (error) {
        debugPrint('加载超分引擎失败: $error');
      }
    }
  }
}
