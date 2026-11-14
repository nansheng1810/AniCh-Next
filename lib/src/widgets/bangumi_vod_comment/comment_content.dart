import 'package:flutter/material.dart';
import 'package:xs/src/utils/color.dart';
import 'package:xs/src/widgets/sticker.dart';

/// 后端新旧评论结构兼容：老接口返回 contents 分段，新接口直接返回 text。
String commentPlainText(Map item) {
  final text = item['text'];
  if (text is String) {
    return text.replaceAll(RegExp(r'\n$'), '');
  }
  final contents = item['contents'];
  if (contents is List) {
    final buffer = StringBuffer();
    for (final part in contents) {
      if (part is Map) {
        buffer.write(part['type'] == 'sticker'
            ? '[${part['content']}]'
            : part['content']);
      } else {
        buffer.write(part);
      }
    }
    return buffer.toString().replaceAll(RegExp(r'\n$'), '');
  }
  return '';
}

/// 把评论正文转换成富文本，找不到表情资源时降级为文字。
List<InlineSpan> commentSpans(Map item) {
  final contents = item['contents'];
  if (contents is List && contents.isNotEmpty) {
    final spans = <InlineSpan>[];
    for (final part in contents) {
      if (part is! Map) {
        spans.add(TextSpan(text: '$part'));
        continue;
      }
      if (part['type'] == 'sticker') {
        Map? stickerItem;
        for (final i in sticker['list']) {
          if (i['text'] == part['content']) {
            stickerItem = i;
            break;
          }
        }
        if (stickerItem == null) {
          spans.add(TextSpan(text: '[${part['content']}]'));
        } else {
          spans.add(WidgetSpan(
            child: Image.asset(
              '${sticker['path']}${stickerItem['src']}',
              height: 40,
            ),
          ));
        }
      } else {
        spans.add(TextSpan(text: '${part['content'] ?? ''}'));
      }
    }
    return spans;
  }
  return [TextSpan(text: commentPlainText(item))];
}

String commentUserName(Map item) {
  final user = item['user'];
  if (user is Map) {
    final name = '${user['name'] ?? ''}'.trim();
    if (name.isNotEmpty) {
      return name;
    }
  }
  return '匿名用户';
}

String? commentAvatar(Map item) {
  final user = item['user'];
  if (user is Map) {
    final avatar = user['avatar'];
    if (avatar is String && avatar.isNotEmpty) {
      return avatar;
    }
  }
  return null;
}

Color commentAvatarColor(Map item) {
  final user = item['user'];
  final hex = user is Map ? '${user['color'] ?? ''}' : '';
  try {
    return ColorUtil.fromHex(hex);
  } catch (_) {
    return Colors.grey;
  }
}

int? commentCreatedAt(Map item) {
  final created = item['created'];
  if (created is String) {
    final parsed = DateTime.tryParse(created);
    if (parsed != null) {
      return parsed.millisecondsSinceEpoch;
    }
  }
  final date = item['date'];
  if (date is num) {
    return date.toInt();
  }
  return null;
}
