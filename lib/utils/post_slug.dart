/// Chuyển tiêu đề thành phần đường dẫn chỉ gồm chữ thường, chữ số và gạch ngang.
String postSlug(String title) {
  const vietnamese = {
    'àáạảãâầấậẩẫăằắặẳẵ': 'a',
    'èéẹẻẽêềếệểễ': 'e',
    'ìíịỉĩ': 'i',
    'òóọỏõôồốộổỗơờớợởỡ': 'o',
    'ùúụủũưừứựửữ': 'u',
    'ỳýỵỷỹ': 'y',
    'đ': 'd',
  };

  var value = title.toLowerCase();
  for (final entry in vietnamese.entries) {
    for (final character in entry.key.split('')) {
      value = value.replaceAll(character, entry.value);
    }
  }

  return value
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}

/// ID đảm bảo truy vấn đúng bài, còn slug giúp URL dễ đọc.
String postDetailPath({required String id, required String title}) {
  final slug = postSlug(title);
  return slug.isEmpty ? '/posts/$id' : '/posts/$id/$slug';
}
