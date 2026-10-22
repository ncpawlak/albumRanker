import 'package:flutter/material.dart';

import '../app_scope.dart';
import 'artist_image_picker.dart';

/// Every artist with their background photo; tap one to search for a better image.
class ArtistImagesScreen extends StatefulWidget {
  const ArtistImagesScreen({super.key});

  @override
  State<ArtistImagesScreen> createState() => _ArtistImagesScreenState();
}

class _ArtistImagesScreenState extends State<ArtistImagesScreen> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final images = scope.artistImages;
    final theme = Theme.of(context);
    final artists = {for (final a in scope.repository.albums) a.artist.trim(): true}.keys
        .where((a) => a.isNotEmpty && a.toLowerCase().contains(_filter))
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return Scaffold(
      appBar: AppBar(title: const Text('Artist backgrounds')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              key: const ValueKey('artist-images-filter'),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Find an artist',
                isDense: true,
              ),
              onChanged: (v) => setState(() => _filter = v.trim().toLowerCase()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('Wrong photo? Tap an artist to search for the right one.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          Expanded(
            child: images == null
                ? const Center(child: Text('Artist photos are unavailable'))
                : ListenableBuilder(
                    listenable: images,
                    builder: (context, _) => ListView.builder(
                      itemCount: artists.length,
                      itemBuilder: (context, i) {
                        final artist = artists[i];
                        final url = images.imageFor(artist);
                        return ListTile(
                          key: ValueKey('artist-image-$artist'),
                          leading: CircleAvatar(
                            radius: 22,
                            backgroundColor: theme.colorScheme.surfaceContainerHighest,
                            foregroundImage: url == null ? null : NetworkImage(url),
                            onForegroundImageError: url == null ? null : (_, _) {},
                            child: const Icon(Icons.person_rounded),
                          ),
                          title: Text(artist),
                          subtitle: Text(url != null
                              ? 'Photo set'
                              : images.isKnown(artist)
                                  ? 'No photo · uses cover collage'
                                  : 'Not looked up yet'),
                          trailing: const Icon(Icons.image_search_rounded),
                          onTap: () => showArtistImagePicker(context, artist),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
