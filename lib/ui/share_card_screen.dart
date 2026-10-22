import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../logic/ranking.dart';
import '../models/album.dart';
import 'widgets/rank_medal.dart';
import 'widgets/rating_widgets.dart';

/// One row on a share card: a ranked group or album.
class ShareEntry {
  const ShareEntry({required this.rank, required this.label, required this.detail, required this.rating, this.album, this.quality});

  final int rank;
  final String label;
  final String detail;
  final num rating;

  /// Set for album rows so the card can show the cover.
  final Album? album;

  /// Set when the row's score is a quality coefficient rather than an average.
  final double? quality;

  static List<ShareEntry> fromGroups(List<RankedGroup> groups, {required bool quality}) => [
        for (final g in groups)
          ShareEntry(
            rank: g.rank,
            label: g.label,
            detail: '${g.count} album${g.count == 1 ? '' : 's'}${quality ? ' · avg ${g.average}' : ''}',
            rating: g.average,
            quality: quality ? g.quality : null,
          ),
      ];

  static List<ShareEntry> fromAlbums(List<({int rank, Album album})> ranked, {bool showArtist = true}) => [
        for (final r in ranked)
          ShareEntry(
            rank: r.rank,
            label: r.album.title,
            detail: showArtist ? '${r.album.artist} · ${r.album.year}' : '${r.album.year}',
            rating: r.album.rating,
            album: r.album,
          ),
      ];
}

/// Preview of a shareable top-N image, with a button that sends it through
/// the Android share sheet.
class ShareCardScreen extends StatefulWidget {
  const ShareCardScreen({super.key, required this.title, required this.subtitle, required this.entries});

  /// Builds the heading for the chosen count, e.g. 10 → "My top 10 artists".
  final String Function(int count) title;
  final String subtitle;
  final List<ShareEntry> entries;

  @override
  State<ShareCardScreen> createState() => _ShareCardScreenState();
}

class _ShareCardScreenState extends State<ShareCardScreen> {
  final _boundary = GlobalKey();
  int _count = 10;
  bool _sharing = false;

  List<int> get _options => [5, 10, 25].where((n) => n < widget.entries.length).toList()..add(widget.entries.length);

  @override
  void initState() {
    super.initState();
    if (widget.entries.length < _count) _count = widget.entries.length;
  }

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final render = _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 1080 / render.size.width);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(bytes!.buffer.asUint8List(), mimeType: 'image/png')],
        fileNameOverrides: ['AlbumRank.png'],
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not share: $e')));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = {..._options}.toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Share')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          if (options.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SegmentedButton<int>(
                key: const ValueKey('share-count'),
                showSelectedIcon: false,
                segments: [
                  for (final n in options)
                    ButtonSegment(value: n, label: Text(n == widget.entries.length && n > 25 ? 'All' : 'Top $n')),
                ],
                selected: {_count},
                onSelectionChanged: (s) => setState(() => _count = s.first),
              ),
            ),
          RepaintBoundary(
            key: _boundary,
            child: ShareCard(
              title: widget.title(_count),
              subtitle: widget.subtitle,
              entries: widget.entries.take(_count).toList(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: SizedBox(
            height: 54,
            child: FilledButton.icon(
              key: const ValueKey('share-image'),
              style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              onPressed: _sharing ? null : _share,
              icon: const Icon(Icons.ios_share_rounded),
              label: const Text('Share image', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ),
    );
  }
}

/// The image itself: always drawn in AlbumRank's dark purple-blue style so it
/// looks the same whatever theme the phone uses.
class ShareCard extends StatelessWidget {
  const ShareCard({super.key, required this.title, required this.subtitle, required this.entries});

  final String title;
  final String subtitle;
  final List<ShareEntry> entries;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final theme = base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        brightness: Brightness.dark,
        onSurfaceVariant: Colors.white70,
        surfaceContainerHigh: const Color(0xFF2A2F48),
      ),
    );
    const muted = Color(0xB3FFFFFF);
    return Theme(
      data: theme,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF3B2C8F), Color(0xFF161A2E), Color(0xFF0E1016)],
            stops: [0, 0.45, 1],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, height: 1.15)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: muted, fontSize: 13)),
            const SizedBox(height: 14),
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    RankMedal(e.rank, width: 36),
                    const SizedBox(width: 8),
                    if (e.album != null) ...[AlbumCover(album: e.album!, size: 40), const SizedBox(width: 10)],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                          Text(e.detail,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: muted, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    e.quality != null ? RatingBadge.quality(e.quality!, size: 34) : RatingBadge(e.rating, size: 34),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.music_note_rounded, color: Color(0xFF8FB3FF), size: 16),
                Icon(Icons.star_rounded, color: Color(0xFF8FB3FF), size: 16),
                SizedBox(width: 4),
                Text('AlbumRank', style: TextStyle(color: Color(0xFF8FB3FF), fontSize: 13, fontWeight: FontWeight.w800)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
