import 'package:html/parser.dart' as html;
import 'package:html/dom.dart';

class ParsedHtmlMeta {
  final String title;
  final String publisher;
  final List<String> tags;
  ParsedHtmlMeta({required this.title, required this.publisher, required this.tags});
}

ParsedHtmlMeta extractMeta(String htmlText) {
  try {
    final doc = html.parse(htmlText);

    // <title>...</title>
    final title = (doc.querySelector('title')?.text ?? 'Unknown Title').trim();

    // AO3-ish byline (fallback)
    String publisher = 'Unknown Publisher';
    final byline = doc.querySelector('div.byline a')?.text?.trim();
    if (byline != null && byline.isNotEmpty) publisher = byline;

    // AO3-like tags area
    final tags = <String>{};
    for (final dd in doc.querySelectorAll('dl.tags dd')) {
      final a = dd.querySelector('a');
      if (a != null) tags.add(a.text.trim());
    }

    return ParsedHtmlMeta(title: title, publisher: publisher, tags: tags.toList());
  } catch (_) {
    return ParsedHtmlMeta(title: 'Unknown Title', publisher: 'Unknown Publisher', tags: []);
  }
}

/// Try to find chapters by scanning anchors/headings.
/// Returns list of {title, id} where id is element id to scroll into view.
List<Map<String, String>> findChaptersForWeb(String htmlText) {
  try {
    final doc = html.parse(htmlText);
    final result = <Map<String,String>>[];

    // AO3 uses <h3 class="title"> inside chapters; also #chapters container.
    final candidates = doc.querySelectorAll('#chapters h2, #chapters h3, h2.heading, h3.heading, h2.title, h3.title');
    int idx = 1;
    for (final c in candidates) {
      final t = c.text.trim();
      if (t.isEmpty) continue;
      String id = c.id;
      if (id.isEmpty) {
        id = 'ficbatch_ch_$idx';
        c.id = id;
      }
      result.add({'title': t, 'id': id});
      idx++;
    }
    return result;
  } catch (_) {
    return [];
  }
}
