import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/storage_provider.dart';
import '../repositories/work_repository.dart';
import 'reader_screen.dart';

class LibraryTab extends ConsumerStatefulWidget {
  const LibraryTab({super.key});

  @override
  ConsumerState<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends ConsumerState<LibraryTab> {
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
                              return _grid(allWorks);
                            }
                            final idsAsync = ref.watch(categoryWorksProvider(cat));
                            return idsAsync.when(
                              loading: () => const Center(child: CircularProgressIndicator()),
                              error: (e, _) => Center(child: Text('Error: $e')),
                              data: (ids) {
                                final filtered = allWorks.where((w) => ids.contains(w.id)).toList();
                                return _grid(filtered);
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

  Widget _grid(List works) {
    return GridView.builder(
      itemCount: works.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.7,
      ),
      itemBuilder: (context, i) {
        final w = works[i];
        return Card(
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ReaderScreen(work: w),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    w.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text('by ${w.author}', maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  if ((w.summary ?? '').isNotEmpty)
                    Text(
                      w.summary!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () async {
                          final json = const JsonEncoder.withIndent('  ').convert(w.toJson());
                          await showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Work JSON'),
                              content: SizedBox(
                                width: double.maxFinite,
                                child: SingleChildScrollView(child: SelectableText(json)),
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                              ],
                            ),
                          );
                        },
                        icon: const Icon(Icons.code),
                        tooltip: 'Show JSON',
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
  }
}
