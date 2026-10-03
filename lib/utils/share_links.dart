/// Link chia sẻ lên mạng xã hội cho một URL (đã là URL tuyệt đối).
library;

class ShareLinks {
  const ShareLinks({required this.facebook, required this.x});

  final String facebook;
  final String x;
}

ShareLinks shareLinks({required String url, required String title}) {
  return ShareLinks(
    facebook: Uri.https('www.facebook.com', '/sharer/sharer.php', {
      'u': url,
    }).toString(),
    x: Uri.https('twitter.com', '/intent/tweet', {
      'url': url,
      if (title.trim().isNotEmpty) 'text': title.trim(),
    }).toString(),
  );
}
