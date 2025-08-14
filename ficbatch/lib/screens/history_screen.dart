import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:provider/provider.dart';
import '../services/history_service.dart';
import '../models.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  static const route = '/history';
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _query = '';
  LogKind? _kind;
  bool _desc = true;
  final _fmt = DateFormat('yyyy-MM-dd HH:mm:ss');

  @override
  Widget build(BuildContext context) {
    final history = context.watch<HistoryService>();
    var logs = history.logs.where((e) {
      final matchKind = _kind == null || e.kind == _kind;
      final matchQuery = _query.isEmpty ||
          (e.message.toLowerCase().contains(_query.toLowerCase()));
      return matchKind && matchQuery;
    }).toList();
    logs.sort((a, b) => _desc ? b.at.compareTo(a.at) : a.at.compareTo(b.at));

    return NeumorphicBackground(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(children: [
              Expanded(
                child: Neumorphic(
                  style: const NeumorphicStyle(depth: -4),
                  child: TextField(
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Filter by title/id/message…',
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<LogKind?>(
                value: _kind,
                items: [
                  const DropdownMenuItem(value: null, child: Text('All')),
                  ...LogKind.values
                      .map((k) => DropdownMenuItem(
                          value: k, child: Text(logKindLabel(k))))
                      .toList(),
                ],
                onChanged: (v) => setState(() => _kind = v),
              ),
              IconButton(
                icon: Icon(_desc ? Icons.arrow_downward : Icons.arrow_upward),
                onPressed: () => setState(() => _desc = !_desc),
              ),
              TextButton(
                onPressed: () => context.read<HistoryService>().clear(),
                child: const Text('Clear'),
              )
            ]),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: logs.length,
                itemBuilder: (_, i) {
                  final e = logs[i];
                  return Neumorphic(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(12),
                    style: const NeumorphicStyle(depth: -2),
                    child: Row(
                      children: [
                        SizedBox(
                            width: 90,
                            child: Text(_fmt.format(e.at),
                                style: const TextStyle(fontFeatures: []))),
                        const SizedBox(width: 8),
                        Text('[${logKindLabel(e.kind)}]'),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(e.message,
                                overflow: TextOverflow.ellipsis)),
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
}
