import 'package:flutter_test/flutter_test.dart';
import 'package:xs/src/pages/bangumi_collection/models/bangumi_collection_model.dart';

void main() {
  test('BangumiCollection 能解析收藏分页的 next 标记', () {
    final data = BangumiCollection.fromJson({
      'error': false,
      'message': '',
      'body': {
        'data': <dynamic>[],
        'page': 1,
        'prev': false,
        'next': true,
        'total': 0,
      },
    });

    expect(data.error, isFalse);
    expect(data.body?.page, 1);
    expect(data.body?.next, isTrue);
    expect(data.body?.data, isEmpty);
  });
}
