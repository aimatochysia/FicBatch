import 'package:flutter/material.dart';

class BrowseToolbar extends StatelessWidget {
  final TextEditingController urlController;
  final VoidCallback onHome;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onRefresh; 
  final VoidCallback onQuickSearch;
  final VoidCallback onAdvancedSearch;
  final VoidCallback onSaveCurrentSearch;
  final VoidCallback onLoadSavedSearch;
  final VoidCallback onSaveToLibrary;

  const BrowseToolbar({
    super.key,
    required this.urlController,
    required this.onHome,
    required this.onBack,
    required this.onForward,
    required this.onRefresh, 
    required this.onQuickSearch,
    required this.onAdvancedSearch,
    required this.onSaveCurrentSearch,
    required this.onLoadSavedSearch,
    required this.onSaveToLibrary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        
        IconButton(
          icon: const Icon(Icons.home),
          tooltip: 'Home',
          onPressed: onHome,
        ),
        IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: onBack,
        ),
        IconButton(
          icon: const Icon(Icons.arrow_forward),
          tooltip: 'Forward',
          onPressed: onForward,
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: onRefresh,
        ),
        const SizedBox(width: 8),
        
        Expanded(
          child: TextField(
            controller: urlController,
            decoration: InputDecoration(
              hintText: 'Search AO3 works...',
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.search),
                    tooltip: 'Quick Search',
                    onPressed: onQuickSearch,
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.arrow_drop_down),
                    tooltip: 'More search options',
                    onSelected: (v) {
                      if (v == 'quick') onQuickSearch();
                      if (v == 'advanced') onAdvancedSearch();
                    },
                    itemBuilder: (ctx) => const [
                      PopupMenuItem(
                        value: 'quick',
                        child: Text('Quick Search'),
                      ),
                      PopupMenuItem(
                        value: 'advanced',
                        child: Text('Advanced Search'),
                      ),
                    ],
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.bookmark_add),
                    tooltip: 'Save Current Search',
                    onPressed: onSaveCurrentSearch,
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.arrow_drop_down),
                    tooltip: 'Bookmarks',
                    onSelected: (v) {
                      if (v == 'save') onSaveCurrentSearch();
                      if (v == 'load') onLoadSavedSearch();
                    },
                    itemBuilder: (ctx) => const [
                      PopupMenuItem(
                        value: 'save',
                        child: Text('Save Current Search'),
                      ),
                      PopupMenuItem(
                        value: 'load',
                        child: Text('Load Saved Search'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            onSubmitted: (_) => onQuickSearch(),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.save_alt),
          tooltip: 'Save to Library',
          onPressed: onSaveToLibrary,
        ),
      ],
    );
  }
}
