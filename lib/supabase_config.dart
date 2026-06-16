/// Cấu hình kết nối Supabase.
///
/// Hai giá trị này là CÔNG KHAI (anon key được thiết kế để nhúng vào client) —
/// quyền truy cập thật do RLS / Storage policies trên Supabase quyết định.
///
/// Lấy ở: Supabase Dashboard -> Project Settings -> API:
///   - Project URL        -> [supabaseUrl]
///   - Project API keys: anon public -> [supabaseAnonKey]
class SupabaseConfig {
  /// Vd: 'https://abcdxyz.supabase.co'
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://opfyzjqyqpvofumpbzyw.supabase.co',
  );

  /// Khóa công khai (publishable key, dạng `sb_publishable_...`).
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_HmokPPM2wAaR95kbaRfIoA_xx7wshZo',
  );

  /// Tên bucket chứa ảnh gallery (tạo trên Supabase Storage).
  static const String galleryBucket = 'graduation';

  /// Đã điền cấu hình thật chưa (để app cảnh báo thay vì lỗi khó hiểu).
  static bool get isConfigured =>
      url.startsWith('http') && !anonKey.startsWith('PASTE_');
}
