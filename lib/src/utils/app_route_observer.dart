import 'package:flutter/material.dart';

/// 全局路由观察者：页面返回时用于自愈重建（例如播放页返回详情页）。
final RouteObserver<ModalRoute<dynamic>> appRouteObserver =
    RouteObserver<ModalRoute<dynamic>>();

/// 是否发生过渲染错误。Release 下 ErrorWidget 会显示灰块，
/// 返回页面时如果出现过错误就强制重挂内容，避免灰块残留。
bool hadRenderError = false;

/// 播放页是否刚刚关闭：返回详情页时需要重挂内容区，
/// 避免播放过程中后台重建留下的异常布局。
bool vodPageClosed = false;
