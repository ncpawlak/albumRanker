import 'package:flutter/widgets.dart';

import '../data/album_repository.dart';
import '../data/settings_controller.dart';
import '../services/album_lookup_service.dart';
import '../services/artist_image_service.dart';
import '../services/auto_backup_service.dart';

/// Makes app-wide services available to the widget tree.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.repository,
    required this.settings,
    required this.lookup,
    this.backup,
    this.artistImages,
    required super.child,
  });

  final AlbumRepository repository;
  final SettingsController settings;
  final AlbumLookupService lookup;

  /// Null in tests and on web, where auto-backup is unavailable.
  final AutoBackupService? backup;

  /// Band photos for backgrounds. Null turns backgrounds off (e.g. in most tests).
  final ArtistImageService? artistImages;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      repository != oldWidget.repository || settings != oldWidget.settings || lookup != oldWidget.lookup || backup != oldWidget.backup ||
      artistImages != oldWidget.artistImages;
}
