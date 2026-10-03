/// Chữ thường + bỏ dấu tiếng Việt (vd "Tốt Nghiệp" -> "tot nghiep"). Dùng chung
/// cho slug và tìm kiếm để người đọc gõ không dấu vẫn khớp.
String foldVietnamese(String text) {
  const vietnamese = {
    'àáạảãâầấậẩẫăằắặẳẵ': 'a',
    'èéẹẻẽêềếệểễ': 'e',
    'ìíịỉĩ': 'i',
    'òóọỏõôồốộổỗơờớợởỡ': 'o',
    'ùúụủũưừứựửữ': 'u',
    'ỳýỵỷỹ': 'y',
    'đ': 'd',
  };

  var value = text.toLowerCase();
  for (final entry in vietnamese.entries) {
    for (final character in entry.key.split('')) {
      value = value.replaceAll(character, entry.value);
    }
  }
  // Một số bộ gõ sinh chữ dạng tổ hợp (o + dấu mũ + dấu sắc) thay vì "ố"
  // dựng sẵn: gỡ các dấu rời còn sót lại.
  return value.replaceAll(RegExp('[\u0300-\u036f]'), '');
}

/// Chuyển tiêu đề thành phần đường dẫn chỉ gồm chữ thường, chữ số và gạch ngang.
String postSlug(String title) {
  return foldVietnamese(
    title,
  ).replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
}

/// ID đảm bảo truy vấn đúng bài, còn slug giúp URL dễ đọc.
String postDetailPath({required String id, required String title}) {
  final slug = postSlug(title);
  return slug.isEmpty ? '/posts/$id' : '/posts/$id/$slug';
}
