import 'package:flutter/material.dart';
import 'package:flutter_neumorphic/flutter_neumorphic.dart';
import 'package:provider/provider.dart';
import '../services/download_service.dart';
import '../services/history_service.dart';

class DashboardScreen extends StatefulWidget {
  static const route = '/dashboard';
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _controller = TextEditingController();
  bool _downloading = false;

  @override
  Widget build(BuildContext context) {
    final downloader = context.watch<DownloadService>();
    final history = context.watch<HistoryService>();

    return NeumorphicBackground(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Row(
              children: [
                Expanded(
                  child: Neumorphic(
                    style: const NeumorphicStyle(depth: -4),
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.all(12),
                        hintText: 'Enter work IDs or URLs (any separators ok)',
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _startDownload(downloader),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                NeumorphicButton(
                  onPressed: () => _startDownload(downloader),
                  style: const NeumorphicStyle(depth: 4, intensity: 0.9),
                  child: const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Icon(Icons.download),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_downloading) const LinearProgressIndicator(minHeight: 4),
            const SizedBox(height: 12),
            Text('Queue', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...downloader.queue.map((t) => Neumorphic(
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(child: Text('ID: ${t.id}')),
                  Text(t.status.toUpperCase()),
                  if (t.error != null) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.error, color: Colors.red),
                  ]
                ],
              ),
            )),
            const SizedBox(height: 16),
            Text('Recent Activity', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...history.logs.take(12).map((e) => Neumorphic(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.all(10),
              style: const NeumorphicStyle(depth: -2),
              child: Text(e.message),
            )),
          ],
        ),
      ),
    );
  }

  void _startDownload(DownloadService downloader) async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _downloading = true);
    await downloader.addFromInput(text);
    setState(() => _downloading = false);
    _controller.clear();
    FocusScope.of(context).unfocus();
  }
}
