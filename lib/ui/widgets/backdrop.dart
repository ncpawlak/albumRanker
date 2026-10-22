import 'dart:math';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../models/album.dart';

/// A network image that fades in when loaded and disappears quietly on errors.
class FadingNetworkImage extends StatelessWidget {
  const FadingNetworkImage(this.url, {super.key, this.fit = BoxFit.cover, this.alignment = Alignment.center});

  final String url;
  final BoxFit fit;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) => Image.network(
        url,
        fit: fit,
        alignment: alignment,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
        frameBuilder: (context, child, frame, sync) => sync
            ? child
            : AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOut,
                child: child,
              ),
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
}

/// Lays a very faint, slightly blurred image behind [child], fading into the
/// page color toward the bottom so text stays readable.
class Backdrop extends StatelessWidget {
  const Backdrop({super.key, required this.image, required this.child});

  /// Null shows just the plain page.
  final Widget? image;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final dark = theme.brightness == Brightness.dark;
    return Stack(
      children: [
        Positioned.fill(child: ColoredBox(color: surface)),
        if (image != null)
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: dark ? 0.32 : 0.2,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5, tileMode: TileMode.decal),
                  child: image,
                ),
              ),
            ),
          ),
        if (image != null)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [surface.withValues(alpha: 0), surface.withValues(alpha: 0.3), surface.withValues(alpha: 0.75)],
                    stops: const [0, 0.45, 1],
                  ),
                ),
              ),
            ),
          ),
        Positioned.fill(child: child),
      ],
    );
  }
}

/// The artist's band photo, looked up (once) when first shown.
class ArtistPhoto extends StatefulWidget {
  const ArtistPhoto({super.key, required this.artist, this.fallback});

  final String artist;

  /// Shown when the artist has no photo, e.g. a cover collage.
  final Widget? fallback;

  @override
  State<ArtistPhoto> createState() => _ArtistPhotoState();
}

class _ArtistPhotoState extends State<ArtistPhoto> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    AppScope.of(context).artistImages?.resolve(widget.artist);
  }

  @override
  void didUpdateWidget(ArtistPhoto old) {
    super.didUpdateWidget(old);
    if (old.artist != widget.artist) AppScope.of(context).artistImages?.resolve(widget.artist);
  }

  @override
  Widget build(BuildContext context) {
    final service = AppScope.of(context).artistImages;
    if (service == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final url = service.imageFor(widget.artist);
        if (url == null) return service.isKnown(widget.artist) ? widget.fallback ?? const SizedBox.shrink() : const SizedBox.shrink();
        return FadingNetworkImage(url, key: ValueKey(url), alignment: const Alignment(0, -0.3));
      },
    );
  }
}

/// A tilted mosaic of a group's best album covers.
class CoverCollage extends StatelessWidget {
  const CoverCollage({super.key, required this.albums});

  final List<Album> albums;

  /// Covers to use: highest rated first, up to 12.
  static List<String> coversFor(Iterable<Album> albums) {
    final withArt = albums.where((a) => a.artworkUrl != null).toList()
      ..sort((a, b) => b.rating.compareTo(a.rating));
    return [for (final a in withArt.take(12)) a.artworkUrl!.replaceFirst('600x600bb', '300x300bb')];
  }

  @override
  Widget build(BuildContext context) {
    final covers = coversFor(albums);
    if (covers.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(builder: (context, c) {
      // Oversize and rotate the grid so its edges never show.
      final w = c.maxWidth * 1.5, h = c.maxHeight * 1.5;
      const cols = 3;
      final tile = w / cols;
      final rows = (h / tile).ceil();
      var i = 0;
      return ClipRect(
        child: OverflowBox(
          maxWidth: w,
          maxHeight: h,
          child: Transform.rotate(
            angle: -pi / 14,
            child: Column(
              children: [
                for (var r = 0; r < rows; r++)
                  Row(
                    children: [
                      for (var col = 0; col < cols; col++)
                        SizedBox(
                          width: tile,
                          height: tile,
                          child: FadingNetworkImage(covers[(i++ + r) % covers.length]),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
