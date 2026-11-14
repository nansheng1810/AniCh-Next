import 'dart:async';
import 'dart:io';

/// 单条线路测速结果。
class LineSpeedResult {
  const LineSpeedResult({
    required this.latencyMs,
    required this.speedKbps,
    required this.error,
  });

  /// 首字节延迟（毫秒）。
  final int latencyMs;

  /// 下载速度（KB/s），m3u8 等小文件可能为 0。
  final double speedKbps;

  final bool error;

  String get text {
    if (error) {
      return '不可用';
    }
    final speed = speedKbps >= 1024
        ? '${(speedKbps / 1024).toStringAsFixed(1)} MB/s'
        : '${speedKbps.toStringAsFixed(0)} KB/s';
    return '$latencyMs ms · $speed';
  }
}

/// 通过 Range 请求测试线路延迟与下载速度，不依赖原生插件。
class LineSpeedTester {
  static Future<LineSpeedResult> test(
    String url, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final stopwatch = Stopwatch()..start();
      final request = await client.getUrl(Uri.parse(url)).timeout(timeout);
      request.headers.set(HttpHeaders.rangeHeader, 'bytes=0-524287');
      request.headers.set(HttpHeaders.userAgentHeader, 'AniCh-Next/1.3');
      final response = await request.close().timeout(timeout);
      final firstByte = stopwatch.elapsedMilliseconds;
      if (response.statusCode >= 400) {
        await response.drain<void>();
        return LineSpeedResult(
          latencyMs: firstByte,
          speedKbps: 0,
          error: true,
        );
      }
      var bytes = 0;
      await for (final chunk in response.timeout(timeout)) {
        bytes += chunk.length;
        if (bytes >= 512 * 1024 ||
            stopwatch.elapsed > const Duration(seconds: 5)) {
          break;
        }
      }
      final elapsed = stopwatch.elapsedMilliseconds;
      return LineSpeedResult(
        latencyMs: firstByte,
        speedKbps: elapsed > 0 ? bytes / 1024 / (elapsed / 1000) : 0,
        error: false,
      );
    } catch (_) {
      return const LineSpeedResult(latencyMs: 0, speedKbps: 0, error: true);
    } finally {
      client.close(force: true);
    }
  }
}
