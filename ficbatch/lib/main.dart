import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_neumorphic/flutter_neumorphic.dart';

import 'services/settings_service.dart';
import 'services/download_service.dart';
import 'services/library_service.dart';
import 'services/history_service.dart';
import 'services/storage_service.dart';

import 'screens/dashboard_screen.dart';
import 'screens/library_screen.dart';
import 'screens/reader_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/history_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settings = SettingsService();
  await settings.load();

  final storage = StorageService(settings: settings);
  await storage.ensureReady(); // asks storage perms on Android if needed

  final history = HistoryService();
  await history.load();

  final library = LibraryService(settings: settings, history: history, storage: storage);
  await library.init();

  final downloader = DownloadService(
    settings: settings,
    library: library,
    history: history,
    storage: storage,
  );

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => settings),
      ChangeNotifierProvider(create: (_) => history),
      ChangeNotifierProvider(create: (_) => library),
      ChangeNotifierProvider(create: (_) => downloader),
    ],
    child: const FicBatchApp(),
  ));
}

class FicBatchApp extends StatelessWidget {
  const FicBatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    return NeumorphicApp(
      title: 'ficbatch',
      debugShowCheckedModeBanner: false,
      themeMode: settings.darkMode ? ThemeMode.dark : ThemeMode.light,
      theme: const NeumorphicThemeData(
        baseColor: Color(0xFFEFF3F6),
        lightSource: LightSource.topLeft,
        depth: 4,
      ),
      darkTheme: const NeumorphicThemeData(
        baseColor: Color(0xFF1F2430),
        lightSource: LightSource.topLeft,
        depth: 4,
      ),
      home: const RootShell(),
      routes: {
        DashboardScreen.route: (_) => const DashboardScreen(),
        LibraryScreen.route: (_) => const LibraryScreen(),
        SettingsScreen.route: (_) => const SettingsScreen(),
        HistoryScreen.route: (_) => const HistoryScreen(),
      },
      onGenerateRoute: (settingsRoute) {
        if (settingsRoute.name?.startsWith(ReaderScreen.routeBase) ?? false) {
          final args = settingsRoute.arguments as ReaderScreenArgs;
          return MaterialPageRoute(builder: (_) => ReaderScreen(args: args));
        }
        return null;
      },
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});
  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int index = 0;
  final items = const [
    DashboardScreen(),
    LibraryScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return NeumorphicBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(child: items[index]),
        bottomNavigationBar: Neumorphic(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.symmetric(vertical: 6),
          style: const NeumorphicStyle(depth: -4, intensity: 0.7),
          child: BottomNavigationBar(
            currentIndex: index,
            type: BottomNavigationBarType.fixed,
            onTap: (i) => setState(() => index = i),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.download), label: 'Dashboard'),
              BottomNavigationBarItem(icon: Icon(Icons.library_books), label: 'Library'),
              BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'History'),
              BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
            ],
          ),
        ),
      ),
    );
  }
}
