import 'package:flutter/material.dart';
import '../models/work.dart';

class WorkCard extends StatelessWidget {
  final Work work;
  final VoidCallback? onOpen;

  const WorkCard({super.key, required this.work, this.onOpen});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                work.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(work.author, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              if ((work.summary ?? '').isNotEmpty)
                Flexible(
                  child: Text(
                    work.summary!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const SizedBox(height: 4),
              if (work.tags.isNotEmpty)
                Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  children: work.tags.take(4).map((t) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        t,
                        style: const TextStyle(fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${work.wordsCount ?? '-'} words'),
                  const Icon(Icons.book, size: 16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
