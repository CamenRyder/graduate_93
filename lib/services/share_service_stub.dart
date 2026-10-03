bool canShareNatively() => false;

Future<bool> shareNatively({
  required String title,
  required String url,
}) async => false;

void openWindow(String url) {}
