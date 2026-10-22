import 'dart:async';

import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../services/artist_image_service.dart';

/// Lets the user pick [artist]'s background photo from Deezer search results.
Future<void> showArtistImagePicker(BuildContext context, String artist) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FractionallySizedBox(heightFactor: 0.8, child: _ArtistImagePicker(artist: artist)),
    );

class _ArtistImagePicker extends StatefulWidget {
  const _ArtistImagePicker({required this.artist});

  final String artist;

  @override
  State<_ArtistImagePicker> createState() => _ArtistImagePickerState();
}

class _ArtistImagePickerState extends State<_ArtistImagePicker> {
  late final _query = TextEditingController(text: widget.artist);
  Timer? _debounce;
  List<ArtistImageOption>? _results;
  String? _error;
  int _searchId = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_results == null && _error == null) _search();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final id = ++_searchId;
    setState(() {
      _results = null;
      _error = null;
    });
    try {
      final results = (await AppScope.of(context).artistImages!.search(_query.text))
        ..sort((a, b) => b.fans.compareTo(a.fans));
      if (mounted && id == _searchId) setState(() => _results = results);
    } catch (_) {
      if (mounted && id == _searchId) setState(() => _error = 'Couldn\'t search right now. Check your connection.');
    }
  }

  Future<void> _choose(String? url) async {
    await AppScope.of(context).artistImages!.setImage(widget.artist, url);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final current = AppScope.of(context).artistImages!.imageFor(widget.artist);
    final results = _results;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text('Background for ${widget.artist}', style: theme.textTheme.titleLarge),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            key: const ValueKey('image-search-field'),
            controller: _query,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search artists'),
            onChanged: (_) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 400), _search);
            },
            onSubmitted: (_) => _search(),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _error != null
              ? Center(child: Text(_error!, style: TextStyle(color: muted)))
              : results == null
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      children: [
                        ListTile(
                          key: const ValueKey('image-none'),
                          leading: const CircleAvatar(child: Icon(Icons.hide_image_outlined)),
                          title: const Text('No image'),
                          subtitle: const Text('Show this artist\'s album covers instead'),
                          onTap: () => _choose(null),
                        ),
                        if (results.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text('No artists found', textAlign: TextAlign.center, style: TextStyle(color: muted)),
                          ),
                        for (final (i, r) in results.indexed)
                          ListTile(
                            key: ValueKey('image-option-$i'),
                            leading: CircleAvatar(backgroundImage: NetworkImage(r.thumbUrl), onBackgroundImageError: (_, _) {}),
                            title: Text(r.name),
                            subtitle: Text('${_fans(r.fans)} fans on Deezer'),
                            trailing: r.imageUrl == current
                                ? Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary)
                                : null,
                            onTap: () => _choose(r.imageUrl),
                          ),
                      ],
                    ),
        ),
      ],
    );
  }

  static String _fans(int n) => n >= 1000000
      ? '${(n / 1000000).toStringAsFixed(1)}M'
      : n >= 1000
          ? '${(n / 1000).round()}K'
          : '$n';
}
