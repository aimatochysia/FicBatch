import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';

class SettingsTab extends ConsumerWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    final notifier = ref.read(themeProvider.notifier);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: ListView(
          children: [
            ListTile(
              title: const Text('Theme'),
              subtitle: Text(theme.toString()),
              trailing: PopupMenuButton<ThemeMode>(
                onSelected: notifier.setMode,
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: ThemeMode.light,
                    child: Text('Light'),
                  ),
                  const PopupMenuItem(
                    value: ThemeMode.dark,
                    child: Text('Dark'),
                  ),
                  const PopupMenuItem(
                    value: ThemeMode.system,
                    child: Text('System'),
                  ),
                ],
              ),
            ),
            ListTile(
              title: const Text('Library Grid Size'),
              subtitle: const Text('2 columns (default) - TODO'),
            ),
            ListTile(
              title: const Text('Font & Reader Settings'),
              subtitle: const Text(
                'Reader font size, line height, justification - TODO',
              ),
            ),
            ListTile(
              title: const Text('Sync Settings'),
              subtitle: const Text('Auto-sync interval, on-wifi-only - TODO'),
            ),
          ],
        ),
      ),
    );
  }
}
