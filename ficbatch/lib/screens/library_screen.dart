import 'package:flutter/material.dart';
import 'package:flutter_neumorphic/flutter_neumorphic.dart';
import 'package:provider/provider.dart';
import '../models.dart';
import '../services/library_service.dart';
import 'reader_screen.dart';

class LibraryScreen extends StatefulWidget {
  static const route = '/library';
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _query = '';
  String _sort = 'date';
  String _tagsFilter = '';

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryService>();
    final items = _filteredSorted(library.items);

    return NeumorphicBackground(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Neumorphic(
              style: const NeumorphicStyle(depth: -4),
              child: TextField(
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search by title…',
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(height: 10),
            _buildTagsRow(library),
            const SizedBox(height: 10),
            Row(
              children: [
                DropdownButton<String>(
                  value: _sort,
                  items: const [
                    DropdownMenuItem(value: 'date', child: Text('Sort: Date Added')),
                    DropdownMenuItem(value: 'az', child: Text('Sort: A→Z')),
                    DropdownMenuItem(value: 'za', child: Text('Sort: Z→A')),
                  ],
                  onChanged: (v) => setState(() => _sort = v ?? 'date'),
                ),
                const Spacer(),
                NeumorphicButton(
                  onPressed: () => library.rescan(),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text('Refresh'),
                  ),
                )
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final w = items[i];
                  return Neumorphic(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => Navigator.of(context).pushNamed(
                              ReaderScreen.routeBase,
                              arguments: ReaderScreenArgs(work: w),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(w.title, style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: 4),
                                Text(w.publisher, style: Theme.of(context).textTheme.bodySmall),
                                const SizedBox(height: 6),
                                LinearProgressIndicator(value: w.progress, minHeight: 6),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: -8,
                                  children: w.tags.take(6).map((t) => Chip(label: Text(t), visualDensity: VisualDensity.compact)).toList(),
                                )
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(w.favorite ? Icons.favorite : Icons.favorite_border),
                          onPressed: () {
                            final updated = w.copyWith(favorite: !w.favorite);
                            context.read<LibraryService>().updateWork(updated);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Delete work?'),
                                content: Text('This will delete\n"${w.title}"'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                  TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                                ],
                              ),
                            );
                            if (ok == true) {
                              await context.read<LibraryService>().deleteWork(w);
                            }
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagsRow(LibraryService lib) {
    final tags = lib.allTags();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          FilterChip(
            label: const Text('All tags'),
            selected: _tagsFilter.isEmpty,
            onSelected: (_) => setState(() => _tagsFilter = ''),
          ),
          const SizedBox(width: 8),
          ...tags.map((t) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(t),
              selected: _tagsFilter == t,
              onSelected: (_) => setState(() => _tagsFilter = t),
            ),
          )),
        ],
      ),
    );
  }

  List<WorkItem> _filteredSorted(List<WorkItem> all) {
    var items = all.where((w) {
      final matchesQuery = _query.isEmpty || w.title.toLowerCase().contains(_query.toLowerCase());
      final matchesTag = _tagsFilter.isEmpty || w.tags.contains(_tagsFilter);
      return matchesQuery && matchesTag;
    }).toList();

    switch (_sort) {
      case 'az': items.sort((a,b)=>a.title.toLowerCase().compareTo(b.title.toLowerCase())); break;
      case 'za': items.sort((a,b)=>b.title.toLowerCase().compareTo(a.title.toLowerCase())); break;
      default:   items.sort((a,b)=>b.addedAt.compareTo(a.addedAt)); break;
    }
    return items;
  }
}
