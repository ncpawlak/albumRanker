import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../services/auto_backup_service.dart';
import '../theme/rating_colors.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _export(BuildContext context) async {
    final repo = AppScope.of(context).repository;
    final messenger = ScaffoldMessenger.of(context);
    final now = DateTime.now();
    final stamp = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    try {
      final saved = await FilePicker.saveFile(
        dialogTitle: 'Save backup',
        fileName: 'AlbumRank-backup-$stamp.json',
        bytes: utf8.encode(repo.exportJson()),
        mimeType: 'application/json',
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (saved != null) {
        messenger.showSnackBar(SnackBar(content: Text('Backup saved (${repo.albums.length} albums)')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _import(BuildContext context) async {
    final repo = AppScope.of(context).repository;
    final messenger = ScaffoldMessenger.of(context);
    final file = await FilePicker.pickFile(
      dialogTitle: 'Choose backup',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (file == null || !context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Replace your albums?'),
        content: Text('Importing will replace all ${repo.albums.length} albums currently in the app '
            'with the contents of "${file.name}".'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Replace')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final bytes = await file.readAsBytes();
      final count = await repo.importJson(utf8.decode(bytes));
      messenger.showSnackBar(SnackBar(content: Text('Imported $count albums')));
    } on FormatException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Import failed: ${e.message}')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), centerTitle: false, toolbarHeight: 64),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          _Section(
            title: 'Appearance',
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: ListenableBuilder(
                  listenable: scope.settings,
                  builder: (context, _) => SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ThemeMode>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_rounded), label: Text('Dark')),
                        ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_rounded), label: Text('Light')),
                      ],
                      selected: {scope.settings.themeMode},
                      onSelectionChanged: (s) => scope.settings.setThemeMode(s.first),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _Section(
            title: 'Backup',
            children: [
              ListTile(
                leading: const Icon(Icons.upload_file_rounded),
                title: const Text('Export backup'),
                subtitle: const Text('Save all albums to a .json file'),
                onTap: () => _export(context),
              ),
              const Divider(indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.download_rounded),
                title: const Text('Import backup'),
                subtitle: const Text('Replace albums from a .json file'),
                onTap: () => _import(context),
              ),
              if (scope.backup case final backup? when backup.supported) ...[
                const Divider(indent: 16, endIndent: 16),
                _AutoBackupTile(backup: backup),
              ],
            ],
          ),
          const SizedBox(height: 20),
          _Section(
            title: 'Rating colors',
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    for (var r = 1; r <= 10; r++)
                      Expanded(
                        child: Container(
                          height: 28,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: ratingColor(r), borderRadius: BorderRadius.circular(6)),
                          child: Text('$r',
                              style: TextStyle(color: onRatingColor(r), fontWeight: FontWeight.w800, fontSize: 12)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'AlbumRank · album search by iTunes',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _AutoBackupTile extends StatelessWidget {
  const _AutoBackupTile({required this.backup});

  final AutoBackupService backup;

  static String _describe(DateTime? last) {
    if (last == null) return 'No backup yet';
    final days = DateTime.now().difference(last).inDays;
    final when = switch (days) { 0 => 'today', 1 => 'yesterday', _ => '$days days ago' };
    return 'Last backup $when';
  }

  Future<void> _backupNow(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final path = await backup.backupNow();
      messenger.showSnackBar(SnackBar(content: Text('Saved to $path')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Backup failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: backup,
      builder: (context, _) => ListTile(
        leading: const Icon(Icons.history_rounded),
        title: const Text('Weekly auto-backup'),
        subtitle: Text('${_describe(backup.lastBackup)} · Downloads/AlbumRank, keeps ${AutoBackupService.keep}'),
        trailing: TextButton(onPressed: () => _backupNow(context), child: const Text('Back up now')),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Card(clipBehavior: Clip.antiAlias, child: Column(children: children)),
      ],
    );
  }
}
