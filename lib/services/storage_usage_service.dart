import 'package:supabase_flutter/supabase_flutter.dart';

/// Tổng dung lượng file trong các Storage bucket của Supabase project.
class StorageUsage {
  const StorageUsage({required this.usedBytes, required this.quotaBytes});

  final int usedBytes;
  final int quotaBytes;

  int get remainingBytes => (quotaBytes - usedBytes).clamp(0, quotaBytes);

  double get usedFraction =>
      quotaBytes == 0 ? 0 : (usedBytes / quotaBytes).clamp(0, 1);

  double get remainingFraction => 1 - usedFraction;
}

/// Đọc tổng kích thước object qua RPC chỉ-đọc được khai báo trong migration.
class StorageUsageService {
  StorageUsageService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<StorageUsage> getUsage({required int quotaBytes}) async {
    final value = await _client.rpc('get_storage_usage_bytes');
    final usedBytes = switch (value) {
      int v => v,
      num v => v.toInt(),
      String v => int.tryParse(v),
      _ => null,
    };

    if (usedBytes == null || usedBytes < 0) {
      throw const FormatException(
        'RPC get_storage_usage_bytes trả về dữ liệu không hợp lệ.',
      );
    }
    return StorageUsage(usedBytes: usedBytes, quotaBytes: quotaBytes);
  }
}
