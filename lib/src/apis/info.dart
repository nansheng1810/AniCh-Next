import 'package:dio/dio.dart';
import 'package:xs/src/utils/account.dart';

final api = createApiDio();

class InfoApi {
  // 最新
  static Future<Response> checkUpdate() async {
    const url =
        'https://api.github.com/repos/nansheng1810/AniCh-Next/releases/latest';
    final response =
        await api.get(url, options: Options(responseType: ResponseType.json));
    return response;
  }
}
