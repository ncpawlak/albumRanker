import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_scope.dart';
import '../data/album_repository.dart';
import '../models/album.dart';
import '../services/album_lookup_service.dart';
import 'widgets/rating_widgets.dart';

class AlbumEditScreen extends StatefulWidget {
  const AlbumEditScreen({super.key, this.album});

  /// Album to edit, or null to add a new one.
  final Album? album;

  @override
  State<AlbumEditScreen> createState() => _AlbumEditScreenState();
}

class _AlbumEditScreenState extends State<AlbumEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _artist;
  late final TextEditingController _year;
  late final TextEditingController _genre;
  final _titleFocus = FocusNode();
  int? _rating;
  String? _artworkUrl;
  String? _externalId;
  bool _ratingError = false;
  bool _saving = false;

  Timer? _debounce;
  int _lookupSeq = 0;
  bool _searching = false;
  String? _lookupError;
  List<AlbumSuggestion> _suggestions = const [];

  bool get _isEditing => widget.album != null;

  @override
  void initState() {
    super.initState();
    final a = widget.album;
    _title = TextEditingController(text: a?.title ?? '');
    _artist = TextEditingController(text: a?.artist ?? '');
    _year = TextEditingController(text: a != null ? '${a.year}' : '');
    _genre = TextEditingController(text: a?.genre ?? '');
    _rating = a?.rating;
    _artworkUrl = a?.artworkUrl;
    _externalId = a?.externalId;
    _genre.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _title.dispose();
    _artist.dispose();
    _year.dispose();
    _genre.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  void _onTitleChanged(String value) {
    _debounce?.cancel();
    final term = value.trim();
    if (term.length < 2) {
      setState(() {
        _suggestions = const [];
        _searching = false;
        _lookupError = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _lookup(term));
  }

  Future<void> _lookup(String term) async {
    final seq = ++_lookupSeq;
    final lookup = AppScope.of(context).lookup;
    setState(() {
      _searching = true;
      _lookupError = null;
    });
    try {
      final results = await lookup.search(term);
      if (!mounted || seq != _lookupSeq) return;
      setState(() {
        _suggestions = results;
        _searching = false;
      });
    } catch (_) {
      if (!mounted || seq != _lookupSeq) return;
      setState(() {
        _suggestions = const [];
        _searching = false;
        _lookupError = "Couldn't reach album search. You can still enter details manually.";
      });
    }
  }

  void _applySuggestion(AlbumSuggestion s) {
    _debounce?.cancel();
    _lookupSeq++;
    setState(() {
      _title.text = s.title;
      _artist.text = s.artist;
      if (s.year != null) _year.text = '${s.year}';
      if (s.genre != null) _genre.text = s.genre!;
      _artworkUrl = s.artworkUrl;
      _externalId = s.externalId;
      _suggestions = const [];
      _searching = false;
      _lookupError = null;
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _save() async {
    final formOk = _formKey.currentState!.validate();
    setState(() => _ratingError = _rating == null);
    if (!formOk || _rating == null) return;

    final repo = AppScope.of(context).repository;
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    try {
      final year = int.parse(_year.text.trim());
      if (_isEditing) {
        await repo.update(widget.album!.copyWith(
          title: _title.text,
          artist: _artist.text,
          year: year,
          genre: _genre.text,
          rating: _rating,
          artworkUrl: _artworkUrl,
          externalId: _externalId,
        ));
      } else {
        await repo.add(
          title: _title.text,
          artist: _artist.text,
          year: year,
          genre: _genre.text,
          rating: _rating!,
          artworkUrl: _artworkUrl,
          externalId: _externalId,
        );
      }
      navigator.pop();
    } on DuplicateAlbumException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      final editExisting = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Already in your list'),
          content: Text('"${e.existing.title}" by ${e.existing.artist} is already in your albums '
              '(rated ${e.existing.rating}/10).'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Edit existing')),
          ],
        ),
      );
      if (editExisting == true && mounted) {
        navigator.pushReplacement(MaterialPageRoute(builder: (_) => AlbumEditScreen(album: e.existing)));
      }
    }
  }

  Future<void> _delete() async {
    final album = widget.album!;
    final repo = AppScope.of(context).repository;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete album?'),
        content: Text('"${album.title}" by ${album.artist} will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await repo.delete(album.id);
    navigator.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Deleted "${album.title}"'),
        action: SnackBarAction(label: 'Undo', onPressed: () => repo.restore(album)),
      ));
  }

  String? _required(String? v, String field) => (v == null || v.trim().isEmpty) ? '$field is required' : null;

  String? _validateYear(String? v) {
    final missing = _required(v, 'Year');
    if (missing != null) return missing;
    final year = int.tryParse(v!.trim());
    final max = DateTime.now().year + 1;
    if (year == null || year < 1900 || year > max) return 'Enter a year between 1900 and $max';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final genres = AppScope.of(context).repository.genres;
    final genreQuery = _genre.text.trim().toLowerCase();
    final genreChips = genres
        .where((g) => g.toLowerCase() != genreQuery && (genreQuery.isEmpty || g.toLowerCase().contains(genreQuery)))
        .take(8)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit album' : 'Add album'),
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
          children: [
            if (_artworkUrl != null) ...[
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    _artworkUrl!,
                    width: 140,
                    height: 140,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            const _Label('Album'),
            TextFormField(
              key: const ValueKey('field-title'),
              controller: _title,
              focusNode: _titleFocus,
              autofocus: !_isEditing,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              onChanged: _onTitleChanged,
              validator: (v) => _required(v, 'Album name'),
              decoration: InputDecoration(
                hintText: 'Start typing to search…',
                prefixIcon: const Icon(Icons.album_outlined),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : null,
              ),
            ),
            if (_lookupError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Text(_lookupError!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
              ),
            if (_suggestions.isNotEmpty) _SuggestionList(suggestions: _suggestions, onSelected: _applySuggestion),
            const SizedBox(height: 18),
            const _Label('Artist'),
            TextFormField(
              key: const ValueKey('field-artist'),
              controller: _artist,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: (v) => _required(v, 'Artist'),
              decoration: const InputDecoration(hintText: 'Artist', prefixIcon: Icon(Icons.person_outline_rounded)),
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('Year'),
                      TextFormField(
                        key: const ValueKey('field-year'),
                        controller: _year,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                        validator: _validateYear,
                        decoration: const InputDecoration(hintText: 'YYYY'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('Genre'),
                      TextFormField(
                        key: const ValueKey('field-genre'),
                        controller: _genre,
                        textCapitalization: TextCapitalization.words,
                        validator: (v) => _required(v, 'Genre'),
                        decoration: const InputDecoration(hintText: 'Genre'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (genreChips.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final g in genreChips)
                    ActionChip(
                      label: Text(g),
                      onPressed: () => _genre.text = g,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            const _Label('Your rating'),
            RatingPicker(
              value: _rating,
              onChanged: (v) => setState(() {
                _rating = v;
                _ratingError = false;
              }),
            ),
            if (_ratingError)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text('Rating is required',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: SizedBox(
            height: 54,
            child: FilledButton(
              key: const ValueKey('save-album'),
              style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              onPressed: _saving ? null : _save,
              child: Text(_isEditing ? 'Save changes' : 'Add to my albums',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          letterSpacing: 1.1,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SuggestionList extends StatelessWidget {
  const _SuggestionList({required this.suggestions, required this.onSelected});

  final List<AlbumSuggestion> suggestions;
  final ValueChanged<AlbumSuggestion> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final s in suggestions)
            ListTile(
              dense: true,
              onTap: () => onSelected(s),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: s.artworkUrl == null
                      ? Icon(Icons.album_rounded, color: theme.colorScheme.onSurfaceVariant)
                      : Image.network(
                          s.artworkUrl!.replaceFirst('600x600bb', '100x100bb'),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Icon(Icons.album_rounded, color: theme.colorScheme.onSurfaceVariant),
                        ),
                ),
              ),
              title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                [s.artist, if (s.year != null) '${s.year}', if (s.genre != null) s.genre!].join('  ·  '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}
