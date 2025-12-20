import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/storage_provider.dart';
import '../repositories/work_repository.dart';
import '../services/ao3_service.dart';
import '../services/batch_import_service.dart';
import '../services/library_export_service.dart';

class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({super.key});

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> {
  final _controller = TextEditingController();
  final _batchController = TextEditingController();
  bool _isAdding = false;
  bool _isBatchImporting = false;
  int _parsedCount = 0;
  String _importProgress = '';

  @override
  void dispose() {
    _controller.dispose();
    _batchController.dispose();
    super.dispose();
  }

  void _updateParsedCount() {
    final storage = ref.read(storageProvider);
    final exportService = LibraryExportService(storage);
    final batchService = BatchImportService(storage, Ao3Service(), exportService);
    setState(() {
      _parsedCount = batchService.validateInput(_batchController.text);
    });
  }

  Future<void> _batchImport() async {
    if (_batchController.text.trim().isEmpty) return;
    
    final storage = ref.read(storageProvider);
    final exportService = LibraryExportService(storage);
    final batchService = BatchImportService(storage, Ao3Service(), exportService);
    
    setState(() {
      _isBatchImporting = true;
      _importProgress = 'Starting import...';
    });
    
    try {
      final result = await batchService.importWorks(
        _batchController.text,
        onProgress: (current, total, title) {
          if (mounted) {
            setState(() {
              _importProgress = 'Importing $current of $total${title != null ? ': $title' : ''}';
            });
          }
        },
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import complete: ${result.toSummary()}'),
            duration: const Duration(seconds: 4),
          ),
        );
        _batchController.clear();
        setState(() {
          _parsedCount = 0;
          _importProgress = '';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBatchImporting = false;
          _importProgress = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Single work input section
            const Text(
              'Add Single Work',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Enter AO3 work ID or URL'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'e.g. 123456 or /works/123456 or full URL',
                      border: OutlineInputBorder(),
                      isDense: true,
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
                              SnackBar(content: Text('Error: $e')),
                            );
                          } finally {
                            setState(() => _isAdding = false);
                          }
                        },
                  child: _isAdding 
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Add'),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            
            // Batch import section
            const Text(
              'Batch Import Works',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Paste multiple AO3 links or work IDs (one per line, or separated by commas/spaces).\n'
              'Works will be added to the default category.',
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _batchController,
              maxLines: 8,
              decoration: InputDecoration(
                hintText: 'https://archiveofourown.org/works/123456\n'
                    'https://archiveofourown.org/works/789012\n'
                    '345678\n'
                    '/works/901234',
                border: const OutlineInputBorder(),
                counterText: _parsedCount > 0 ? '$_parsedCount work(s) detected' : null,
              ),
              onChanged: (_) => _updateParsedCount(),
            ),
            const SizedBox(height: 8),
            if (_importProgress.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_importProgress)),
                  ],
                ),
              ),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isBatchImporting || _parsedCount == 0
                      ? null
                      : _batchImport,
                  icon: _isBatchImporting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download),
                  label: Text(_isBatchImporting 
                      ? 'Importing...' 
                      : 'Import ${_parsedCount > 0 ? '$_parsedCount Works' : 'Works'}'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _batchController.text.isEmpty
                      ? null
                      : () {
                          _batchController.clear();
                          setState(() => _parsedCount = 0);
                        },
                  child: const Text('Clear'),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Info section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Supported URL formats',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Full URL: https://archiveofourown.org/works/123456\n'
                      '• Chapter URL: https://archiveofourown.org/works/123456/chapters/789\n'
                      '• Short path: /works/123456\n'
                      '• Work ID only: 123456',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
