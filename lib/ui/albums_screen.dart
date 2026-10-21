import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models/album.dart';
import '../theme/app_theme.dart';
import 'album_edit_screen.dart';
import 'widgets/album_tile.dart';

enum AlbumSort {
  topRated('Top rated'),
  recent('Recently added'),
  title('A–Z'),
  artist('Artist'),
  year('Year');

  const AlbumSort(this.label);
  final String label;
}

List<Album> sortAndFilterAlbums(List<Album> albums, AlbumSort sort, String query) {
  final q = query.trim().toLowerCase();
  final list = q.isEmpty
      ? List<Album>.of(albums)
      : albums
          .where((a) =>
              a.title.toLowerCase().contains(q) ||
              a.artist.toLowerCase().contains(q) ||
              a.genre.toLowerCase().contains(q) ||
              '${a.year}'.contains(q))
          .toList();
  int byTitle(Album a, Album b) => a.title.toLowerCase().compareTo(b.title.toLowerCase());
  switch (sort) {
    case AlbumSort.topRated:
      list.sort((a, b) {
        final c = b.rating.compareTo(a.rating);
        return c != 0 ? c : byTitle(a, b);
      });
    case AlbumSort.recent:
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    case AlbumSort.title:
      list.sort(byTitle);
    case AlbumSort.artist:
      list.sort((a, b) {
        final c = a.artist.toLowerCase().compareTo(b.artist.toLowerCase());
        if (c != 0) return c;
        final y = a.year.compareTo(b.year);
        return y != 0 ? y : byTitle(a, b);
      });
    case AlbumSort.year:
      list.sort((a, b) {
        final c = b.year.compareTo(a.year);
        return c != 0 ? c : byTitle(a, b);
      });
  }
  return list;
}

class AlbumsScreen extends StatefulWidget {
  const AlbumsScreen({super.key});

  @override
  State<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends State<AlbumsScreen> {
  AlbumSort _sort = AlbumSort.topRated;
  String _query = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openEditor([Album? album]) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => AlbumEditScreen(album: album)));
  }

  Future<void> _delete(Album album) async {
    final repo = AppScope.of(context).repository;
    final messenger = ScaffoldMessenger.of(context);
    await repo.delete(album.id);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Deleted "${album.title}"'),
        action: SnackBarAction(label: 'Undo', onPressed: () => repo.restore(album)),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context).repository;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Albums'),
        centerTitle: false,
        toolbarHeight: 64,
      ),
      floatingActionButton: _GradientFab(onPressed: () => _openEditor()),
      body: ListenableBuilder(
        listenable: repo,
        builder: (context, _) {
          final all = repo.albums;
          final albums = sortAndFilterAlbums(all, _sort, _query);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Search albums, artists, genres…',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final s in AlbumSort.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(s.label),
                          selected: _sort == s,
                          onSelected: (_) => setState(() => _sort = s),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _query.isEmpty ? '${all.length} albums' : '${albums.length} of ${all.length} albums',
                    style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
              Expanded(
                child: all.isEmpty
                    ? _EmptyState(onAdd: () => _openEditor())
                    : albums.isEmpty
                        ? Center(
                            child: Text('No matches', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 96),
                            itemCount: albums.length,
                            itemBuilder: (context, i) {
                              final album = albums[i];
                              return Dismissible(
                                key: ValueKey(album.id),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  color: theme.colorScheme.errorContainer,
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 24),
                                  child: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.onErrorContainer),
                                ),
                                onDismissed: (_) => _delete(album),
                                child: AlbumTile(album: album, onTap: () => _openEditor(album)),
                              );
                            },
                          ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GradientFab extends StatelessWidget {
  const _GradientFab({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Add album',
      child: Container(
        decoration: BoxDecoration(
          gradient: accentGradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: const Color(0xFF5B8CFF).withValues(alpha: 0.45), blurRadius: 24, offset: const Offset(0, 8)),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: const ValueKey('add-album'),
            borderRadius: BorderRadius.circular(18),
            onTap: onPressed,
            child: const SizedBox(
              width: 58,
              height: 58,
              child: Icon(Icons.add_rounded, color: Colors.white, size: 32),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.album_rounded, size: 72, color: theme.colorScheme.primary.withValues(alpha: 0.6)),
            const SizedBox(height: 16),
            Text('No albums yet', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Add your first album to start ranking.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add_rounded), label: const Text('Add album')),
          ],
        ),
      ),
    );
  }
}
