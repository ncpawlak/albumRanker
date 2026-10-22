import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_scope.dart';
import 'data/album_repository.dart';
import 'data/settings_controller.dart';
import 'services/album_lookup_service.dart';
import 'theme/app_theme.dart';
import 'ui/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(AlbumRankerApp(
    repository: AlbumRepository(prefs),
    settings: SettingsController(prefs),
    lookup: AlbumLookupService(),
  ));
}

class AlbumRankerApp extends StatelessWidget {
  const AlbumRankerApp({super.key, required this.repository, required this.settings, required this.lookup});

  final AlbumRepository repository;
  final SettingsController settings;
  final AlbumLookupService lookup;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      repository: repository,
      settings: settings,
      lookup: lookup,
      child: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => MaterialApp(
          title: 'Album Ranker',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: settings.themeMode,
          home: const HomeShell(),
        ),
      ),
    );
  }
}
