import 'package:flutter/material.dart';
import 'package:flutter_neumorphic/flutter_neumorphic.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../services/storage_service.dart';
import '../services/library_service.dart';

class SettingsScreen extends StatelessWidget {
  static const route = '/settings';
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsService>();
    final storage = context.read<StorageService?>();
    final lib = context.read<LibraryService>();

    return NeumorphicBackground(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Dark Mode'),
            value: s.darkMode,
            onChanged: (v) => s.setDarkMode(v),
          ),
          SwitchListTile(
            title: const Text('Global autosave position'),
            value: s.autosaveEnabled,
            onChanged: (v) => s.setAutosaveEnabled(v),
          ),
          ListTile(
            title: const Text('Autosave interval'),
            subtitle: Text('${s.autosaveSeconds} seconds'),
            trailing: DropdownButton<int>(
              value: s.autosaveSeconds,
              items: const [5,10,15,20,30,60].map((e)=>DropdownMenuItem(value:e, child: Text('$e s'))).toList(),
              onChanged: (v) => s.setAutosaveSeconds(v ?? s.autosaveSeconds),
            ),
          ),
          ListTile(
            title: const Text('Global reader font size'),
            subtitle: Text('${(s.readerFontScale*100).toStringAsFixed(0)} %'),
          ),
          ListTile(
            title: const Text('Library folder'),
            subtitle: Text(s.libraryFolder ?? 'Resolving…'),
            trailing: ElevatedButton(
              onPressed: () async {
                final newDir = await context.read<StorageService>().pickDirectory();
                if (newDir != null) {
                  await lib.rescan();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Using folder: $newDir')));
                }
              },
              child: const Text('Change'),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () async {
              await lib.rescan();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rescanned library')));
            },
            child: const Text('Rescan Library Now'),
          ),
        ],
      ),
    );
  }
}
