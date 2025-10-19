import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/storage_provider.dart';
import '../repositories/work_repository.dart';

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
                  const Text('Library'),
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
        );
      },
    );
  }
}
