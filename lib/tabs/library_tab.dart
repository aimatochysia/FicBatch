import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/work_repository.dart';

class LibraryTab extends ConsumerWidget {
  const LibraryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(workRepositoryProvider);
    final works = repo.allLocalWorks();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Library'),
            const SizedBox(height: 8),
            Expanded(
              child: GridView.builder(
                itemCount: works.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
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
                          Text(
                            'by ${w.author}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                onPressed: () {},
                                icon: const Icon(Icons.more_vert),
                              ),
                            ],
                          ),
                        ],
                      ),
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
}
