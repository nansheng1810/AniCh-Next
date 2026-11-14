import 'dart:convert';
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
        return 'Anime4K v4：修复 / 放大模型自由组合';
      case UpscalerEngine.xbr:
        return 'Super-xBR：像素边缘插值';
      case UpscalerEngine.sharpBilinear:
        return '锐化双线性：低开销通用放大';
    }
  }

  /// 是否可用：LS1 为闭源算法，无法以着色器形式集成
  bool get available => this != UpscalerEngine.ls1;

  /// 是否提供可调参数
  bool get configurable =>
      this == UpscalerEngine.anime4k ||
      upscalerParamSpecs[this]?.isNotEmpty == true;

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
        return anime4kShaderAssets(const {});
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

/// 着色器数值参数定义（对应 `//!PARAM` / `#define`）。
class UpscalerParamSpec {
  const UpscalerParamSpec({
    required this.key,
    required this.label,
    required this.min,
    required this.max,
    required this.defaultValue,
    this.step = 0.05,
    this.isDefine = false,
    this.decimals = 2,
  });

  final String key;
  final String label;
  final double min;
  final double max;
  final double defaultValue;
  final double step;

  /// 是否为 `//!TYPE DEFINE` 的整数开关
  final bool isDefine;
  final int decimals;

  String format(double value) => isDefine
      ? value.round().toString()
      : value.toStringAsFixed(decimals).replaceFirst(RegExp(r'\.?0+$'), '');

  int? get divisions {
    if (step <= 0) {
      return null;
    }
    final count = ((max - min) / step).round();
    return count > 0 ? count : null;
  }
}

/// 各引擎的可调参数，键为 mpv 着色器中的参数名。
const Map<UpscalerEngine, List<UpscalerParamSpec>> upscalerParamSpecs = {
  UpscalerEngine.fsr: [
    UpscalerParamSpec(
      key: 'SHARP',
      label: 'RCAS 锐化',
      min: 0,
      max: 4,
      defaultValue: 0.2,
    ),
    UpscalerParamSpec(
      key: 'NDS',
      label: '非线性降采样（NDS）',
      min: 0,
      max: 1,
      defaultValue: 1,
      step: 1,
      isDefine: true,
    ),
  ],
  UpscalerEngine.nis: [
    UpscalerParamSpec(
      key: 'SHARP',
      label: '锐化强度',
      min: 0,
      max: 1,
      defaultValue: 0.5,
    ),
    UpscalerParamSpec(
      key: 'NIS_HDR_MODE',
      label: 'HDR 模式（0 关闭 / 1 PQ / 2 sRGB）',
      min: 0,
      max: 2,
      defaultValue: 0,
      step: 1,
      isDefine: true,
      decimals: 0,
    ),
  ],
  UpscalerEngine.sgsr: [
    UpscalerParamSpec(
      key: 'SHARP',
      label: '锐化强度',
      min: 1,
      max: 8,
      defaultValue: 2,
      step: 0.1,
    ),
    UpscalerParamSpec(
      key: 'ET',
      label: '边缘阈值',
      min: 0,
      max: 32,
      defaultValue: 8,
      step: 0.5,
    ),
  ],
  UpscalerEngine.bcas: [
    UpscalerParamSpec(
      key: 'STR',
      label: '锐化强度',
      min: 0,
      max: 1,
      defaultValue: 0.5,
    ),
    UpscalerParamSpec(
      key: 'SIGMA',
      label: '双边平滑',
      min: 0,
      max: 0.5,
      defaultValue: 0.1,
    ),
  ],
  UpscalerEngine.sharpBilinear: [
    UpscalerParamSpec(
      key: 'SHARPNESS',
      label: '锐度（1.0 为普通双线性）',
      min: 1,
      max: 3,
      defaultValue: 1.6,
    ),
  ],
};

/// Anime4K 组合选项。
class UpscalerChoiceSpec {
  const UpscalerChoiceSpec({
    required this.key,
    required this.label,
    required this.options,
  });

  final String key;
  final String label;
  final Map<String, String> options;
}

const Map<String, String> anime4kDefaults = {
  'preset': 'balanced',
  'restore': 'cnn_m',
  'upscale': 'cnn_m',
  'clamp': '1',
  'denoise': 'off',
  'deblur': 'off',
  'thin': 'off',
  'darken': 'off',
  'autoDownscale': 'off',
};

/// 预设只覆盖画质相关项，其余预处理统一关闭。
const Map<String, Map<String, String>> anime4kPresets = {
  'fast': {'restore': 'cnn_s', 'upscale': 'cnn_s'},
  'balanced': {'restore': 'cnn_m', 'upscale': 'cnn_m'},
  'hq': {'restore': 'cnn_l', 'upscale': 'cnn_l'},
  'ultimate': {'restore': 'cnn_vl', 'upscale': 'cnn_vl'},
  'gan': {'restore': 'gan_ul', 'upscale': 'gan_x2_m'},
  'denoise': {'restore': 'off', 'upscale': 'denoise_m', 'denoise': 'median'},
  'deblur': {'restore': 'off', 'upscale': 'dtd_x2', 'deblur': 'dog'},
  '3d': {'restore': 'cnn_m', 'upscale': '3d_aa'},
};

const List<UpscalerChoiceSpec> anime4kChoiceSpecs = [
  UpscalerChoiceSpec(key: 'preset', label: '画质预设', options: {
    'fast': '极速 S',
    'balanced': '均衡 M',
    'hq': '高质量 L',
    'ultimate': '极致 VL',
    'gan': 'GAN 画质',
    'denoise': '去噪优先',
    'deblur': '去模糊优先',
    '3d': '3D 动画',
    'custom': '自定义',
  }),
  UpscalerChoiceSpec(key: 'restore', label: '线稿修复', options: {
    'off': '关闭',
    'cnn_s': 'CNN S',
    'cnn_m': 'CNN M',
    'cnn_l': 'CNN L',
    'cnn_vl': 'CNN VL',
    'cnn_ul': 'CNN UL',
    'soft_s': 'Soft S',
    'soft_m': 'Soft M',
    'soft_l': 'Soft L',
    'soft_vl': 'Soft VL',
    'soft_ul': 'Soft UL',
    'gan_ul': 'GAN UL',
    'gan_uul': 'GAN UUL',
  }),
  UpscalerChoiceSpec(key: 'upscale', label: '放大模型', options: {
    'off': '关闭',
    'cnn_s': 'CNN x2 S',
    'cnn_m': 'CNN x2 M',
    'cnn_l': 'CNN x2 L',
    'cnn_vl': 'CNN x2 VL',
    'cnn_ul': 'CNN x2 UL',
    'denoise_s': '去噪 CNN x2 S',
    'denoise_m': '去噪 CNN x2 M',
    'denoise_l': '去噪 CNN x2 L',
    'denoise_vl': '去噪 CNN x2 VL',
    'denoise_ul': '去噪 CNN x2 UL',
    'gan_x2_s': 'GAN x2 S',
    'gan_x2_m': 'GAN x2 M',
    'gan_x3_l': 'GAN x3 L',
    'gan_x3_vl': 'GAN x3 VL',
    'gan_x4_ul': 'GAN x4 UL',
    'gan_x4_uul': 'GAN x4 UUL',
    'dog_x2': 'DoG x2',
    'dtd_x2': 'DTD x2',
    'original_x2': 'Original x2',
    '3d': '3D 图形 x2',
    '3d_aa': '3D 抗锯齿 x2',
  }),
  UpscalerChoiceSpec(key: 'denoise', label: '去噪预处理', options: {
    'off': '关闭',
    'mean': '双边均值',
    'median': '双边中值',
    'mode': '双边众数',
  }),
  UpscalerChoiceSpec(key: 'deblur', label: '去模糊预处理', options: {
    'off': '关闭',
    'dog': 'DoG',
    'original': 'Original',
  }),
  UpscalerChoiceSpec(key: 'thin', label: '线条细化', options: {
    'off': '关闭',
    'fast': 'Fast',
    'veryfast': 'Very Fast',
    'hq': 'HQ',
  }),
  UpscalerChoiceSpec(key: 'darken', label: '线条压暗', options: {
    'off': '关闭',
    'fast': 'Fast',
    'veryfast': 'Very Fast',
    'hq': 'HQ',
  }),
  UpscalerChoiceSpec(key: 'autoDownscale', label: '自动降采样', options: {
    'off': '关闭',
    'x2': 'x2',
    'x4': 'x4',
  }),
];

const Map<String, String> _restoreFiles = {
  'cnn_s': 'Anime4K_Restore_CNN_S.glsl',
  'cnn_m': 'Anime4K_Restore_CNN_M.glsl',
  'cnn_l': 'Anime4K_Restore_CNN_L.glsl',
  'cnn_vl': 'Anime4K_Restore_CNN_VL.glsl',
  'cnn_ul': 'Anime4K_Restore_CNN_UL.glsl',
  'soft_s': 'Anime4K_Restore_CNN_Soft_S.glsl',
  'soft_m': 'Anime4K_Restore_CNN_Soft_M.glsl',
  'soft_l': 'Anime4K_Restore_CNN_Soft_L.glsl',
  'soft_vl': 'Anime4K_Restore_CNN_Soft_VL.glsl',
  'soft_ul': 'Anime4K_Restore_CNN_Soft_UL.glsl',
  'gan_ul': 'Anime4K_Restore_GAN_UL.glsl',
  'gan_uul': 'Anime4K_Restore_GAN_UUL.glsl',
};

const Map<String, String> _upscaleFiles = {
  'cnn_s': 'Anime4K_Upscale_CNN_x2_S.glsl',
  'cnn_m': 'Anime4K_Upscale_CNN_x2_M.glsl',
  'cnn_l': 'Anime4K_Upscale_CNN_x2_L.glsl',
  'cnn_vl': 'Anime4K_Upscale_CNN_x2_VL.glsl',
  'cnn_ul': 'Anime4K_Upscale_CNN_x2_UL.glsl',
  'denoise_s': 'Anime4K_Upscale_Denoise_CNN_x2_S.glsl',
  'denoise_m': 'Anime4K_Upscale_Denoise_CNN_x2_M.glsl',
  'denoise_l': 'Anime4K_Upscale_Denoise_CNN_x2_L.glsl',
  'denoise_vl': 'Anime4K_Upscale_Denoise_CNN_x2_VL.glsl',
  'denoise_ul': 'Anime4K_Upscale_Denoise_CNN_x2_UL.glsl',
  'gan_x2_s': 'Anime4K_Upscale_GAN_x2_S.glsl',
  'gan_x2_m': 'Anime4K_Upscale_GAN_x2_M.glsl',
  'gan_x3_l': 'Anime4K_Upscale_GAN_x3_L.glsl',
  'gan_x3_vl': 'Anime4K_Upscale_GAN_x3_VL.glsl',
  'gan_x4_ul': 'Anime4K_Upscale_GAN_x4_UL.glsl',
  'gan_x4_uul': 'Anime4K_Upscale_GAN_x4_UUL.glsl',
  'dog_x2': 'Anime4K_Upscale_DoG_x2.glsl',
  'dtd_x2': 'Anime4K_Upscale_DTD_x2.glsl',
  'original_x2': 'Anime4K_Upscale_Original_x2.glsl',
  '3d': 'Anime4K_3DGraphics_Upscale_x2_US.glsl',
  '3d_aa': 'Anime4K_3DGraphics_AA_Upscale_x2_US.glsl',
};

const Map<String, String> _denoiseFiles = {
  'mean': 'Anime4K_Denoise_Bilateral_Mean.glsl',
  'median': 'Anime4K_Denoise_Bilateral_Median.glsl',
  'mode': 'Anime4K_Denoise_Bilateral_Mode.glsl',
};

const Map<String, String> _deblurFiles = {
  'dog': 'Anime4K_Deblur_DoG.glsl',
  'original': 'Anime4K_Deblur_Original.glsl',
};

const Map<String, String> _thinFiles = {
  'fast': 'Anime4K_Thin_Fast.glsl',
  'veryfast': 'Anime4K_Thin_VeryFast.glsl',
  'hq': 'Anime4K_Thin_HQ.glsl',
};

const Map<String, String> _darkenFiles = {
  'fast': 'Anime4K_Darken_Fast.glsl',
  'veryfast': 'Anime4K_Darken_VeryFast.glsl',
  'hq': 'Anime4K_Darken_HQ.glsl',
};

const Map<String, String> _autoDownscaleFiles = {
  'x2': 'Anime4K_AutoDownscalePre_x2.glsl',
  'x4': 'Anime4K_AutoDownscalePre_x4.glsl',
};

/// 按选项组合出 Anime4K 着色器链。
List<String> anime4kShaderAssets(Map<String, String> choices) {
  final values = {...anime4kDefaults, ...choices};
  final files = <String>[];
  void add(String? name) {
    if (name != null) {
      files.add('assets/shaders/anime4k/$name');
    }
  }

  if (values['clamp'] != '0') {
    add('Anime4K_Clamp_Highlights.glsl');
  }
  add(_denoiseFiles[values['denoise']]);
  add(_deblurFiles[values['deblur']]);
  add(_restoreFiles[values['restore']]);
  add(_thinFiles[values['thin']]);
  add(_darkenFiles[values['darken']]);
  add(_autoDownscaleFiles[values['autoDownscale']]);
  add(_upscaleFiles[values['upscale']]);
  return files;
}

/// 负责把着色器资源释放到磁盘，并通过 mpv 属性加载它们。
class UpscalerShaderManager {
  static String? _signature;
  static List<String> _paths = const [];

  /// 将 assets 中的着色器写入应用目录，返回可被 mpv 读取的绝对路径。
  ///
  /// 数值参数会直接改写 `//!PARAM`（或 `#define`）后的默认值，
  /// 这样 mpv 无需依赖 `glsl-shader-opts` 也能生效。
  static Future<List<String>> resolve(
    UpscalerEngine engine, {
    Map<String, double> params = const {},
    Map<String, String> choices = const {},
  }) async {
    final signature =
        '${engine.id}|${jsonEncode(params)}|${jsonEncode(choices)}';
    if (signature == _signature) {
      return _paths;
    }
    final support = await getApplicationSupportDirectory();
    final dir = Directory(
      '${support.path}${Platform.pathSeparator}shaders'
      '${Platform.pathSeparator}${engine.id}',
    );
    await dir.create(recursive: true);
    final assets = engine == UpscalerEngine.anime4k
        ? anime4kShaderAssets(choices)
        : engine.shaderAssets;
    final paths = <String>[];
    for (final asset in assets) {
      final file = File(
        '${dir.path}${Platform.pathSeparator}${asset.split('/').last}',
      );
      var source = await rootBundle.loadString(asset);
      source = _rewriteParams(source, engine, params);
      await file.writeAsString(source, flush: true);
      paths.add(file.path);
    }
    _signature = signature;
    _paths = paths;
    return paths;
  }

  static String _rewriteParams(
    String source,
    UpscalerEngine engine,
    Map<String, double> params,
  ) {
    var result = source;
    final specs = upscalerParamSpecs[engine] ?? const <UpscalerParamSpec>[];
    for (final spec in specs) {
      final value = (params[spec.key] ?? spec.defaultValue)
          .clamp(spec.min, spec.max)
          .toDouble();
      if (engine == UpscalerEngine.sharpBilinear) {
        result = result.replaceAllMapped(
          RegExp(r'#define\s+SHARPNESS\s+[0-9.]+'),
          (_) => '#define SHARPNESS ${spec.format(value)}',
        );
        continue;
      }
      final pattern = RegExp(
        '(//!PARAM\\s+${RegExp.escape(spec.key)}\\r?\\n'
        '(?:[ \\t]*//![^\\r\\n]*\\r?\\n)*)'
        '[ \\t]*[-0-9.]+',
      );
      result = result.replaceAllMapped(
        pattern,
        (match) => '${match.group(1)}${spec.format(value)}',
      );
    }
    return result;
  }

  /// 应用引擎：先清空旧着色器，再逐个追加，避免路径分隔符在 Windows 上的歧义。
  static Future<void> apply(
    Player player,
    UpscalerEngine engine, {
    Map<String, double> params = const {},
    Map<String, String> choices = const {},
  }) async {
    final platform = player.platform;
    if (platform is! NativePlayer) {
      return;
    }
    var paths = const <String>[];
    if (engine.available && engine != UpscalerEngine.none) {
      try {
        paths = await resolve(engine, params: params, choices: choices);
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
