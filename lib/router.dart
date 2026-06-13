import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import 'controllers/auth_controller.dart';
import 'controllers/guest_controller.dart';
import 'pages/admin_page.dart';
import 'pages/auth_page.dart';
import 'pages/countdown_page.dart';
import 'pages/login_page.dart';
import 'pages/welcome_page.dart';

/// Cấu hình điều hướng theo URL.
///
/// Công khai (không cần đăng nhập):
///  - `/`          : xác thực khách mời (nhập code + số điện thoại)
///  - `/welcome`   : trang chủ sau khi xác thực
///  - `/countdown` : trang đếm ngược đến sự kiện
///  - `/login`     : đăng nhập admin
/// Cần đăng nhập admin:
///  - `/admin`     : trang quản trị
final router = GoRouter(
  initialLocation: '/',
  refreshListenable: Listenable.merge([authController, guestController]),
  redirect: (context, state) {
    final loc = state.matchedLocation;
    final loggedIn = authController.isLoggedIn;
    final guestAuthed = guestController.isAuthenticated;

    // Bảo vệ /admin: chưa đăng nhập -> về /login.
    if (loc == '/admin' && !loggedIn) return '/login';
    // Đã đăng nhập mà mở /login -> vào /admin.
    if (loc == '/login' && loggedIn) return '/admin';

    // Khách đã xác thực: vào thẳng trang chủ, chặn quay lại trang nhập code
    // (kể cả khi bấm back trên trình duyệt hay tải lại trang).
    if (loc == '/' && guestAuthed) return '/welcome';
    // Chưa xác thực mà mở trang chủ khách -> về trang nhập code.
    if (loc == '/welcome' && !guestAuthed) return '/';
    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const AuthPage(),
    ),
    GoRoute(
      path: '/welcome',
      builder: (context, state) => const WelcomePage(),
    ),
    GoRoute(
      path: '/countdown',
      builder: (context, state) => const CountdownPage(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminPage(),
    ),
  ],
);
