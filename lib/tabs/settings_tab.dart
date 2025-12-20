import 'dart:io' show Platform, File;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/storage_provider.dart';
import '../services/sync_service.dart';
import '../services/library_export_service.dart';
import '../services/download_service.dart';

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
  bool _isExporting = false;
  bool _isImporting = false;

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

  Future<void> _exportLibrary() async {
    setState(() => _isExporting = true);
    
    try {
      final storage = ref.read(storageProvider);
      final exportService = LibraryExportService(storage);
      
      final filePath = await exportService.exportToFile();
      
      if (mounted) {
        _showExportSuccessDialog(filePath);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  void _showExportSuccessDialog(String filePath) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export Successful'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Library exported successfully to:'),
            const SizedBox(height: 8),
            SelectableText(
              filePath,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 16),
            const Text(
              'You can copy this file to another device and import it there.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: filePath));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Path copied to clipboard')),
              );
            },
            child: const Text('Copy Path'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _importLibrary() async {
    // Show import dialog with text input for JSON
    final controller = TextEditingController();
    
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import Library'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paste the library JSON content below, or enter a file path:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 10,
                decoration: const InputDecoration(
                  hintText: '{"version": 1, "works": [...], ...}\n\nOr paste file path',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Import mode:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                '• Merge: Add new works, update existing (preserve reading progress)\n'
                '• Replace: Clear library and import all data',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, {
              'content': controller.text,
              'mode': ImportMode.merge,
            }),
            child: const Text('Merge Import'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, {
              'content': controller.text,
              'mode': ImportMode.replace,
            }),
            child: const Text('Replace All'),
          ),
        ],
      ),
    );
    
    controller.dispose();
    
    if (result == null) return;
    
    final content = result['content'] as String;
    final mode = result['mode'] as ImportMode;
    
    if (content.isEmpty) return;
    
    setState(() => _isImporting = true);
    
    try {
      final storage = ref.read(storageProvider);
      final exportService = LibraryExportService(storage);
      
      ImportResult importResult;
      
      // Check if content is a file path
      if (_isFilePath(content)) {
        importResult = await exportService.importFromFile(content.trim(), mode: mode);
      } else {
        importResult = await exportService.importFromJson(content, mode: mode);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import complete: ${importResult.toSummary()}'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  bool _isFilePath(String content) {
    final trimmed = content.trim();
    // Check if it looks like a file path
    if (Platform.isWindows) {
      return trimmed.contains(':\\') || trimmed.startsWith('\\\\');
    } else {
      return trimmed.startsWith('/');
    }
  }

  Future<void> _showStorageInfo() async {
    final storage = ref.read(storageProvider);
    final works = storage.getAllWorks();
    final categories = await storage.getCategories();
    final downloadSize = await DownloadService.getStorageUsage();
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Storage Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _storageInfoRow('Works in library', '${works.length}'),
            _storageInfoRow('Categories', '${categories.length}'),
            _storageInfoRow('Downloaded works', '${works.where((w) => w.isDownloaded).length}'),
            _storageInfoRow('Download storage', _formatBytes(downloadSize)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _storageInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
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
            
            // Data Management Section
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Data Management',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            
            // Export Library
            ListTile(
              leading: const Icon(Icons.upload),
              title: const Text('Export Library'),
              subtitle: const Text('Save library to JSON file'),
              trailing: _isExporting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right),
              onTap: _isExporting ? null : _exportLibrary,
            ),
            
            // Import Library
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Import Library'),
              subtitle: const Text('Load library from JSON file or data'),
              trailing: _isImporting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right),
              onTap: _isImporting ? null : _importLibrary,
            ),
            
            // Storage Info
            ListTile(
              leading: const Icon(Icons.storage),
              title: const Text('Storage Info'),
              subtitle: const Text('View storage usage'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _showStorageInfo,
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
