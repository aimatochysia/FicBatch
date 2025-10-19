import '../../models/work.dart';
import '../../models/reading_progress.dart';

typedef JsonRunner = Future<T?> Function<T>(String jsJsonExpr);

Future<Map<String, dynamic>?> fetchAo3MetaCombined(JsonRunner getJson) async {
  const js = r'''
    (function(){
      function text(sel){
        var el = document.querySelector(sel);
        return el ? (el.textContent || '').trim() : '';
      }
      function inner(sel){
        var el = document.querySelector(sel);
        return el ? (el.innerText || '').trim() : '';
      }
      function collectTags(){
        var out = {};
        var root = document.querySelector('dl.work.meta.group');
        if (!root) return out;
        var dts = root.querySelectorAll('dt');
        dts.forEach(function(dt){
          var key = (dt.className || '').split(' ')[0];
          var dd = dt.nextElementSibling;
          if (!dd) return;
          if (key === 'language') {
            out.language = (dd.textContent || '').trim();
            return;
          }
          if (key === 'stats') return;
          var tags = Array.prototype.slice.call(dd.querySelectorAll('a.tag'))
            .map(function(a){ return (a.textContent || '').trim(); })
            .filter(Boolean);
          if (tags.length) out[key] = tags;
        });
        return out;
      }
      function collectStats(){
        var o = {};
        var stats = document.querySelector('dl.stats');
        if (!stats) return o;
        function grab(cls){
          var dd = stats.querySelector('dd.' + cls);
          return dd ? (dd.textContent || '').trim() : '';
        }
        o.published = grab('published');
        o.updated = grab('status') || grab('updated');
        o.words = grab('words');
        o.chapters = grab('chapters');
        o.kudos = grab('kudos');
        o.hits = grab('hits');
        o.comments = grab('comments');
        return o;
      }
      return {
        title: text('h2.title.heading'),
        author: text('h3.byline.heading a[rel="author"]'),
        summary: inner('div.summary.module blockquote.userstuff'),
        tags: collectTags(),
        stats: collectStats()
      };
    })()
  ''';
  return await getJson<Map<String, dynamic>>(js);
}

Work buildWorkFromMeta(String workId, Map<String, dynamic> meta) {
  String s(String? v) => (v ?? '').trim();
  int? toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    final t = v.toString().replaceAll(',', '').replaceAll('.', '').trim();
    final m = RegExp(r'\d+').firstMatch(t);
    return m != null ? int.tryParse(m.group(0)!) : null;
  }

  int? chapterCount(dynamic v) {
    if (v == null) return null;
    final m = RegExp(r'(\d+)').firstMatch(v.toString());
    return m != null ? int.tryParse(m.group(1)!) : null;
  }

  DateTime? toDate(dynamic v) {
    if (v == null) return null;
    try {
      return DateTime.parse(v.toString());
    } catch (_) {
      return null;
    }
  }

  final stats = Map<String, dynamic>.from(meta['stats'] ?? {});
  final tagsMap = Map<String, dynamic>.from(meta['tags'] ?? {});
  final allTags = <String>[];
  for (final e in tagsMap.entries) {
    if (e.value is List) allTags.addAll(List<String>.from(e.value));
  }

  return Work(
    id: workId,
    title: s(meta['title']).isNotEmpty ? s(meta['title']) : 'Untitled Work',
    author: s(meta['author']).isNotEmpty ? s(meta['author']) : 'Unknown Author',
    tags: allTags,
    userAddedDate: DateTime.now(),
    publishedAt: toDate(stats['published']),
    updatedAt: toDate(stats['updated']),
    wordsCount: toInt(stats['words']),
    chaptersCount: chapterCount(stats['chapters']),
    kudosCount: toInt(stats['kudos']),
    hitsCount: toInt(stats['hits']),
    commentsCount: toInt(stats['comments']),
    readingProgress: ReadingProgress.empty(),
    summary: s(meta['summary']).isNotEmpty ? s(meta['summary']) : null,
  );
}
