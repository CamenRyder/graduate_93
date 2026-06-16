import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'controllers/auth_controller.dart';
import 'controllers/guest_controller.dart';
import 'controllers/theme_controller.dart';
import 'firebase_options.dart';
import 'router.dart';
import 'supabase_config.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // URL "sạch": /admin thay vì /#/admin
  usePathUrlStrategy();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Supabase: dùng cho kho ảnh (gallery). Chỉ khởi tạo khi đã điền cấu hình
  // để app không crash lúc chưa cắm URL/khóa.
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
    );
  }

  // Cache Firestore trong IndexedDB: lần 2+ trả data tức thì rồi sync ngầm.
  // synchronizeTabs = true: nhiều tab mở cùng lúc vẫn nhất quán.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Đọc lựa chọn theme + trạng thái đăng nhập đã lưu trước khi vẽ giao diện.
  await Future.wait([
    themeController.load(),
    authController.load(),
    guestController.load(),
  ]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuild lại app khi đổi chế độ Sáng/Tối.
    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) {
        return MaterialApp.router(
          title: 'Admin · Web Gra',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeController.themeMode,
          routerConfig: router,
          // Giảm cỡ chữ toàn hệ thống xuống 80% (nhỏ hơn 20%).
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(textScaler: const TextScaler.linear(0.8)),
              child: child ?? const SizedBox.shrink(),
            );
          },
        );
      },
    );
  }
}
