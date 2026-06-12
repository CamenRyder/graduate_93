import 'package:go_router/go_router.dart';

import 'controllers/auth_controller.dart';
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
  refreshListenable: authController,
  redirect: (context, state) {
    final loc = state.matchedLocation;
    final loggedIn = authController.isLoggedIn;

    // Bảo vệ /admin: chưa đăng nhập -> về /login.
    if (loc == '/admin' && !loggedIn) return '/login';
    // Đã đăng nhập mà mở /login -> vào /admin.
    if (loc == '/login' && loggedIn) return '/admin';
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
