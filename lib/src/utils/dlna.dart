import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// 局域网内发现的 DLNA 媒体渲染设备。
class DlnaDevice {
  const DlnaDevice({
    required this.name,
    required this.location,
    required this.controlUrl,
  });

  final String name;
  final String location;
  final String controlUrl;

  String get host {
    try {
      return Uri.parse(location).host;
    } catch (_) {
      return location;
    }
  }
}

/// 纯 Dart 实现的 DLNA/SSDP 发现与 AVTransport 控制。
class DlnaService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 4),
    receiveTimeout: const Duration(seconds: 5),
    responseType: ResponseType.plain,
  ));

  /// 搜索局域网内的 MediaRenderer 设备。
  Future<List<DlnaDevice>> discover({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final found = <String, DlnaDevice>{};
    RawDatagramSocket? socket;
    StreamSubscription<RawSocketEvent>? subscription;
    final pending = <Future<void>>[];
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      socket.multicastLoopback = false;
      socket.multicastHops = 2;
      final payload = utf8.encode('M-SEARCH * HTTP/1.1\r\n'
          'HOST: 239.255.255.250:1900\r\n'
          'MAN: "ssdp:discover"\r\n'
          'MX: 3\r\n'
          'ST: urn:schemas-upnp-org:device:MediaRenderer:1\r\n'
          '\r\n');
      for (var i = 0; i < 2; i++) {
        socket.send(payload, InternetAddress('239.255.255.250'), 1900);
      }

      final completer = Completer<void>();
      subscription = socket.listen((event) {
        if (event != RawSocketEvent.read) {
          return;
        }
        final datagram = socket?.receive();
        if (datagram == null) {
          return;
        }
        final text = utf8.decode(datagram.data, allowMalformed: true);
        final location = _header(text, 'LOCATION');
        if (location == null || found.containsKey(location)) {
          return;
        }
        pending.add(_resolve(location).then((device) {
          if (device != null) {
            found[location] = device;
          }
        }));
      });
      Timer(timeout, () {
        if (!completer.isCompleted) {
          completer.complete();
        }
      });
      await completer.future;
      await Future.wait(pending);
    } catch (e) {
      debugPrint('DLNA 搜索失败: $e');
    } finally {
      await subscription?.cancel();
      socket?.close();
    }
    return found.values.toList();
  }

  Future<DlnaDevice?> _resolve(String location) async {
    try {
      final response = await _dio.get<String>(location);
      final xml = response.data ?? '';
      final name = _tag(xml, 'friendlyName') ?? 'DLNA 设备';
      String? controlPath;
      for (final match
          in RegExp(r'<service>([\s\S]*?)</service>').allMatches(xml)) {
        final block = match.group(1) ?? '';
        if (block.contains('AVTransport')) {
          controlPath = _tag(block, 'controlURL');
          break;
        }
      }
      if (controlPath == null || controlPath.isEmpty) {
        return null;
      }
      final controlUrl = Uri.parse(location).resolve(controlPath).toString();
      return DlnaDevice(
        name: _decodeEntities(name),
        location: location,
        controlUrl: controlUrl,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> setAvTransportUri(
    DlnaDevice device,
    String url, {
    String title = 'AniCh Next',
  }) async {
    final metadata = '<DIDL-Lite '
        'xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" '
        'xmlns:dc="http://purl.org/dc/elements/1.1/" '
        'xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/">'
        '<item id="0" parentID="-1" restricted="1">'
        '<dc:title>${_escapeXml(title)}</dc:title>'
        '<upnp:class>object.item.videoItem</upnp:class>'
        '<res protocolInfo="http-get:*:video/mp4:*">${_escapeXml(url)}</res>'
        '</item></DIDL-Lite>';
    await _soap(
      device,
      'SetAVTransportURI',
      '<InstanceID>0</InstanceID>'
          '<CurrentURI>${_escapeXml(url)}</CurrentURI>'
          '<CurrentURIMetaData>${_escapeXml(metadata)}</CurrentURIMetaData>',
    );
  }

  Future<void> play(DlnaDevice device) => _soap(
        device,
        'Play',
        '<InstanceID>0</InstanceID><Speed>1</Speed>',
      );

  Future<void> pause(DlnaDevice device) => _soap(
        device,
        'Pause',
        '<InstanceID>0</InstanceID>',
      );

  Future<void> stop(DlnaDevice device) => _soap(
        device,
        'Stop',
        '<InstanceID>0</InstanceID>',
      );

  Future<void> _soap(
    DlnaDevice device,
    String action,
    String body,
  ) async {
    final envelope = '<?xml version="1.0" encoding="utf-8"?>'
        '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" '
        's:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">'
        '<s:Body><u:$action '
        'xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">'
        '$body</u:$action></s:Body></s:Envelope>';
    final response = await _dio.post<String>(
      device.controlUrl,
      data: envelope,
      options: Options(
        contentType: 'text/xml; charset="utf-8"',
        headers: {
          'SOAPAction': '"urn:schemas-upnp-org:service:AVTransport:1#$action"',
        },
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    if (response.statusCode != null && response.statusCode! >= 400) {
      throw HttpException('DLNA 设备返回 ${response.statusCode}');
    }
  }

  void dispose() {
    _dio.close(force: true);
  }

  String? _header(String text, String name) {
    for (final line in const LineSplitter().convert(text)) {
      final index = line.indexOf(':');
      if (index <= 0) {
        continue;
      }
      if (line.substring(0, index).trim().toUpperCase() == name.toUpperCase()) {
        return line.substring(index + 1).trim();
      }
    }
    return null;
  }

  String? _tag(String xml, String tag) {
    final match = RegExp('<$tag[^>]*>([\\s\\S]*?)</$tag>', caseSensitive: false)
        .firstMatch(xml);
    return match?.group(1)?.trim();
  }

  String _decodeEntities(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");
  }

  String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}

/// 在局域网内提供本地缓存文件，供电视等 DLNA 设备拉流播放。
class LocalMediaServer {
  HttpServer? _server;
  String? _filePath;
  String _fileName = 'video.mp4';

  bool get isRunning => _server != null;

  Future<String> serve(String filePath) async {
    await stop();
    _filePath = filePath;
    _fileName = filePath.split(Platform.pathSeparator).last;
    final server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    _server = server;
    server.listen(_handle);
    final ip = await _localIp();
    return 'http://$ip:${server.port}/${Uri.encodeComponent(_fileName)}';
  }

  Future<void> _handle(HttpRequest request) async {
    final path = _filePath;
    if (path == null) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }
    final file = File(path);
    if (!await file.exists()) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }
    final total = await file.length();
    request.response.headers
      ..set(HttpHeaders.contentTypeHeader, _contentType(path))
      ..set(HttpHeaders.acceptRangesHeader, 'bytes');
    if (request.method == 'HEAD') {
      request.response.headers.set(HttpHeaders.contentLengthHeader, total);
      await request.response.close();
      return;
    }
    final range = request.headers.value(HttpHeaders.rangeHeader);
    if (range != null) {
      final match = RegExp(r'bytes=(\d*)-(\d*)').firstMatch(range);
      var start = int.tryParse(match?.group(1) ?? '') ?? 0;
      var end = int.tryParse(match?.group(2) ?? '') ?? total - 1;
      if (end >= total) {
        end = total - 1;
      }
      if (start > end) {
        start = 0;
      }
      request.response.statusCode = HttpStatus.partialContent;
      request.response.headers
        ..set(HttpHeaders.contentRangeHeader, 'bytes $start-$end/$total')
        ..set(HttpHeaders.contentLengthHeader, end - start + 1);
      await request.response.addStream(file.openRead(start, end + 1));
    } else {
      request.response.headers.set(HttpHeaders.contentLengthHeader, total);
      await request.response.addStream(file.openRead());
    }
    await request.response.close();
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  Future<String> _localIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (address.isLoopback || address.address.startsWith('169.254.')) {
            continue;
          }
          return address.address;
        }
      }
    } catch (_) {
      // 获取失败时回退到本机地址
    }
    return '127.0.0.1';
  }

  String _contentType(String path) {
    final extension = path.split('.').last.toLowerCase();
    return switch (extension) {
      'mp4' || 'm4v' => 'video/mp4',
      'mkv' => 'video/x-matroska',
      'webm' => 'video/webm',
      'avi' => 'video/x-msvideo',
      'flv' => 'video/x-flv',
      'ts' => 'video/mp2t',
      'mov' => 'video/quicktime',
      _ => 'application/octet-stream',
    };
  }
}
