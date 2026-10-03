import 'package:web/web.dart' as web;

import '../utils/seo.dart';

void applySeoMeta(SeoMeta meta) {
  final document = web.document;
  document.title = meta.fullTitle;

  for (final tag in meta.tags) {
    final selector = 'meta[${tag.attribute}="${tag.key}"]';
    var element =
        document.head?.querySelector(selector) as web.HTMLMetaElement?;
    if (element == null) {
      element = document.createElement('meta') as web.HTMLMetaElement;
      element.setAttribute(tag.attribute, tag.key);
      document.head?.append(element);
    }
    element.content = tag.content;
  }

  var canonical =
      document.head?.querySelector('link[rel="canonical"]')
          as web.HTMLLinkElement?;
  if (canonical == null) {
    canonical = document.createElement('link') as web.HTMLLinkElement;
    canonical.rel = 'canonical';
    document.head?.append(canonical);
  }
  canonical.href = meta.canonicalUrl;
}
