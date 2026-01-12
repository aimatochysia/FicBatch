import 'dart:io' show Platform;
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

  // Layout constants for compact mode (mobile-style)
  static const double _compactModeBreakpoint = 600;
  static const double _compactButtonSize = 32;
  static const double _compactIconSize = 18;
  static const double _compactTextFieldHeight = 36;
  
  // Check if running on mobile platform (Android/iOS)
  static bool get _isMobile => Platform.isAndroid || Platform.isIOS;

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
        // Use compact UI on smaller screens (like phone browsers)
        final isCompact = constraints.maxWidth < _compactModeBreakpoint;
        
        return Row(
          children: [
            // Navigation buttons - hidden on mobile (Android/iOS)
            // Users can use platform's native back gestures or pull-to-refresh
            if (!_isMobile) ...[
              _buildNavigationButtons(context, isCompact),
              SizedBox(width: isCompact ? 2 : 8),
            ],
            
            // Search bar
            Expanded(
              child: SizedBox(
                height: isCompact ? _compactTextFieldHeight : null,
                child: TextField(
                  controller: urlController,
                  style: isCompact ? const TextStyle(fontSize: 13) : null,
                  decoration: InputDecoration(
                    hintText: isCompact ? 'Search...' : 'Search AO3 works...',
                    hintStyle: isCompact ? const TextStyle(fontSize: 13) : null,
                    border: const OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 6 : 8,
                      vertical: isCompact ? 0 : 12,
                    ),
                    isDense: isCompact,
                    suffixIcon: _buildSearchSuffixIcons(context, isCompact),
                  ),
                  onSubmitted: (_) => onQuickSearch(),
                ),
              ),
            ),
            // Save to library button - hidden on mobile (Android/iOS)
            // Works are saved via the injected buttons on listing pages
            if (!_isMobile) ...[
              SizedBox(width: isCompact ? 2 : 8),
              _buildSaveToLibraryButton(isCompact),
            ],
          ],
        );
      },
    );
  }

  /// Build the suffix icons for the search bar
  Widget _buildSearchSuffixIcons(BuildContext context, bool isCompact) {
    if (isCompact) {
      // Compact mode: combine search + more into one popup, bookmark into another
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Search popup (combines quick search + advanced)
          PopupMenuButton<String>(
            icon: Icon(Icons.search, size: _compactIconSize),
            tooltip: 'Search',
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(
              minWidth: _compactButtonSize,
              minHeight: _compactButtonSize,
            ),
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
          // Bookmark popup
          PopupMenuButton<String>(
            icon: Icon(Icons.bookmark, size: _compactIconSize),
            tooltip: 'Bookmarks',
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(
              minWidth: _compactButtonSize,
              minHeight: _compactButtonSize,
            ),
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
      );
    } else {
      // Standard mode: full suffix icons
      return Row(
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
      );
    }
  }

  /// Build the save to library button
  Widget _buildSaveToLibraryButton(bool isCompact) {
    if (isCompact) {
      return SizedBox(
        width: _compactButtonSize,
        height: _compactButtonSize,
        child: IconButton(
          icon: Icon(Icons.save_alt, size: _compactIconSize),
          tooltip: 'Save to Library',
          onPressed: onSaveToLibrary,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      );
    } else {
      return IconButton(
        icon: const Icon(Icons.save_alt),
        tooltip: 'Save to Library',
        onPressed: onSaveToLibrary,
      );
    }
  }

  /// Build navigation buttons - compact on small screens like mobile browsers
  Widget _buildNavigationButtons(BuildContext context, bool isCompact) {
    if (isCompact) {
      // Compact mode: use smaller icons with minimal padding, tightly grouped
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(6),
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
