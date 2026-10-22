import 'package:flutter/widgets.dart';

import '../data/album_repository.dart';
import '../data/settings_controller.dart';
import '../services/album_lookup_service.dart';
import '../services/auto_backup_service.dart';

/// Makes app-wide services available to the widget tree.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.repository,
    required this.settings,
    required this.lookup,
    this.backup,
    required super.child,
  });

  final AlbumRepository repository;
  final SettingsController settings;
  final AlbumLookupService lookup;

  /// Null in tests and on web, where auto-backup is unavailable.
  final AutoBackupService? backup;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      repository != oldWidget.repository || settings != oldWidget.settings || lookup != oldWidget.lookup || backup != oldWidget.backup;
}
