# 🎓 Graduation 2026 — Web tốt nghiệp của Hiếu

> Trang web kỷ niệm & mời tham dự lễ tốt nghiệp 2026, được xây dựng bằng **Flutter Web**.

<p align="left">
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-Web-02569B?logo=flutter&logoColor=white">
  <img alt="Firebase" src="https://img.shields.io/badge/Firebase-Hosting%20%7C%20Auth%20%7C%20Firestore-FFCA28?logo=firebase&logoColor=black">
  <img alt="Supabase" src="https://img.shields.io/badge/Supabase-Storage-3ECF8E?logo=supabase&logoColor=white">
</p>

🌐 **Live:** https://graduation-e59ff.web.app

---

## ✨ Tính năng

- ⏳ **Đếm ngược** đến ngày lễ tốt nghiệp
- 💌 **Thiệp mời** chi tiết cho từng khách
- 🖼️ **Thư viện ảnh** (gallery) kỷ niệm
- 💝 Trang **lời nhắn / love** & lời cảm ơn
- 🗺️ **Hướng dẫn** đường đi và thông tin sự kiện
- 🗓️ **Lịch trình** chương trình
- 🔐 **Đăng nhập** + **trang quản trị** (admin) để cập nhật nội dung

## 🧱 Công nghệ

| Mảng | Công nghệ |
|------|-----------|
| Giao diện | Flutter Web, `go_router` |
| Backend dữ liệu | Firebase **Firestore**, Firebase **Auth** |
| Lưu ảnh / file | **Supabase** Storage |
| Hosting | Firebase **Hosting** |

## 📁 Cấu trúc thư mục

```
lib/
├── main.dart              # Điểm khởi chạy
├── router.dart            # Định tuyến (go_router)
├── firebase_options.dart  # Cấu hình Firebase
├── supabase_config.dart   # Đọc key Supabase từ --dart-define
├── pages/                 # Các trang (welcome, countdown, gallery, admin, ...)
├── widgets/               # Component dùng lại
├── controllers/           # Xử lý logic / state
├── models/                # Model dữ liệu
├── services/              # Gọi Firestore / Supabase
└── theme/                 # Màu sắc, font, theme
```

---

## 🚀 Bắt đầu

### 1. Yêu cầu
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Dart `^3.11.5`)
- [Firebase CLI](https://firebase.google.com/docs/cli) (để deploy)

### 2. Cài dependency
```bash
flutter pub get
```

### 3. Tạo file `env.json` 🔑
File này chứa key Supabase và **không được commit** (đã nằm trong `.gitignore`). Tạo ở thư mục gốc:

```json
{
  "SUPABASE_URL": "https://<project>.supabase.co",
  "SUPABASE_ANON_KEY": "<anon_key>"
}
```

> ⚠️ Key được **nạp lúc build** qua `--dart-define-from-file=env.json` và nướng thẳng vào bản web — Firebase/prod không đọc file `env.json`, nên **luôn phải truyền cờ này** khi run/build.

### 4. Chạy thử (local)
```bash
flutter run -d chrome --dart-define-from-file=env.json
```

---

## 📦 Build & Deploy

Luôn chạy **đủ 2 bước, đúng thứ tự** mỗi khi cập nhật web:

```bash
# 1) Build code mới ra build/web (kèm key Supabase)
flutter build web --release --dart-define-from-file=env.json

# 2) Đẩy build/web lên Firebase Hosting
firebase deploy --only hosting
```

> 💡 Firebase chỉ upload thư mục `build/web`, **không build từ source**. Quên bước 1 → web sẽ vẫn là bản cũ. Thiếu cờ `--dart-define-from-file=env.json` → mất key.

### Kiểm tra nhanh sau khi deploy
```bash
# Key Supabase đã nằm trong bản build chưa? (trả về số > 0 là OK)
grep -c "supabase.co" build/web/main.dart.js

# Bản live mới nhất phát hành lúc nào?
firebase hosting:channel:list
```

Nếu trên trình duyệt vẫn thấy bản cũ → bấm **Ctrl + Shift + R** (hard refresh) để xoá cache.

---

<p align="center">Made with ❤️ for Hiếu's Graduation 2026</p>
