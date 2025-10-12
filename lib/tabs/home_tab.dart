import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/work_repository.dart';

class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({super.key});

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> {
  final _controller = TextEditingController();
  bool _isAdding = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add AO3 work (ID or URL)'),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'e.g. 123456 or /works/123456 or full URL',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isAdding
                      ? null
                      : () async {
                          final input = _controller.text.trim();
                          if (input.isEmpty) return;
                          setState(() => _isAdding = true);
                          try {
                            final repo = ref.read(workRepositoryProvider);
                            await repo.addFromUrl(input);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Added to library')),
                            );
                            _controller.clear();
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: \$e')),
                            );
                          } finally {
                            setState(() => _isAdding = false);
                          }
                        },
                  child: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Or import from file (OPDS / JSON / AO3 export) - TODO'),
          ],
        ),
      ),
    );
  }
}
