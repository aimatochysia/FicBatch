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

  // Layout constants for compact mode (mobile-style navigation)
  static const double _compactModeBreakpoint = 600;
  static const double _compactButtonSize = 36;
  static const double _compactIconSize = 20;

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
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use compact navigation buttons on smaller screens (like phone browsers)
        final isCompact = constraints.maxWidth < _compactModeBreakpoint;
        
        return Row(
          children: [
            // Compact navigation cluster (like mobile browser)
            _buildNavigationButtons(context, isCompact),
            SizedBox(width: isCompact ? 4 : 8),
            
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
            SizedBox(width: isCompact ? 4 : 8),
            IconButton(
              icon: const Icon(Icons.save_alt),
              tooltip: 'Save to Library',
              onPressed: onSaveToLibrary,
            ),
          ],
        );
      },
    );
  }

  /// Build navigation buttons - compact on small screens like mobile browsers
  Widget _buildNavigationButtons(BuildContext context, bool isCompact) {
    if (isCompact) {
      // Compact mode: use smaller icons with minimal padding, tightly grouped
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _compactIconButton(Icons.arrow_back, 'Back', onBack),
            _compactIconButton(Icons.arrow_forward, 'Forward', onForward),
            _compactIconButton(Icons.refresh, 'Refresh', onRefresh),
            _compactIconButton(Icons.home, 'Home', onHome),
          ],
        ),
      );
    } else {
      // Standard mode: regular icon buttons
      return Row(
        mainAxisSize: MainAxisSize.min,
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
        ],
      );
    }
  }

  /// Build a compact icon button for mobile-style navigation
  Widget _compactIconButton(IconData icon, String tooltip, VoidCallback onPressed) {
    return SizedBox(
      width: _compactButtonSize,
      height: _compactButtonSize,
      child: IconButton(
        icon: Icon(icon, size: _compactIconSize),
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
    );
  }
}
