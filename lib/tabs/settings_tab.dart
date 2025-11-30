import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';
import '../providers/storage_provider.dart';
import '../services/sync_service.dart';

/// Provider for library grid columns setting
final libraryGridColumnsProvider = StateNotifierProvider<LibraryGridColumnsNotifier, int>((ref) {
  final storage = ref.watch(storageProvider);
  final saved = storage.settingsBox.get('library_grid_columns', defaultValue: 4);
  return LibraryGridColumnsNotifier(saved is int ? saved : 4, storage);
});

class LibraryGridColumnsNotifier extends StateNotifier<int> {
  final dynamic _storage;
  
  LibraryGridColumnsNotifier(super.state, this._storage);
  
  Future<void> setColumns(int columns) async {
    state = columns;
    await _storage.settingsBox.put('library_grid_columns', columns);
  }
}

/// Provider for sync settings
final syncSettingsProvider = StateNotifierProvider<SyncSettingsNotifier, SyncSettings>((ref) {
  final storage = ref.watch(storageProvider);
  return SyncSettingsNotifier(storage);
});

class SyncSettings {
  final bool autoSyncEnabled;
  final SyncInterval interval;
  final SyncNetworkPreference networkPreference;
  final DateTime? lastSyncTime;
  
  SyncSettings({
    this.autoSyncEnabled = false,
    this.interval = SyncInterval.daily,
    this.networkPreference = SyncNetworkPreference.wifiOnly,
    this.lastSyncTime,
  });
  
  SyncSettings copyWith({
    bool? autoSyncEnabled,
    SyncInterval? interval,
    SyncNetworkPreference? networkPreference,
    DateTime? lastSyncTime,
  }) => SyncSettings(
    autoSyncEnabled: autoSyncEnabled ?? this.autoSyncEnabled,
    interval: interval ?? this.interval,
    networkPreference: networkPreference ?? this.networkPreference,
    lastSyncTime: lastSyncTime ?? this.lastSyncTime,
  );
}

class SyncSettingsNotifier extends StateNotifier<SyncSettings> {
  final dynamic _storage;
  
  SyncSettingsNotifier(this._storage) : super(SyncSettings()) {
    _loadSettings();
  }
  
  Future<void> _loadSettings() async {
    try {
      final box = _storage.settingsBox;
      final enabled = box.get('auto_sync_enabled', defaultValue: false);
      final intervalIndex = box.get('sync_interval', defaultValue: 1);
      final networkIndex = box.get('sync_network_preference', defaultValue: 0);
      final lastSyncStr = box.get('last_sync_time');
      
      state = SyncSettings(
        autoSyncEnabled: enabled == true,
        interval: SyncInterval.values[intervalIndex is int ? intervalIndex : 1],
        networkPreference: SyncNetworkPreference.values[networkIndex is int ? networkIndex : 0],
        lastSyncTime: lastSyncStr != null ? DateTime.tryParse(lastSyncStr.toString()) : null,
      );
    } catch (e) {
      debugPrint('Error loading sync settings: $e');
    }
  }
  
  Future<void> setAutoSyncEnabled(bool enabled) async {
    state = state.copyWith(autoSyncEnabled: enabled);
    await _storage.settingsBox.put('auto_sync_enabled', enabled);
    
    if (enabled) {
      await SyncService.scheduleSync(
        interval: state.interval,
        networkPreference: state.networkPreference,
      );
    } else {
      await SyncService.cancelSync();
    }
  }
  
  Future<void> setInterval(SyncInterval interval) async {
    state = state.copyWith(interval: interval);
    await _storage.settingsBox.put('sync_interval', interval.index);
    
    if (state.autoSyncEnabled) {
      await SyncService.scheduleSync(
        interval: interval,
        networkPreference: state.networkPreference,
      );
    }
  }
  
  Future<void> setNetworkPreference(SyncNetworkPreference preference) async {
    state = state.copyWith(networkPreference: preference);
    await _storage.settingsBox.put('sync_network_preference', preference.index);
    
    if (state.autoSyncEnabled) {
      await SyncService.scheduleSync(
        interval: state.interval,
        networkPreference: preference,
      );
    }
  }
  
  void updateLastSyncTime(DateTime time) {
    state = state.copyWith(lastSyncTime: time);
  }
}

class SettingsTab extends ConsumerStatefulWidget {
  const SettingsTab({super.key});

  @override
  ConsumerState<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<SettingsTab> {
  bool _isSyncing = false;

  Future<void> _performManualSync() async {
    setState(() => _isSyncing = true);
    
    try {
      final syncService = SyncService();
      final syncSettings = ref.read(syncSettingsProvider);
      
      // Check network preference
      final canSync = await syncService.canSyncWithCurrentNetwork(
        syncSettings.networkPreference,
      );
      
      if (!canSync) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot sync: Wi-Fi required but not connected'),
            ),
          );
        }
        return;
      }
      
      final updates = await syncService.performSync();
      
      if (mounted) {
        ref.read(syncSettingsProvider.notifier).updateLastSyncTime(DateTime.now());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              updates.isEmpty 
                  ? 'Sync complete. No updates found.'
                  : 'Sync complete. Found ${updates.length} update(s).',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);
    final gridColumns = ref.watch(libraryGridColumnsProvider);
    final gridNotifier = ref.read(libraryGridColumnsProvider.notifier);
    final syncSettings = ref.watch(syncSettingsProvider);
    final syncNotifier = ref.read(syncSettingsProvider.notifier);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: ListView(
          children: [
            // Theme setting
            ListTile(
              leading: const Icon(Icons.palette),
              title: const Text('Theme'),
              subtitle: Text(theme == ThemeMode.dark ? 'Dark' : 'Light'),
              trailing: PopupMenuButton<ThemeMode>(
                onSelected: themeNotifier.setMode,
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: ThemeMode.light,
                    child: Text('Light'),
                  ),
                  const PopupMenuItem(
                    value: ThemeMode.dark,
                    child: Text('Dark'),
                  ),
                ],
              ),
            ),
            
            const Divider(),
            
            // Library Grid Size
            ListTile(
              leading: const Icon(Icons.grid_view),
              title: const Text('Library Grid Columns'),
              subtitle: Text('$gridColumns columns'),
              trailing: PopupMenuButton<int>(
                onSelected: gridNotifier.setColumns,
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 2, child: Text('2 columns')),
                  const PopupMenuItem(value: 3, child: Text('3 columns')),
                  const PopupMenuItem(value: 4, child: Text('4 columns')),
                  const PopupMenuItem(value: 5, child: Text('5 columns')),
                  const PopupMenuItem(value: 6, child: Text('6 columns')),
                ],
              ),
            ),
            
            const Divider(),
            
            // Sync Settings Section
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Sync Settings',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            
            // Auto Sync Toggle
            SwitchListTile(
              secondary: const Icon(Icons.sync),
              title: const Text('Auto Sync'),
              subtitle: Text(
                Platform.isWindows
                    ? 'Background sync not available on Windows'
                    : 'Automatically check for work updates',
              ),
              value: syncSettings.autoSyncEnabled,
              onChanged: Platform.isWindows ? null : syncNotifier.setAutoSyncEnabled,
            ),
            
            // Sync Interval
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('Sync Interval'),
              subtitle: Text(syncSettings.interval.label),
              enabled: syncSettings.autoSyncEnabled && !Platform.isWindows,
              trailing: PopupMenuButton<SyncInterval>(
                enabled: syncSettings.autoSyncEnabled && !Platform.isWindows,
                onSelected: syncNotifier.setInterval,
                itemBuilder: (context) => SyncInterval.values
                    .map((i) => PopupMenuItem(value: i, child: Text(i.label)))
                    .toList(),
              ),
            ),
            
            // Network Preference
            ListTile(
              leading: const Icon(Icons.wifi),
              title: const Text('Sync Network'),
              subtitle: Text(syncSettings.networkPreference.label),
              trailing: PopupMenuButton<SyncNetworkPreference>(
                onSelected: syncNotifier.setNetworkPreference,
                itemBuilder: (context) => SyncNetworkPreference.values
                    .map((p) => PopupMenuItem(value: p, child: Text(p.label)))
                    .toList(),
              ),
            ),
            
            // Last Sync Time
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Last Sync'),
              subtitle: Text(
                syncSettings.lastSyncTime != null
                    ? _formatDateTime(syncSettings.lastSyncTime!)
                    : 'Never',
              ),
            ),
            
            // Manual Sync Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ElevatedButton.icon(
                onPressed: _isSyncing ? null : _performManualSync,
                icon: _isSyncing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
                label: Text(_isSyncing ? 'Syncing...' : 'Sync Now'),
              ),
            ),
            
            const Divider(),
            
            // Reader Settings placeholder
            ListTile(
              leading: const Icon(Icons.text_fields),
              title: const Text('Font & Reader Settings'),
              subtitle: const Text(
                'Reader font size, line height, justification',
              ),
              onTap: () {
                // TODO: Open reader settings dialog
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reader settings coming soon')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
  
  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} minutes ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
           '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
