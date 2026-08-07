import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import 'controllers/auth_controller.dart';
import 'controllers/guest_controller.dart';
import 'pages/admin_page.dart';
import 'pages/auth_page.dart';
import 'pages/countdown_page.dart';
import 'pages/gallery_page.dart';
import 'pages/guide_page.dart';
import 'pages/invite_detail_page.dart';
import 'pages/login_page.dart';
import 'pages/love_page.dart';
import 'pages/post_detail_page.dart';
import 'pages/post_editor_page.dart';
import 'pages/posts_admin_page.dart';
import 'pages/posts_page.dart';
import 'pages/scheduled_page.dart';
import 'pages/user_gallery_page.dart';
import 'pages/welcome_page.dart';

/// Cấu hình điều hướng theo URL.
///
/// Công khai (không cần đăng nhập):
///  - `/`          : danh sách bài viết đã đăng
///  - `/posts`     : alias danh sách bài viết đã đăng
///  - `/posts/:id` : đọc chi tiết 1 bài viết đã đăng
///  - `/auth`      : xác thực khách mời (nhập code + số điện thoại)
///  - `/countdown` : trang đếm ngược đến sự kiện
///  - `/login`     : đăng nhập admin
/// Cần khách đã xác thực:
///  - `/welcome`   : trang chào            (chưa xác nhận)
///  - `/invite`    : chi tiết lời mời + xác nhận
///  - `/scheduled` : lịch hẹn              (sau khi xác nhận)
///  - `/guide`     : hướng dẫn di chuyển
/// Cần đăng nhập admin:
///  - `/admin`                : trang quản trị
///  - `/admin/posts`          : quản lý bài viết
///  - `/admin/posts/edit`     : viết bài mới
///  - `/admin/posts/edit/:id` : sửa bài đã có
final router = GoRouter(
  initialLocation: '/',
  refreshListenable: Listenable.merge([authController, guestController]),
  redirect: (context, state) {
    final loc = state.matchedLocation;
    final loggedIn = authController.isLoggedIn;
    final guestAuthed = guestController.isAuthenticated;
    final confirmed = guestController.confirmed;

    // Bảo vệ /admin (+ mọi trang con /admin/...) và /gallery:
    // chưa đăng nhập -> về /login.
    final needsAdmin =
        loc == '/admin' || loc.startsWith('/admin/') || loc == '/gallery';
    if (needsAdmin && !loggedIn) return '/login';
    // Đã đăng nhập mà mở /login -> vào /admin.
    if (loc == '/login' && loggedIn) return '/admin';

    // Khách đã xác thực ở trang nhập code: đã xác nhận thì vào thẳng lịch hẹn,
    // chưa thì vào trang chào (chặn quay lại trang nhập code khi back/reload).
    if (loc == '/auth' && guestAuthed) {
      return confirmed ? '/scheduled' : '/welcome';
    }

    // Đã xác nhận tham dự -> không quay lại bước chào / xác nhận nữa.
    if (guestAuthed && confirmed && (loc == '/welcome' || loc == '/invite')) {
      return '/scheduled';
    }

    // Các trang chỉ dành cho khách đã xác thực -> chưa xác thực thì về nhập code.
    const guestOnly = [
      '/welcome',
      '/invite',
      '/scheduled',
      '/guide',
      '/photos',
    ];
    if (guestOnly.contains(loc) && !guestAuthed) return '/auth';
    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (context, state) => const PostsPage()),
    GoRoute(path: '/auth', builder: (context, state) => const AuthPage()),
    GoRoute(path: '/welcome', builder: (context, state) => const WelcomePage()),
    GoRoute(
      path: '/invite',
      builder: (context, state) => const InviteDetailPage(),
    ),
    GoRoute(
      path: '/scheduled',
      builder: (context, state) => const ScheduledPage(),
    ),
    GoRoute(path: '/guide', builder: (context, state) => const GuidePage()),
    GoRoute(
      path: '/photos',
      builder: (context, state) => const UserGalleryPage(),
    ),
    GoRoute(
      path: '/countdown',
      builder: (context, state) => const CountdownPage(),
    ),
    GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
    GoRoute(path: '/admin', builder: (context, state) => const AdminPage()),
    GoRoute(
      path: '/admin/posts',
      builder: (context, state) => const PostsAdminPage(),
    ),
    GoRoute(
      path: '/admin/posts/edit',
      builder: (context, state) => const PostEditorPage(),
    ),
    GoRoute(
      path: '/admin/posts/edit/:id',
      builder: (context, state) =>
          PostEditorPage(postId: state.pathParameters['id']),
    ),
    GoRoute(
      path: '/posts',
      builder: (context, state) => const PostsPage(showBackButton: true),
    ),
    GoRoute(
      path: '/posts/:id',
      builder: (context, state) =>
          PostDetailPage(postId: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(path: '/gallery', builder: (context, state) => const GalleryPage()),
    GoRoute(path: '/love', builder: (context, state) => const LovePage()),
  ],
);
