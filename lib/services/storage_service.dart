import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:xml/xml.dart';
import '../models/work.dart';
import '../models/reading_progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static SharedPreferences? _prefs;
  static const String worksBoxName = 'works_box';
  static const String settingsBoxName = 'settings_box';
  static bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    _prefs ??= await SharedPreferences.getInstance();

    await Hive.initFlutter();

    if (!Hive.isAdapterRegistered(0))
      Hive.registerAdapter(ReadingProgressAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(WorkAdapter());

    await Hive.openBox<Work>(worksBoxName);
    await Hive.openBox(settingsBoxName);

    await migrateHive();

    _initialized = true;
  }

  Box<Work> get worksBox => Hive.box<Work>(worksBoxName);
  Box<dynamic> get settingsBox => Hive.box(settingsBoxName);

  List<Work> getAllWorks() => worksBox.values.toList();
  Future<void> saveWork(Work work) async => await worksBox.put(work.id, work);
  Work? getWork(String id) => worksBox.get(id);
  Future<void> deleteWork(String id) async => await worksBox.delete(id);
  Future<void> clearAll() async => await worksBox.clear();

  Future<String> exportToJson() async {
    final works = getAllWorks();
    final jsonList = works.map((w) => w.toJson()).toList();
    return const JsonEncoder.withIndent('  ').convert({'works': jsonList});
  }

  Future<void> importFromJson(String jsonString) async {
    final data = jsonDecode(jsonString);
    if (data is! Map || !data.containsKey('works')) return;

    final works = (data['works'] as List)
        .map((e) => Work.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    for (final w in works) {
      await saveWork(w);
    }
  }

  Future<String> exportToOpds() async {
    final works = getAllWorks();
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element(
      'feed',
      nest: () {
        builder.element('title', nest: 'AO3 Reader Library');
        builder.element('updated', nest: DateTime.now().toIso8601String());
        for (final w in works) {
          builder.element(
            'entry',
            nest: () {
              builder.element('id', nest: w.id);
              builder.element('title', nest: w.title);
              builder.element('author', nest: w.author);
              builder.element(
                'updated',
                nest: w.userAddedDate.toIso8601String(),
              );
            },
          );
        }
      },
    );
    return builder.buildDocument().toXmlString(pretty: true);
  }

  Future<void> saveAdvancedFilters(Map<String, dynamic> filters) async {
    await settingsBox.put('last_advanced_filters', filters);
  }

  Future<Map<String, dynamic>> getAdvancedFilters() async {
    final data = settingsBox.get('last_advanced_filters');
    return data != null ? Map<String, dynamic>.from(data) : {};
  }

  Future<void> saveSearch(
    String name,
    String url,
    Map<String, dynamic> filters,
  ) async {
    final searches = await getSavedSearches();
    searches.removeWhere((s) => s['name'] == name);
    searches.add({'name': name, 'url': url, 'filters': filters});
    await settingsBox.put('saved_searches', searches);
  }

  Future<List<Map<String, dynamic>>> getSavedSearches() async {
    final saved = settingsBox.get('saved_searches');
    if (saved == null) return [];
    return (saved as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> deleteSavedSearch(String name) async {
    final searches = await getSavedSearches();
    searches.removeWhere((s) => s['name'] == name);
    await settingsBox.put('saved_searches', searches);
  }
}

Future<void> migrateHive() async {
  final Box<dynamic> box = Hive.box(StorageService.worksBoxName);
  final keys = box.keys.toList();

  for (final key in keys) {
    final raw = box.get(key);
    if (raw == null) continue;

    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      map.putIfAbsent(
        'readingProgress',
        () => {
          'chapterIndex': 0,
          'chapterAnchor': '',
          'scrollPosition': 0.0,
          'lastReadAt': DateTime.now().toIso8601String(),
        },
      );

      try {
        final normalized = Work.fromJson(map);
        await box.put(key, normalized);
      } catch (e) {
        print('Migration failed for $key: $e');
      }
    } else if (raw is Work) {
      continue;
    } else {
      print('Unexpected data type for key $key: ${raw.runtimeType}');
    }
  }
}
