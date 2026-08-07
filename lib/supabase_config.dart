/// Cấu hình kết nối Supabase.
///
/// Giá trị KHÔNG hardcode trong code — nạp qua biến môi trường lúc build/run:
///   flutter run   --dart-define-from-file=env.json
///   flutter build --dart-define-from-file=env.json
/// (xem `env.example.json` để biết các khóa cần điền; `env.json` đã được
/// .gitignore nên không lọt lên git.)
///
/// Lưu ý: đây vẫn là app web client nên các giá trị này CÔNG KHAI khi chạy —
/// bảo mật thật nằm ở RLS / Storage policies. Đưa vào env chủ yếu để không
/// lưu key trong source code và dễ xoay key/đổi môi trường.
class SupabaseConfig {
  /// Vd: 'https://abcdxyz.supabase.co'
  static const String url = String.fromEnvironment('SUPABASE_URL');

  /// Khóa công khai (publishable key, dạng `sb_publishable_...`).
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Tên bucket chứa ảnh gallery (tạo trên Supabase Storage).
  static const String galleryBucket = 'graduation';

  /// File Storage quota của Supabase Free Plan (1 GiB). Quota thực tế được
  /// tính ở cấp organization; giá trị này phù hợp khi dùng gói Free.
  static const int storageQuotaBytes = 1024 * 1024 * 1024;

  /// Đã nạp cấu hình qua env chưa (để app bỏ qua Supabase thay vì crash khi
  /// chạy mà quên truyền --dart-define-from-file=env.json).
  static bool get isConfigured => url.startsWith('http') && anonKey.isNotEmpty;
}
