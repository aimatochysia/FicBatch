import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/storage_provider.dart';
import '../repositories/work_repository.dart';
import '../services/download_service.dart';
import '../services/library_export_service.dart';
import '../models/work.dart';
import 'reader_screen.dart';
import 'settings_tab.dart';

class LibraryTab extends ConsumerStatefulWidget {
  const LibraryTab({super.key});

  @override
  ConsumerState<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends ConsumerState<LibraryTab> {
  bool _isDownloading = false;
  String _downloadProgress = '';
  
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
                    tabs: tabs.map((c) => Tab(text: c)).toList(),
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

  Widget _buildCategoryContent(String category, List<Work> works, List<Work> allWorks) {
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

  Widget _grid(List works) {
    // Get the grid columns setting
    final settingsColumns = ref.watch(libraryGridColumnsProvider);
    
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
        
        return GridView.builder(
          itemCount: works.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
          ),
          itemBuilder: (context, i) {
            final w = works[i];
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
                // Long press to edit categories (alternative for compact mode)
                onLongPress: () => _editCategoriesForWork(context, w.id),
                child: Padding(
                  padding: EdgeInsets.all(isCompact ? 6.0 : 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        w.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isCompact ? 13 : 14,
                        ),
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
                      // Hide action buttons on compact screens (use long press instead)
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
          },
        );
      },
    );
  }
}
