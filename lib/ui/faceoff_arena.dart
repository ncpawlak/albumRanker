import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_scope.dart';
import '../logic/faceoff.dart';
import '../models/album.dart';
import '../theme/rating_colors.dart';
import 'widgets/rating_widgets.dart';

enum _Phase { entering, choosing, prompting, decided, finished }

/// The face-off experience: two albums fly in, collide, bounce apart to reveal
/// their details, and the user picks a winner and optionally nudges ratings.
class FaceOffArena extends StatefulWidget {
  const FaceOffArena({super.key, required this.pool, required this.match, this.rounds, this.random});

  final List<Album> pool;
  final FaceOffMatch match;

  /// Null for endless.
  final int? rounds;

  /// Injectable for tests.
  final Random? random;

  @override
  State<FaceOffArena> createState() => _FaceOffArenaState();
}

class _FaceOffArenaState extends State<FaceOffArena> with TickerProviderStateMixin {
  static const _impactAt = 0.32;

  late FaceOffSession _session;
  late final AnimationController _enter =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..addListener(_onEnterTick);
  late final AnimationController _pick = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
  late final AnimationController _exit = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));

  _Phase _phase = _Phase.entering;
  Album? _left, _right;
  String? _winnerId;
  int _resultIndex = -1;
  List<FaceOffOption> _options = const [];
  String _outcome = '';
  bool _impactFired = false;
  bool _outOfPairs = false;

  @override
  void initState() {
    super.initState();
    _session = FaceOffSession(widget.pool, widget.match, rounds: widget.rounds, random: widget.random);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadNext());
  }

  @override
  void dispose() {
    _enter.dispose();
    _pick.dispose();
    _exit.dispose();
    super.dispose();
  }

  void _onEnterTick() {
    if (!_impactFired && _enter.value >= _impactAt) {
      _impactFired = true;
      HapticFeedback.heavyImpact();
    }
  }

  Album _live(Album a) => AppScope.of(context).repository.byId(a.id) ?? a;

  void _loadNext() {
    if (!mounted) return;
    final pair = _session.next(AppScope.of(context).repository.albums);
    if (pair == null) {
      _outOfPairs = !_session.roundsDone;
      _finish();
      return;
    }
    setState(() {
      _left = pair.$1;
      _right = pair.$2;
      _winnerId = null;
      _resultIndex = -1;
      _options = const [];
      _outcome = '';
      _impactFired = false;
      _phase = _Phase.entering;
    });
    _pick.value = 0;
    _exit.value = 0;
    _enter.forward(from: 0).whenComplete(() {
      if (mounted && _phase == _Phase.entering) setState(() => _phase = _Phase.choosing);
    });
  }

  void _choose(Album? winner) {
    if (_phase != _Phase.choosing) return;
    final left = _live(_left!), right = _live(_right!);
    final repo = AppScope.of(context).repository;
    HapticFeedback.selectionClick();
    _resultIndex = _session.record(left, right, winner?.id);
    if (winner == null) {
      setState(() {
        _phase = _Phase.decided;
        _outcome = 'Too close to call';
      });
      _pick.forward(from: 0);
      return;
    }
    final loser = winner.id == left.id ? right : left;
    repo.recordFaceOff(winnerId: winner.id, loserId: loser.id);
    final options = faceOffOptions(winner, loser);
    setState(() {
      _winnerId = winner.id;
      _options = options;
      if (options.isEmpty) {
        _phase = _Phase.decided;
        _outcome = 'Your ratings already agree';
      } else {
        _phase = _Phase.prompting;
      }
    });
    _pick.forward(from: 0);
  }

  Future<void> _applyOption(FaceOffOption? option) async {
    if (_phase != _Phase.prompting) return;
    if (option != null) {
      await AppScope.of(context).repository.setRatings(option.changes);
      _session.attachChanges(_resultIndex, option.changes);
      HapticFeedback.mediumImpact();
    }
    if (!mounted) return;
    setState(() {
      _phase = _Phase.decided;
      _outcome = option == null
          ? 'Ratings kept'
          : option.label.replaceFirst(RegExp(r'^Raise'), 'Raised').replaceFirst(RegExp(r'^Lower'), 'Lowered').replaceFirst(RegExp(r'^Both:'), 'Now');
    });
  }

  Future<void> _next() async {
    if (_phase != _Phase.decided) return;
    if (_session.roundsDone) {
      _finish();
      return;
    }
    await _exit.forward(from: 0);
    _loadNext();
  }

  void _finish() {
    if (_session.results.isEmpty && !_outOfPairs) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _phase = _Phase.finished);
  }

  void _restart() {
    setState(() {
      _session = FaceOffSession(widget.pool, widget.match, rounds: widget.rounds, random: widget.random);
      _outOfPairs = false;
    });
    _loadNext();
  }

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context).repository;
    return Scaffold(
      backgroundColor: const Color(0xFF090A10),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.2),
            radius: 1.1,
            colors: [Color(0xFF241B55), Color(0xFF0E1016), Color(0xFF090A10)],
            stops: [0, 0.6, 1],
          ),
        ),
        child: SafeArea(
          child: ListenableBuilder(
            listenable: repo,
            builder: (context, _) => AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: _phase == _Phase.finished
                  ? _Recap(
                      key: const ValueKey('recap'),
                      results: _session.results,
                      outOfPairs: _outOfPairs,
                      onDone: () => Navigator.of(context).pop(),
                      onAgain: _restart,
                    )
                  : _arena(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _arena(BuildContext context) {
    final theme = Theme.of(context);
    final rounds = widget.rounds;
    final shownRound = _phase == _Phase.entering || _phase == _Phase.choosing
        ? _session.results.length + 1
        : _session.results.length;
    return Column(
      key: const ValueKey('arena'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
          child: Row(
            children: [
              IconButton(
                key: const ValueKey('faceoff-stop'),
                tooltip: 'Stop',
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
                onPressed: _finish,
              ),
              const Spacer(),
              Text(
                rounds == null ? 'Round $shownRound' : 'Round ${min(shownRound, rounds)} of $rounds',
                key: const ValueKey('faceoff-round'),
                style: theme.textTheme.titleSmall?.copyWith(color: Colors.white70, letterSpacing: 1.2),
              ),
              const Spacer(),
              const SizedBox(width: 48),
            ],
          ),
        ),
        if (rounds != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _session.results.length / rounds,
                minHeight: 4,
                backgroundColor: Colors.white10,
              ),
            ),
          ),
        Expanded(child: _left == null ? const SizedBox.shrink() : _stage(context)),
        _panel(context),
      ],
    );
  }

  Widget _stage(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final slot = (w - 24) / 2;
      final cover = min(slot - 20, 170.0);
      final collide = (slot - cover) / 2 + 6;
      const coverTop = 30.0;
      // Roughly centers covers + details in the space above the prompt.
      final top = c.maxHeight.isFinite ? max(24.0, (c.maxHeight - (coverTop + cover + 16 + 120)) / 2) : 24.0;
      return AnimatedBuilder(
        animation: Listenable.merge([_enter, _pick, _exit]),
        builder: (context, _) {
          final t = _enter.value;
          final a = Curves.easeInCubic.transform((t / _impactAt).clamp(0.0, 1.0));
          final b = Curves.easeOutBack.transform(((t - _impactAt) / 0.3).clamp(0.0, 1.0));
          final inward = t < _impactAt ? _lerp(-w, collide, a) : _lerp(collide, 0, b);
          final tilt = t < _impactAt ? _lerp(-0.45, 0, a) : 0.14 * (1 - b) * sin(b * pi * 2);
          final sinceImpact = t - _impactAt;
          final squash = sinceImpact >= 0 && sinceImpact < 0.1 ? 1 - 0.14 * sin(pi * sinceImpact / 0.1) : 1.0;
          final shake = sinceImpact >= 0 && sinceImpact < 0.2 ? sin(sinceImpact * 95) * 9 * (1 - sinceImpact / 0.2) : 0.0;
          final burstP = ((t - _impactAt) / 0.28).clamp(0.0, 1.0);
          final burstOn = t >= _impactAt && burstP < 1;
          final vs = Curves.elasticOut.transform(((t - 0.38) / 0.4).clamp(0.0, 1.0));
          final p = _pick.value;
          final e = Curves.easeInCubic.transform(_exit.value);
          final coverTop = 30.0;

          Widget fighter(Album album, int side) {
            final live = _live(album);
            final decided = _phase == _Phase.prompting || _phase == _Phase.decided;
            final isWinner = decided && _winnerId == album.id;
            final isLoser = decided && _winnerId != null && !isWinner;
            final details = ((t - (side < 0 ? 0.6 : 0.68)) / 0.22).clamp(0.0, 1.0);
            final pickScale = isWinner
                ? 1 + 0.07 * Curves.easeOutBack.transform(p)
                : isLoser
                    ? 1 - 0.1 * p
                    : 1.0;
            return Transform.translate(
              offset: Offset(side * -inward + side * w * e, isLoser ? 14 * p : 0),
              child: Opacity(
                opacity: (1 - e) * (isLoser ? 1 - 0.55 * p : 1),
                child: GestureDetector(
                  key: ValueKey('fighter-${side < 0 ? 'left' : 'right'}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _choose(live),
                  child: SizedBox(
                    width: slot,
                    child: Column(
                      children: [
                        SizedBox(
                          height: coverTop,
                          child: isWinner
                              ? Opacity(
                                  opacity: p.clamp(0.0, 1.0),
                                  child: Transform.translate(
                                    offset: Offset(0, -18 * (1 - p)),
                                    child: const Icon(Icons.emoji_events_rounded,
                                        key: ValueKey('winner-crown'), color: Color(0xFFFFD54F), size: 28),
                                  ),
                                )
                              : null,
                        ),
                        Transform.rotate(
                          angle: side * -tilt,
                          child: Transform.scale(
                            scaleX: squash * pickScale,
                            scaleY: (2 - squash) * pickScale,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(cover * 0.12),
                                boxShadow: [
                                  BoxShadow(
                                    color: (isWinner ? ratingColor(live.rating) : Colors.black)
                                        .withValues(alpha: isWinner ? 0.7 * p : 0.5),
                                    blurRadius: isWinner ? 36 * p : 18,
                                    spreadRadius: isWinner ? 4 * p : 0,
                                  ),
                                ],
                              ),
                              child: AlbumCover(album: live, size: cover),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Opacity(
                          opacity: details,
                          child: Transform.translate(
                            offset: Offset(0, 16 * (1 - details)),
                            child: _Details(album: live),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          return Transform.translate(
            offset: Offset(shake, 0),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (burstOn)
                  Positioned(
                    left: w / 2 - w * 0.75 * Curves.easeOut.transform(burstP),
                    top: top + coverTop + cover / 2 - w * 0.75 * Curves.easeOut.transform(burstP),
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: (1 - burstP) * 0.9,
                        child: Container(
                          width: w * 1.5 * Curves.easeOut.transform(burstP),
                          height: w * 1.5 * Curves.easeOut.transform(burstP),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(colors: [Colors.white, Color(0xFF8A5BFF), Color(0x008A5BFF)]),
                          ),
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.fromLTRB(12, top, 12, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [fighter(_left!, -1), fighter(_right!, 1)],
                  ),
                ),
                Positioned(
                  left: w / 2 - 28,
                  top: top + coverTop + cover / 2 - 28,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: (vs.clamp(0.0, 1.0)) * (1 - p) * (1 - e),
                      child: Transform.scale(scale: vs, child: const _VsBadge()),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    });
  }

  Widget _panel(BuildContext context) {
    final theme = Theme.of(context);
    final white = theme.textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800);
    final Widget child;
    switch (_phase) {
      case _Phase.entering:
        child = const SizedBox(key: ValueKey('panel-empty'), height: 120);
      case _Phase.choosing:
        child = Column(
          key: const ValueKey('panel-choose'),
          children: [
            Text('Which one is better?', style: white),
            const SizedBox(height: 4),
            Text('Tap an album', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white60)),
            const SizedBox(height: 8),
            TextButton(
              key: const ValueKey('faceoff-too-close'),
              onPressed: () => _choose(null),
              child: const Text('Too close to call'),
            ),
          ],
        );
      case _Phase.prompting:
        final winner = _live(_winnerId == _left!.id ? _left! : _right!);
        child = Column(
          key: const ValueKey('panel-prompt'),
          children: [
            Text('${winner.title} wins!', textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: white),
            const SizedBox(height: 4),
            Text('Adjust the ratings?', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white60)),
            const SizedBox(height: 12),
            for (final (i, o) in _options.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    key: ValueKey('faceoff-option-$i'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => _applyOption(o),
                    child: Text(o.label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ),
            TextButton(
              key: const ValueKey('faceoff-keep'),
              onPressed: () => _applyOption(null),
              child: const Text('Keep ratings'),
            ),
          ],
        );
      case _Phase.decided:
        final last = _session.roundsDone;
        child = Column(
          key: const ValueKey('panel-decided'),
          children: [
            Text(_outcome,
                key: const ValueKey('faceoff-outcome'),
                style: white,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('faceoff-finish'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _finish,
                    child: const Text('Stop'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    key: const ValueKey('faceoff-next'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _next,
                    icon: Icon(last ? Icons.flag_rounded : Icons.bolt_rounded),
                    label: Text(last ? 'See results' : 'Next match-up',
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ],
        );
      case _Phase.finished:
        child = const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.15), end: Offset.zero).animate(anim),
              child: child,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

class _VsBadge extends StatelessWidget {
  const _VsBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(colors: [Color(0xFF5B8CFF), Color(0xFF8A5BFF)]),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: Color(0xAA8A5BFF), blurRadius: 24, spreadRadius: 2)],
      ),
      child: const Text('VS',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, fontStyle: FontStyle.italic)),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.album});

  final Album album;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(album.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, height: 1.2)),
        const SizedBox(height: 4),
        Text(album.artist,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 13)),
        Text('${album.year} · ${album.genre}',
            textAlign: TextAlign.center, style: const TextStyle(color: Colors.white38, fontSize: 12)),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 450),
          transitionBuilder: (child, anim) =>
              ScaleTransition(scale: CurvedAnimation(parent: anim, curve: Curves.elasticOut), child: child),
          child: RatingBadge(album.rating, key: ValueKey('rating-${album.id}-${album.rating}'), size: 42),
        ),
        if (album.wins + album.losses > 0) ...[
          const SizedBox(height: 6),
          Text('${album.wins}–${album.losses} in face-offs',
              style: const TextStyle(color: Colors.white38, fontSize: 11.5)),
        ],
      ],
    );
  }
}

class _Recap extends StatelessWidget {
  const _Recap({super.key, required this.results, required this.outOfPairs, required this.onDone, required this.onAgain});

  final List<FaceOffResult> results;
  final bool outOfPairs;
  final VoidCallback onDone;
  final VoidCallback onAgain;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final changed = results.fold(0, (n, r) => n + r.changes.length);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
            children: [
              const Icon(Icons.bolt_rounded, color: Color(0xFFFFD54F), size: 48),
              const SizedBox(height: 8),
              Text('Face-off complete',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                '${results.length} match-up${results.length == 1 ? '' : 's'} · '
                '$changed rating${changed == 1 ? '' : 's'} changed',
                key: const ValueKey('recap-summary'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white60),
              ),
              if (outOfPairs)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('You played every match-up in this selection',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.white38)),
                ),
              const SizedBox(height: 20),
              for (final r in results) _RecapRow(result: r),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('recap-again'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: outOfPairs ? null : onAgain,
                  child: const Text('Go again'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: const ValueKey('recap-done'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: onDone,
                  child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecapRow extends StatelessWidget {
  const _RecapRow({required this.result});

  final FaceOffResult result;

  @override
  Widget build(BuildContext context) {
    Widget side(Album a) {
      final won = result.winnerId == a.id;
      final to = result.changes[a.id];
      return Expanded(
        child: Opacity(
          opacity: result.winnerId == null || won ? 1 : 0.55,
          child: Row(
            children: [
              AlbumCover(album: a, size: 40),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (won) ...[
                          const Icon(Icons.emoji_events_rounded, size: 14, color: Color(0xFFFFD54F)),
                          const SizedBox(width: 3),
                        ],
                        Expanded(
                          child: Text(a.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                      ],
                    ),
                    Text(
                      to == null ? formatRating(a.rating) : '${formatRating(a.rating)} → ${formatRating(to)}',
                      style: TextStyle(
                        color: to == null ? Colors.white54 : ratingColor(to),
                        fontWeight: to == null ? FontWeight.w400 : FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          side(result.left),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text('vs', style: TextStyle(color: Colors.white38, fontStyle: FontStyle.italic)),
          ),
          side(result.right),
        ],
      ),
    );
  }
}
