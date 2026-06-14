import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_styles.dart';
import '../widgets/mobile_page.dart';

/// Màn "hướng dẫn di chuyển" — mở từ link "xem hướng dẫn" ở màn lịch hẹn.
///
/// TODO: bổ sung nội dung hướng dẫn (sơ đồ trường, vị trí trên map, ...) khi có.
class GuidePage extends StatelessWidget {
  const GuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return MobilePage(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Hướng dẫn di chuyển đang được cập nhật nhoa.',
            style: messageTextStyle(context),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          InkWell(
            onTap: () => context.go('/scheduled'),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back, size: 16, color: colorScheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    'quay lại',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                      decoration: TextDecoration.underline,
                      decorationColor: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
