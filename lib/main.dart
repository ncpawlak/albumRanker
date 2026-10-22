import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_scope.dart';
import 'data/album_repository.dart';
import 'data/settings_controller.dart';
import 'services/album_lookup_service.dart';
import 'services/auto_backup_service.dart';
import 'theme/app_theme.dart';
import 'ui/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final repository = AlbumRepository(prefs);
  final backup = AutoBackupService.forPlatform(prefs, repository);
  runApp(AlbumRankerApp(
    repository: repository,
    settings: SettingsController(prefs),
    lookup: AlbumLookupService(),
    backup: backup,
  ));
  backup.runIfDue();
}

class AlbumRankerApp extends StatelessWidget {
  const AlbumRankerApp({super.key, required this.repository, required this.settings, required this.lookup, this.backup});

  final AlbumRepository repository;
  final SettingsController settings;
  final AlbumLookupService lookup;
  final AutoBackupService? backup;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      repository: repository,
      settings: settings,
      lookup: lookup,
      backup: backup,
      child: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => MaterialApp(
          title: 'AlbumRank',
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
