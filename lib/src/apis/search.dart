import 'package:dio/dio.dart';
import 'package:xs/protobuf/list.pb.dart';
import 'package:xs/src/config.dart';
import 'package:xs/src/utils/account.dart';

final api = createApiDio(baseUrl: AppConfig.baseUrl);

class SearchApi {
  // 搜索图片
  static Future<Response> searchPicture(
      {required String keyword, int skip = 0}) async {
    const url = '/search';
    final response = await api.get(url,
        queryParameters: {'keyword': keyword, 'skip': skip},
        options: Options(responseType: ResponseType.bytes));
    return response;
  }

  // 搜索番剧
  static Future<Response> searchBangumi(
      {required String keyword, int skip = 0}) async {
    const url = '/bangumi/search';
    final response = await api.get(url,
        queryParameters: {'keyword': keyword, 'skip': skip},
        options: Options(responseType: ResponseType.bytes));
    return response;
  }

  // 搜索联想：图片搜索的关键词
  static Future<List<autocomplete_body_>> autocomplete(
      {required String keyword}) async {
    const url = '/search/autocomplete';
    final response = await api.get(url,
        queryParameters: {'keyword': keyword},
        options: Options(responseType: ResponseType.bytes));
    if (response.statusCode != 200) {
      throw Error();
    }
    final data = autocomplete_.fromBuffer(response.data);
    if (data.error) {
      throw Error();
    }
    return data.body;
  }

  // 搜索联想：番剧作品名
  static Future<List<String>> bangumiAutocomplete(
      {required String keyword}) async {
    const url = '/bangumi/autocomplete';
    final response = await api.get(url,
        queryParameters: {'keyword': keyword});
    if (response.statusCode != 200) {
      throw Error();
    }
    final data = response.data['data'];
    if (data is! List) {
      return [];
    }
    return data
        .map((e) => e is Map ? (e['title'] ?? '').toString() : '')
        .where((e) => e.isNotEmpty)
        .toList();
  }
}
