import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_windows/webview_windows.dart' as win;
import '../../services/storage_service.dart';
import '../../widgets/advanced_search.dart';

void performQuickSearch({
  required String searchType,
  required TextEditingController urlController,
  required bool isWindows,
  required win.WebviewController? winController,
  required WebViewController? controller,
  required void Function(String) onUrlChange,
}) {
  final query = urlController.text.trim();
  if (query.isEmpty) return;

  final params = {'work_search[$searchType]': query, 'commit': 'Search'};
  final uri = Uri.https('archiveofourown.org', '/works/search', params);

  onUrlChange(uri.toString());
  if (isWindows) {
    winController?.loadUrl(uri.toString());
  } else {
    controller?.loadRequest(uri);
  }
}

Future<void> openAdvancedSearch({
  required BuildContext context,
  required StorageService storage,
  required bool isWindows,
  required win.WebviewController? winController,
  required WebViewController? controller,
  required void Function(String) onUrlChange,
}) async {
  final lastFilters = await storage.getAdvancedFilters();
  final result = await Navigator.push<Map<String, dynamic>>(
    context,
    MaterialPageRoute(
      builder: (_) => AdvancedSearchScreen(initialFilters: lastFilters),
    ),
  );
  if (result == null) return;

  final url = result['url'] as String?;
  final filters = result['filters'] as Map<String, dynamic>?;
  if (filters != null) await storage.saveAdvancedFilters(filters);

  if (url != null && url.isNotEmpty) {
    onUrlChange(url);
    if (isWindows) {
      await winController?.loadUrl(url);
    } else {
      await controller?.loadRequest(Uri.parse(url));
    }
  }
}

Future<void> saveCurrentSearch({
  required BuildContext context,
  required StorageService storage,
  required Future<String?> Function() getCurrentUrl,
  required String currentUrl,
  required void Function(String) setCurrentUrl,
}) async {
  final live = await getCurrentUrl();
  final current = (live ?? currentUrl).trim();
  setCurrentUrl(current);
  if (current.isEmpty) return;

  if (!_isValidSearchUrl(current)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cannot save a specific work or chapter page.'),
      ),
    );
    return;
  }

  final nameController = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Save Current Search'),
      content: TextField(
        controller: nameController,
        decoration: const InputDecoration(
          hintText: 'Enter a name for this search',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  if (name == null || name.isEmpty) return;

  final filters = await storage.getAdvancedFilters();
  await storage.saveSearch(name, current, filters);
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Saved search "$name"!')));
  }
}

Future<void> showSavedSearchDialog({
  required BuildContext context,
  required List<Map<String, dynamic>> saved,
  required StorageService storage,
  required bool isWindows,
  required win.WebviewController? winController,
  required WebViewController? controller,
  required void Function(String) setCurrentUrl,
}) async {
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Saved Searches'),
      content: saved.isEmpty
          ? const Text('No saved searches yet.')
          : SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: saved.length,
                itemBuilder: (_, i) {
                  final item = saved[i];
                  return ListTile(
                    title: Text(item['name'] ?? 'default'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () async {
                        await storage.deleteSavedSearch(item['name']);
                        Navigator.pop(ctx);
                        final refreshed = await storage.getSavedSearches();
                        if (!context.mounted) return;
                        await showSavedSearchDialog(
                          context: context,
                          saved: refreshed,
                          storage: storage,
                          isWindows: isWindows,
                          winController: winController,
                          controller: controller,
                          setCurrentUrl: setCurrentUrl,
                        );
                      },
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      final url = (item['url'] ?? '') as String;
                      setCurrentUrl(url);
                      if (isWindows) {
                        winController?.loadUrl(url);
                      } else {
                        controller?.loadRequest(Uri.parse(url));
                      }
                    },
                  );
                },
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

bool _isValidSearchUrl(String url) {
  try {
    final u = Uri.parse(url);
    if (u.host != 'archiveofourown.org') return false;
    final segs = u.pathSegments;
    final hasQuery = u.query.isNotEmpty;

    if (segs.length >= 2 && segs.first == 'tags' && segs.last == 'works')
      return true;
    if (segs.length == 1 && segs.first == 'works' && hasQuery) return true;
    if (segs.length >= 2 &&
        segs[0] == 'works' &&
        segs[1] == 'search' &&
        hasQuery)
      return true;

    if (segs.isNotEmpty && segs[0] == 'works') {
      if (segs.length >= 2 && RegExp(r'^\d+$').hasMatch(segs[1])) return false;
      if (segs.length >= 3 && segs[2] == 'chapters') return false;
    }
    return false;
  } catch (_) {
    return false;
  }
}
