import 'package:get/get.dart';
import 'package:xs/src/middlewares/auth.dart';
import 'package:xs/src/pages/account/change_password.dart';
import 'package:xs/src/pages/account/login.dart';
import 'package:xs/src/pages/account/register.dart';
import 'package:xs/src/pages/bangumi/view.dart';
import 'package:xs/src/pages/bangumi_collection/view.dart';
import 'package:xs/src/pages/bangumi_detail/view.dart';
import 'package:xs/src/pages/bangumi_vod/view.dart';
import 'package:xs/src/pages/character/view.dart';
import 'package:xs/src/pages/download/view.dart';
import 'package:xs/src/pages/home/view.dart';
import 'package:xs/src/pages/person/view.dart';
import 'package:xs/src/pages/settings/info.dart';
import 'package:xs/src/pages/thread_collection/view.dart';
import 'package:xs/src/pages/profile/view.dart';
import 'package:xs/src/pages/search/view.dart';
import 'package:xs/src/pages/search_panel/view.dart';
import 'package:xs/src/pages/settings/account.dart';
import 'package:xs/src/pages/settings/danmaku.dart';
import 'package:xs/src/pages/settings/play_history.dart';
import 'package:xs/src/pages/settings/theme.dart';
import 'package:xs/src/pages/tags/view.dart';
import 'package:xs/src/pages/thread/view.dart';

/// 所有内容页面都挂 [AuthMiddleware]：
/// 本地没有 token 时一律重定向到 `/login`，等同于启动即强制登录。
/// `/login`、`/register`、`/change_password` 三个页面保持公开，否则会重定向死循环。
class AppRoute {
  static const List<String> publicRoutes = [
    '/login',
    '/register',
    '/change_password',
  ];

  static final pages = [
    // 主页
    GetPage(
        name: '/',
        page: () => const HomePage(),
        middlewares: [AuthMiddleware()]),
    // 标签
    GetPage(
        name: '/tags',
        page: () => const TagsPage(),
        middlewares: [AuthMiddleware()]),
    // 登录
    GetPage(name: '/login', page: () => const LoginPage()),
    // 注册
    GetPage(name: '/register', page: () => const RegisterPage()),
    // 修改密码
    GetPage(name: '/change_password', page: () => const ChangePasswordPage()),
    // 个人中心
    GetPage(
        name: '/profile',
        page: () => const ProfilePage(),
        middlewares: [AuthMiddleware()]),
    // 帖子
    GetPage(
        name: '/thread/:id',
        page: () => const ThreadPage(),
        middlewares: [AuthMiddleware()]),
    // 番剧
    GetPage(
        name: '/bangumi',
        page: () => const BangumiPage(),
        middlewares: [AuthMiddleware()]),
    // 番剧详情
    GetPage(
        name: '/bangumi/:id',
        page: () => const BangumiDetailPage(),
        middlewares: [AuthMiddleware()]),
    // 番剧播放页
    GetPage(
        name: '/vod/:id',
        page: () => const BangumiVodPage(),
        middlewares: [AuthMiddleware()]),
    // 角色
    GetPage(
        name: '/character',
        page: () => const CharacterPage(),
        middlewares: [AuthMiddleware()]),
    // 人物
    GetPage(
        name: '/person',
        page: () => const PersonPage(),
        middlewares: [AuthMiddleware()]),
    // 搜索面板
    GetPage(
        name: '/search_panel',
        page: () => const SearchPanelPage(),
        middlewares: [AuthMiddleware()]),
    // 搜索结果
    GetPage(
        name: '/search',
        page: () => const SearchPage(),
        middlewares: [AuthMiddleware()]),

    // 账号管理
    GetPage(
        name: '/account_settings',
        page: () => const AccountSettingsPage(),
        middlewares: [AuthMiddleware()]),
    // 外观设置
    GetPage(
        name: '/theme_settings',
        page: () => const ThemeSettingsPage(),
        middlewares: [AuthMiddleware()]),
    // 弹幕设置
    GetPage(
        name: '/danmaku_settings',
        page: () => const DanmakuSettingsPage(),
        middlewares: [AuthMiddleware()]),
    // 版本信息
    GetPage(
        name: '/info',
        page: () => const InfoSettingsPage(),
        middlewares: [AuthMiddleware()]),

    // 历史记录
    GetPage(
        name: '/play_history',
        page: () => const PlayHistoryPage(),
        middlewares: [AuthMiddleware()]),
    // 追番列表
    GetPage(
        name: '/bangumi_collection',
        page: () => const BangumiCollectionPage(),
        middlewares: [AuthMiddleware()]),
    // 图片收藏
    GetPage(
        name: '/thread_collection',
        page: () => const ThreadCollectionPage(),
        middlewares: [AuthMiddleware()]),
    // 离线缓存
    GetPage(
        name: '/download',
        page: () => const DownloadPage(),
        middlewares: [AuthMiddleware()]),
  ];
}
