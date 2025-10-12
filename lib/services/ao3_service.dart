import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

class Ao3Service {
  final http.Client httpClient;

  Ao3Service({http.Client? client}) : httpClient = client ?? http.Client();

  Future<Map<String, dynamic>> fetchWorkMetadata(String workIdOrUrl) async {
    final url = _normalizeWorkUrl(workIdOrUrl);
    final resp = await httpClient.get(Uri.parse(url));
    if (resp.statusCode != 200) throw Exception('Failed to fetch work');

    final doc = html_parser.parse(resp.body);

    final title = doc.querySelector('h2.title')?.text.trim() ?? 'Unknown title';
    final author =
        doc.querySelector('a[rel="author"]')?.text.trim() ?? 'Unknown author';

    return {'title': title, 'author': author, 'rawHtml': resp.body};
  }

  String cleanWorkHtml(String rawHtml) {
    final doc = html_parser.parse(rawHtml);

    doc
        .querySelectorAll('script, header, footer, nav')
        .forEach((e) => e.remove());

    doc
        .querySelectorAll('.header, .footer, .social, .admin-tools')
        .forEach((e) => e.remove());

    doc.querySelectorAll('img').forEach((img) {
      img.attributes['style'] = 'max-width:100%;height:auto;';
    });
    return doc.outerHtml;
  }

  String _normalizeWorkUrl(String input) {
    if (input.startsWith('http')) return input;
    if (input.startsWith('/works/')) return 'https://archiveofourown.org$input';
    return 'https://archiveofourown.org/works/$input';
  }
}
