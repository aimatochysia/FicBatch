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
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                work.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(work.author, maxLines: 1),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${work.wordsCount ?? '-'} words'),
                  Icon(Icons.book),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
