import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import '../services/storage_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/storage_provider.dart';

class AdvancedSearchScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> initialFilters;

  const AdvancedSearchScreen({Key? key, this.initialFilters = const {}})
    : super(key: key);

  @override
  ConsumerState<AdvancedSearchScreen> createState() =>
      _AdvancedSearchScreenState();
}

class _AdvancedSearchScreenState extends ConsumerState<AdvancedSearchScreen> {
  final _formKey = GlobalKey<FormState>();

  final queryCtrl = TextEditingController();
  final titleCtrl = TextEditingController();
  final creatorsCtrl = TextEditingController();
  final dateCtrl = TextEditingController();
  final wordCountCtrl = TextEditingController();
  String completion = "";
  String crossover = "";
  bool singleChapter = false;
  String language = "";

  final fandomCtrl = TextEditingController();
  String rating = "";
  final List<String> warnings = [];
  final List<String> categories = [];
  final charactersCtrl = TextEditingController();
  final relationshipsCtrl = TextEditingController();
  final tagsCtrl = TextEditingController();

  final hitsCtrl = TextEditingController();
  final kudosCtrl = TextEditingController();
  final commentsCtrl = TextEditingController();
  final bookmarksCtrl = TextEditingController();

  String sortColumn = "_score";
  String sortDirection = "desc";

  @override
  void initState() {
    super.initState();
    _loadInitialFilters();
  }

  void _loadInitialFilters() {
    final f = widget.initialFilters;
    queryCtrl.text = f["work_search[query]"] ?? "";
    titleCtrl.text = f["work_search[title]"] ?? "";
    creatorsCtrl.text = f["work_search[creators]"] ?? "";
    dateCtrl.text = f["work_search[revised_at]"] ?? "";
    completion = f["work_search[complete]"] ?? "";
    crossover = f["work_search[crossover]"] ?? "";
    singleChapter = f["work_search[single_chapter]"] == "1";
    wordCountCtrl.text = f["work_search[word_count]"] ?? "";
    language = f["work_search[language_id]"] ?? "";
    fandomCtrl.text = f["work_search[fandom_names]"] ?? "";
    rating = f["work_search[rating_ids]"] ?? "";
    warnings.clear();
    if (f["work_search[archive_warning_ids][]"] != null) {
      warnings.addAll(
        List<String>.from(f["work_search[archive_warning_ids][]"]),
      );
    }
    categories.clear();
    if (f["work_search[category_ids][]"] != null) {
      categories.addAll(List<String>.from(f["work_search[category_ids][]"]));
    }
    charactersCtrl.text = f["work_search[character_names]"] ?? "";
    relationshipsCtrl.text = f["work_search[relationship_names]"] ?? "";
    tagsCtrl.text = f["work_search[freeform_names]"] ?? "";
    hitsCtrl.text = f["work_search[hits]"] ?? "";
    kudosCtrl.text = f["work_search[kudos_count]"] ?? "";
    commentsCtrl.text = f["work_search[comments_count]"] ?? "";
    bookmarksCtrl.text = f["work_search[bookmarks_count]"] ?? "";
    sortColumn = f["work_search[sort_column]"] ?? "_score";
    sortDirection = f["work_search[sort_direction]"] ?? "desc";
  }

  Map<String, dynamic> get _filters => {
    "work_search[query]": queryCtrl.text,
    "work_search[title]": titleCtrl.text,
    "work_search[creators]": creatorsCtrl.text,
    "work_search[revised_at]": dateCtrl.text,
    "work_search[complete]": completion,
    "work_search[crossover]": crossover,
    "work_search[single_chapter]": singleChapter ? "1" : "0",
    "work_search[word_count]": wordCountCtrl.text,
    "work_search[language_id]": language,
    "work_search[fandom_names]": fandomCtrl.text,
    "work_search[rating_ids]": rating,
    "work_search[archive_warning_ids][]": warnings,
    "work_search[category_ids][]": categories,
    "work_search[character_names]": charactersCtrl.text,
    "work_search[relationship_names]": relationshipsCtrl.text,
    "work_search[freeform_names]": tagsCtrl.text,
    "work_search[hits]": hitsCtrl.text,
    "work_search[kudos_count]": kudosCtrl.text,
    "work_search[comments_count]": commentsCtrl.text,
    "work_search[bookmarks_count]": bookmarksCtrl.text,
    "work_search[sort_column]": sortColumn,
    "work_search[sort_direction]": sortDirection,
    "commit": "Search",
  };

  void _submit() async {
    final uri = Uri.https("archiveofourown.org", "/works/search", _filters);
    final url = uri.toString();

    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save this search?'),
        content: const Text(
          'Would you like to save this search setup for later?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (save == true) {
      final nameController = TextEditingController();
      final name = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Name this search'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              hintText: 'e.g. Long Fics >50k words',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
              child: const Text('Save'),
            ),
          ],
        ),
      );
      if (name != null && name.isNotEmpty && context.mounted) {
        final storage = ref.read(storageProvider);
        await storage.saveSearch(name, url, _filters);
      }
    }

    if (context.mounted) {
      Navigator.pop(context, {'url': url, 'filters': _filters});
    }
  }

  @override
  void dispose() {
    for (final c in [
      queryCtrl,
      titleCtrl,
      creatorsCtrl,
      dateCtrl,
      wordCountCtrl,
      fandomCtrl,
      charactersCtrl,
      relationshipsCtrl,
      tagsCtrl,
      hitsCtrl,
      kudosCtrl,
      commentsCtrl,
      bookmarksCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced Search'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Submit Search',
            onPressed: _submit,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _fieldset("Work Info", [
              _textField("Any Field", queryCtrl),
              _textField("Title", titleCtrl),
              _textField("Author", creatorsCtrl),
              _textField("Date Updated", dateCtrl),
              _radioGroup(
                "Completion",
                {
                  "": "All Works",
                  "T": "Complete Works Only",
                  "F": "Works In Progress Only",
                },
                completion,
                (v) => setState(() => completion = v!),
              ),
              _radioGroup(
                "Crossovers",
                {
                  "": "Include Crossovers",
                  "F": "Exclude Crossovers",
                  "T": "Only Crossovers",
                },
                crossover,
                (v) => setState(() => crossover = v!),
              ),
              SwitchListTile(
                title: const Text("Single Chapter"),
                value: singleChapter,
                onChanged: (v) => setState(() => singleChapter = v),
              ),
              _textField("Word Count", wordCountCtrl),
              _dropdown("Language", language, {
                "": "Any",
                "en": "English",
                "ja": "Japanese",
                "ko": "Korean",
                "fr": "French",
                "de": "German",
                "zh": "Chinese",
              }, (v) => setState(() => language = v ?? "")),
            ]),

            _fieldset("Work Tags", [
              _textField("Fandoms", fandomCtrl),
              _dropdown("Rating", rating, {
                "": "Any",
                "9": "Not Rated",
                "10": "General",
                "11": "Teen & Up",
                "12": "Mature",
                "13": "Explicit",
              }, (v) => setState(() => rating = v ?? "")),
              _checkboxList("Warnings", {
                "14": "Chose Not To Use Archive Warnings",
                "17": "Graphic Violence",
                "18": "Major Character Death",
                "16": "No Archive Warnings Apply",
                "19": "Rape/Non-Con",
                "20": "Underage",
              }, warnings),
              _checkboxList("Categories", {
                "116": "F/F",
                "22": "F/M",
                "21": "Gen",
                "23": "M/M",
                "2246": "Multi",
                "24": "Other",
              }, categories),
              _textField("Characters", charactersCtrl),
              _textField("Relationships", relationshipsCtrl),
              _textField("Additional Tags", tagsCtrl),
            ]),

            _fieldset("Work Stats", [
              _textField("Hits (min)", hitsCtrl),
              _textField("Kudos (min)", kudosCtrl),
              _textField("Comments (min)", commentsCtrl),
              _textField("Bookmarks (min)", bookmarksCtrl),
            ]),

            _fieldset("Search Options", [
              _dropdown(
                "Sort By",
                sortColumn,
                {
                  "_score": "Best Match",
                  "authors_to_sort_on": "Creator",
                  "title_to_sort_on": "Title",
                  "created_at": "Date Posted",
                  "revised_at": "Date Updated",
                  "word_count": "Word Count",
                  "hits": "Hits",
                  "kudos_count": "Kudos",
                  "comments_count": "Comments",
                  "bookmarks_count": "Bookmarks",
                },
                (v) => setState(() => sortColumn = v ?? "_score"),
              ),
              _dropdown(
                "Direction",
                sortDirection,
                {"asc": "Ascending", "desc": "Descending"},
                (v) => setState(() => sortDirection = v ?? "desc"),
              ),
            ]),

            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.search),
              label: const Text('Search'),
              onPressed: () async {
                final uri = Uri.https(
                  'archiveofourown.org',
                  '/works/search',
                  _filters,
                );
                final url = uri.toString();

                final save = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Save this search?'),
                    content: const Text(
                      'Would you like to save this search setup for later?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('No'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Yes'),
                      ),
                    ],
                  ),
                );

                if (save == true) {
                  final nameController = TextEditingController();
                  final name = await showDialog<String>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Name this search'),
                      content: TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          hintText: 'e.g. Long Fics >50k words',
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(ctx, nameController.text.trim()),
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  );
                  if (name != null && name.isNotEmpty && mounted) {
                    final storage = ref.read(storageProvider);
                    await storage.saveSearch(name, url, _filters);
                  }
                }

                if (context.mounted) {
                  Navigator.pop(context, {'url': url, 'filters': _filters});
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldset(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _textField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  Widget _dropdown(
    String label,
    String value,
    Map<String, String> options,
    ValueChanged<String?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        value: value.isEmpty ? null : value,
        items: options.entries
            .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _radioGroup(
    String label,
    Map<String, String> options,
    String groupValue,
    ValueChanged<String?> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ...options.entries.map(
          (e) => RadioListTile<String>(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(e.value),
            value: e.key,
            groupValue: groupValue,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _checkboxList(
    String label,
    Map<String, String> options,
    List<String> selected,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ...options.entries.map(
          (e) => CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(e.value),
            value: selected.contains(e.key),
            onChanged: (checked) {
              setState(() {
                if (checked == true) {
                  selected.add(e.key);
                } else {
                  selected.remove(e.key);
                }
              });
            },
          ),
        ),
      ],
    );
  }
}
