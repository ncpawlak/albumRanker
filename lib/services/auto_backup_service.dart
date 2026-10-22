import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/album_repository.dart';

/// Writes a backup file somewhere the user can reach it, keeping the newest
/// [keep] files whose names start with [prefix]. Returns a display path.
abstract class BackupWriter {
  Future<String> write({required String fileName, required String contents, required String prefix, required int keep});
}

/// Saves into the phone's Downloads/AlbumRank folder via MainActivity.kt.
class AndroidDownloadsWriter implements BackupWriter {
  static const _channel = MethodChannel('albumrank/backup');

  @override
  Future<String> write({required String fileName, required String contents, required String prefix, required int keep}) async {
    final path = await _channel.invokeMethod<String>('saveToDownloads', {
      'fileName': fileName,
      'contents': contents,
      'prefix': prefix,
      'keep': keep,
    });
    return path ?? fileName;
  }
}

/// Saves a backup file once a week when the app is opened.
class AutoBackupService extends ChangeNotifier {
  AutoBackupService(this._prefs, this._repository, this._writer, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  /// Uses the Downloads writer on Android; elsewhere auto-backup is unavailable.
  factory AutoBackupService.forPlatform(SharedPreferences prefs, AlbumRepository repository) =>
      AutoBackupService(
        prefs,
        repository,
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android ? AndroidDownloadsWriter() : null,
      );

  static const interval = Duration(days: 7);
  static const keep = 5;
  static const filePrefix = 'AlbumRank-auto-';
  static const _lastKey = 'albumrank.lastAutoBackup';
  static const _pathKey = 'albumrank.lastAutoBackupPath';

  final SharedPreferences _prefs;
  final AlbumRepository _repository;
  final BackupWriter? _writer;
  final DateTime Function() _clock;
  bool _running = false;

  bool get supported => _writer != null;

  DateTime? get lastBackup => DateTime.tryParse(_prefs.getString(_lastKey) ?? '');
  String? get lastPath => _prefs.getString(_pathKey);

  bool get isDue {
    final last = lastBackup;
    return last == null || _clock().difference(last) >= interval;
  }

  /// Backs up if a week has passed and there is something to save.
  /// Failures are logged, not thrown, so app start is never blocked.
  Future<void> runIfDue() async {
    if (!supported || _running || _repository.albums.isEmpty || !isDue) return;
    try {
      await backupNow();
    } catch (e) {
      debugPrint('Auto-backup failed: $e');
    }
  }

  Future<String> backupNow() async {
    final writer = _writer;
    if (writer == null) throw UnsupportedError('Auto-backup is only available on Android');
    _running = true;
    try {
      final now = _clock();
      final path = await writer.write(
        fileName: '$filePrefix${_stamp(now)}.json',
        contents: _repository.exportJson(),
        prefix: filePrefix,
        keep: keep,
      );
      await _prefs.setString(_lastKey, now.toIso8601String());
      await _prefs.setString(_pathKey, path);
      notifyListeners();
      return path;
    } finally {
      _running = false;
    }
  }

  static String _stamp(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)}_${two(t.hour)}${two(t.minute)}${two(t.second)}';
  }
}
