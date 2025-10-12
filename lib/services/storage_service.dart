import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:xml/xml.dart';
import '../models/work.dart';
import '../models/reading_progress.dart';

class StorageService {
  static const String worksBoxName = 'works_box';
  static bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    await Hive.initFlutter();

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ReadingProgressAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(WorkAdapter());
    }

    await Hive.openBox<Work>(worksBoxName);
    await migrateHive();
    _initialized = true;
  }

  Box<Work> get worksBox => Hive.box<Work>(worksBoxName);

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

    builder.processing('xml', 'version=\"1.0\" encoding=\"UTF-8\"');
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
}

Future<void> migrateHive() async {
  final Box<dynamic> box = Hive.box(StorageService.worksBoxName);
  final keys = box.keys.toList();

  for (final key in keys) {
    final dynamic raw = box.get(key);

    if (raw == null) continue;

    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw as Map);
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
    } else {
      print('Unexpected data type for key $key: ${raw.runtimeType}');
    }
  }
}
