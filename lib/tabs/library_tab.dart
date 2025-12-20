import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/storage_provider.dart';
import '../repositories/work_repository.dart';
import '../services/download_service.dart';
import '../services/library_export_service.dart';
import '../services/sync_service.dart';
import '../models/work.dart';
import 'reader_screen.dart';
import 'settings_tab.dart' show libraryGridColumnsProvider, libraryViewModeProvider, LibraryViewMode;

class LibraryTab extends ConsumerStatefulWidget {
  const LibraryTab({super.key});

  @override
  ConsumerState<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends ConsumerState<LibraryTab> {
  bool _isDownloading = false;
  String _downloadProgress = '';
  bool _isSyncing = false;
  
  Future<void> _syncCategory(String category, List<Work> works) async {
    if (_isSyncing || works.isEmpty) return;
    
    setState(() => _isSyncing = true);
    
    try {
      final syncService = SyncService();
      final updates = await syncService.performSync();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(updates.isEmpty 
                ? 'No updates found in $category' 
                : 'Found ${updates.length} update(s)'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }
  
  Future<void> _downloadWork(Work work) async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 'Downloading ${work.title}...';
    });
    
    try {
      final path = await DownloadService.downloadWork(work.id);
      
      if (path != null) {
        // Update work status in storage
        final storage = ref.read(storageProvider);
        final updatedWork = work.copyWith(
          isDownloaded: true,
          downloadedAt: DateTime.now(),
        );
        await storage.saveWork(updatedWork);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Downloaded "${work.title}"')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to download "${work.title}"')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = '';
        });
      }
    }
  }
  
  Future<void> _downloadCategory(String category, List<Work> works) async {
    if (works.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No works to download in this category')),
      );
      return;
    }
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Download Category'),
        content: Text('Download ${works.length} work(s) from "$category"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Download'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    setState(() {
      _isDownloading = true;
      _downloadProgress = 'Starting download...';
    });
    
    try {
      int downloaded = 0;
      int failed = 0;
      
      for (int i = 0; i < works.length; i++) {
        final work = works[i];
        
        if (mounted) {
          setState(() {
            _downloadProgress = 'Downloading ${i + 1}/${works.length}: ${work.title}';
          });
        }
        
        final path = await DownloadService.downloadWork(work.id);
        
        if (path != null) {
          downloaded++;
          // Update work status
          final storage = ref.read(storageProvider);
          final updatedWork = work.copyWith(
            isDownloaded: true,
            downloadedAt: DateTime.now(),
          );
          await storage.saveWork(updatedWork);
        } else {
          failed++;
        }
        
        // Throttle downloads
        if (i < works.length - 1) {
          await Future.delayed(const Duration(milliseconds: 1000));
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded $downloaded work(s)${failed > 0 ? ', $failed failed' : ''}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = '';
        });
      }
    }
  }

  Future<void> _showCategoryOptionsDialog(String category, List<Work> works) async {
    final storage = ref.read(storageProvider);
    final exportService = LibraryExportService(storage);
    final isAutoDownload = await exportService.isCategoryAutoDownload(category);
    
    if (!mounted) return;
    
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Category: $category'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('Download All'),
                subtitle: Text('${works.length} work(s)'),
                onTap: () {
                  Navigator.pop(ctx);
                  _downloadCategory(category, works);
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.sync),
                title: const Text('Auto-Download'),
                subtitle: const Text('Download new/updated works'),
                value: isAutoDownload,
                onChanged: (value) async {
                  await exportService.setCategoryAutoDownload(category, value);
                  setDialogState(() {});
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editCategoriesForWork(BuildContext context, String workId) async {
    final storage = ref.read(storageProvider);
    final allCats = List<String>.from(await storage.getCategories());
    final selected = Set<String>.from(await storage.getCategoriesForWork(workId));
    final newCatCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Categories'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (allCats.isEmpty)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('No categories yet. Add one below.'),
                  ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: allCats.map((c) {
                      final checked = selected.contains(c);
                      return CheckboxListTile(
                        dense: true,
                        title: Text(c),
                        value: checked,
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              selected.add(c);
                            } else {
                              selected.remove(c);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
                const Divider(),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: newCatCtrl,
                        decoration: const InputDecoration(
                          labelText: 'New category',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        final name = newCatCtrl.text.trim();
                        if (name.isEmpty) return;
                        await storage.addCategory(name);
                        setState(() {
                          allCats.add(name);
                          selected.add(name);
                          newCatCtrl.clear();
                        });
                      },
                      child: const Text('Add'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                await storage.setCategoriesForWork(workId, selected);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    newCatCtrl.dispose();
  }

  Future<void> _showAddCategoryDialog(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Category'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Category Name',
            hintText: 'Enter category name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final storage = ref.read(storageProvider);
      await storage.addCategory(result);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added category "$result"')),
        );
      }
    }
    controller.dispose();
  }

  Future<void> _showManageCategoriesDialog(BuildContext context) async {
    final storage = ref.read(storageProvider);
    final cats = await storage.getCategories();

    if (cats.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No categories to manage')),
        );
      }
      return;
    }

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Manage Categories'),
          content: SizedBox(
            width: 400,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: cats.length,
              itemBuilder: (context, index) {
                final cat = cats[index];
                return ListTile(
                  title: Text(cat),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () async {
                          final controller = TextEditingController(text: cat);
                          final newName = await showDialog<String>(
                            context: context,
                            builder: (ctx2) => AlertDialog(
                              title: const Text('Rename Category'),
                              content: TextField(
                                controller: controller,
                                decoration: const InputDecoration(
                                  labelText: 'New Name',
                                ),
                                autofocus: true,
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx2),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx2, controller.text.trim()),
                                  child: const Text('Rename'),
                                ),
                              ],
                            ),
                          );
                          controller.dispose();

                          if (newName != null && newName.isNotEmpty && newName != cat) {
                            await storage.renameCategory(cat, newName);
                            setState(() {
                              cats[index] = newName;
                            });
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx2) => AlertDialog(
                              title: const Text('Delete Category'),
                              content: Text('Delete category "$cat"? Works will not be deleted.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx2, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx2, true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            await storage.deleteCategory(cat);
                            setState(() {
                              cats.removeAt(index);
                            });
                          }
                        },
                      ),
                    ],
                  ),
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
      ),
    );
  }

  Future<void> _showSortCategoriesDialog(BuildContext context) async {
    final storage = ref.read(storageProvider);
    var cats = List<String>.from(await storage.getCategories());

    if (cats.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No categories to sort')),
        );
      }
      return;
    }

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Sort Categories'),
          content: SizedBox(
            width: 400,
            child: ReorderableListView.builder(
              shrinkWrap: true,
              itemCount: cats.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (oldIndex < newIndex) {
                    newIndex -= 1;
                  }
                  final item = cats.removeAt(oldIndex);
                  cats.insert(newIndex, item);
                });
              },
              itemBuilder: (context, index) {
                final cat = cats[index];
                return ListTile(
                  key: ValueKey(cat),
                  leading: const Icon(Icons.drag_handle),
                  title: Text(cat),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                // Save the new order
                await storage.settingsBox.put('categories_list', cats);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Categories reordered')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final worksAsync = ref.watch(workListProvider);
    final catsAsync = ref.watch(categoriesProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: catsAsync.when(
          data: (cats) {
            final tabs = <String>['All', ...cats];
            return DefaultTabController(
              length: tabs.length,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Library', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        onSelected: (value) async {
                          if (value == 'add') {
                            await _showAddCategoryDialog(context);
                          } else if (value == 'manage') {
                            await _showManageCategoriesDialog(context);
                          } else if (value == 'sort') {
                            await _showSortCategoriesDialog(context);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'add',
                            child: Row(
                              children: [
                                Icon(Icons.add),
                                SizedBox(width: 8),
                                Text('Add Category'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'manage',
                            child: Row(
                              children: [
                                Icon(Icons.edit),
                                SizedBox(width: 8),
                                Text('Manage Categories'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'sort',
                            child: Row(
                              children: [
                                Icon(Icons.sort),
                                SizedBox(width: 8),
                                Text('Sort Categories'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Download progress indicator
                  if (_isDownloading)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_downloadProgress, style: const TextStyle(fontSize: 12))),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  TabBar(
                    isScrollable: true,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                    tabs: tabs.map((c) {
                      // Wrap each tab in a GestureDetector for long-press download
                      return GestureDetector(
                        onLongPress: c == 'All' ? null : () {
                          // Get works for this category and show download dialog
                          _showCategoryLongPressMenu(context, c);
                        },
                        child: Tab(text: c),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: TabBarView(
                      children: tabs.map((cat) {
                        return worksAsync.when(
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (e, _) => Center(child: Text('Error: $e')),
                          data: (allWorks) {
                            if (cat == 'All') {
                              return _buildCategoryContent(cat, allWorks, allWorks);
                            }
                            final idsAsync = ref.watch(categoryWorksProvider(cat));
                            return idsAsync.when(
                              loading: () => const Center(child: CircularProgressIndicator()),
                              error: (e, _) => Center(child: Text('Error: $e')),
                              data: (ids) {
                                final filtered = allWorks.where((w) => ids.contains(w.id)).toList();
                                return _buildCategoryContent(cat, filtered, allWorks);
                              },
                            );
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }
  
  Future<void> _showCategoryLongPressMenu(BuildContext context, String category) async {
    // Get works for this category
    final storage = ref.read(storageProvider);
    final ids = await storage.getWorkIdsForCategory(category);
    final allWorks = await storage.getAllWorks();
    final works = allWorks.where((w) => ids.contains(w.id)).toList();
    
    if (!context.mounted) return;
    
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.download),
              title: Text('Download All (${works.length})'),
              subtitle: Text('Download all works in "$category"'),
              onTap: () {
                Navigator.pop(ctx);
                _downloadCategory(category, works);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Category Options'),
              onTap: () {
                Navigator.pop(ctx);
                _showCategoryOptionsDialog(category, works);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryContent(String category, List<Work> works, List<Work> allWorks) {
    final isMobile = Platform.isAndroid || Platform.isIOS;
    
    Widget buildGrid() {
      return Column(
        children: [
          // Category action bar (only for specific categories, not 'All')
          if (category != 'All')
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _isDownloading ? null : () => _downloadCategory(category, works),
                    icon: const Icon(Icons.download, size: 16),
                    label: Text('Download All (${works.length})'),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _isSyncing ? null : () => _syncCategory(category, works),
                    icon: _isSyncing 
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync),
                    tooltip: 'Sync updates',
                  ),
                  IconButton(
                    onPressed: () => _showCategoryOptionsDialog(category, works),
                    icon: const Icon(Icons.settings),
                    tooltip: 'Category Options',
                  ),
                ],
              ),
            ),
          Expanded(child: _grid(works)),
        ],
      );
    }
    
    // Wrap with RefreshIndicator for mobile
    if (isMobile) {
      return RefreshIndicator(
        onRefresh: () => _syncCategory(category, works),
        child: buildGrid(),
      );
    }
    
    return buildGrid();
  }

  Widget _grid(List works) {
    // Get the grid columns setting
    final settingsColumns = ref.watch(libraryGridColumnsProvider);
    final viewMode = ref.watch(libraryViewModeProvider);
    
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive grid: use user setting, but fewer columns on smaller screens
        final isCompact = constraints.maxWidth < 600;
        // On compact screens, use minimum of 2 or the setting (max 3 for compact)
        // On larger screens, use the user's setting
        final crossAxisCount = isCompact 
            ? (settingsColumns > 3 ? 2 : settingsColumns).clamp(1, 3)
            : settingsColumns;
        final childAspectRatio = isCompact ? 0.8 : 0.7;
        
        // Use list view mode
        if (viewMode == LibraryViewMode.list) {
          return ListView.builder(
            itemCount: works.length,
            itemBuilder: (context, i) => _buildWorkListItem(context, works[i], isCompact),
          );
        }
        
        // Grid view mode (default)
        return GridView.builder(
          itemCount: works.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
          ),
          itemBuilder: (context, i) => _buildWorkGridItem(context, works[i], isCompact),
        );
      },
    );
  }
  
  /// Show context menu for long-press on work card
  Future<void> _showWorkContextMenu(BuildContext context, Work work) async {
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                work.isDownloaded ? Icons.download_done : Icons.download,
                color: work.isDownloaded ? Colors.green : null,
              ),
              title: Text(work.isDownloaded ? 'Re-download' : 'Download'),
              subtitle: work.isDownloaded 
                  ? const Text('Work is already downloaded') 
                  : const Text('Download for offline reading'),
              onTap: () {
                Navigator.pop(ctx);
                _downloadWork(work);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('Edit Categories'),
              onTap: () {
                Navigator.pop(ctx);
                _editCategoriesForWork(context, work.id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Remove from Library'),
              onTap: () async {
                Navigator.pop(ctx);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx2) => AlertDialog(
                    title: const Text('Remove Work'),
                    content: Text('Remove "${work.title}" from your library?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx2, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx2, true),
                        child: const Text('Remove'),
                      ),
                    ],
                  ),
                );
                if (confirm == true && context.mounted) {
                  final storage = ref.read(storageProvider);
                  await storage.deleteWork(work.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Removed "${work.title}"')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
  
  /// Build a work card for grid view
  Widget _buildWorkGridItem(BuildContext context, Work w, bool isCompact) {
    return Card(
      child: InkWell(
        onTap: () async {
          // Add to history
          final storage = ref.read(storageProvider);
          await storage.addToHistory(
            workId: w.id,
            title: w.title,
            author: w.author,
          );
          
          if (context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ReaderScreen(work: w),
              ),
            );
          }
        },
        // Long press to show context menu (works on all screens including mobile)
        onLongPress: () => _showWorkContextMenu(context, w),
        child: Padding(
          padding: EdgeInsets.all(isCompact ? 6.0 : 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      w.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isCompact ? 13 : 14,
                      ),
                    ),
                  ),
                  // Download indicator (always visible)
                  if (w.isDownloaded)
                    const Icon(Icons.download_done, size: 16, color: Colors.green),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'by ${w.author}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: isCompact ? 11 : 12),
              ),
              const SizedBox(height: 4),
              if ((w.summary ?? '').isNotEmpty)
                Text(
                  w.summary!,
                  maxLines: isCompact ? 2 : 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: isCompact ? 10 : 12),
                ),
              const Spacer(),
              // Action buttons on larger screens
              if (!isCompact)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Download button
                    IconButton(
                      onPressed: _isDownloading ? null : () => _downloadWork(w),
                      icon: Icon(
                        w.isDownloaded ? Icons.download_done : Icons.download,
                        color: w.isDownloaded ? Colors.green : null,
                      ),
                      tooltip: w.isDownloaded ? 'Downloaded' : 'Download',
                    ),
                    IconButton(
                      onPressed: () => _editCategoriesForWork(context, w.id),
                      icon: const Icon(Icons.folder_open),
                      tooltip: 'Edit Categories',
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// Build a work item for list view
  Widget _buildWorkListItem(BuildContext context, Work w, bool isCompact) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: InkWell(
        onTap: () async {
          // Add to history
          final storage = ref.read(storageProvider);
          await storage.addToHistory(
            workId: w.id,
            title: w.title,
            author: w.author,
          );
          
          if (context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ReaderScreen(work: w),
              ),
            );
          }
        },
        // Long press to show context menu
        onLongPress: () => _showWorkContextMenu(context, w),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // Download status indicator
              if (w.isDownloaded)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.download_done, size: 18, color: Colors.green),
                ),
              // Work info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      w.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'by ${w.author}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color),
                    ),
                  ],
                ),
              ),
              // Word count
              if (w.wordsCount != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    '${w.wordsCount} words',
                    style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color),
                  ),
                ),
              // More options button
              IconButton(
                onPressed: () => _showWorkContextMenu(context, w),
                icon: const Icon(Icons.more_vert, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
