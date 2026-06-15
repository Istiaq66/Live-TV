import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../l10n/app_localizations.dart';
import '../models/channel.dart';

/// Video surface + live status overlay (buffering / error / now-playing).
class PlayerPanel extends StatefulWidget {
  const PlayerPanel({
    super.key,
    required this.player,
    required this.controller,
    required this.channel,
    required this.onRetry,
    this.onError,
    this.onPlaying,
  });

  final Player player;
  final VideoController controller;
  final Channel? channel;
  final VoidCallback onRetry;

  /// Fired once per channel when playback errors — lets the parent auto-skip.
  final VoidCallback? onError;

  /// Fired when the current channel actually starts playing — the only
  /// trustworthy "this stream works" signal (a URL responding isn't enough).
  final VoidCallback? onPlaying;

  @override
  State<PlayerPanel> createState() => _PlayerPanelState();
}

class _PlayerPanelState extends State<PlayerPanel> {
  bool _buffering = false;
  String? _error;
  bool _reported = false; // guard: report each failure once per channel
  Timer? _watchdog; // fires if a source buffers forever without erroring
  final List<StreamSubscription> _subs = [];

  // The player is shared across channels, so a trailing error event from the
  // previous source can arrive just after we switch. Ignore error events for a
  // brief settle window after a channel change so we don't wrongly blame (and
  // auto-skip away from) the newly selected channel. The watchdog still catches
  // a source that genuinely never starts.
  DateTime? _switchedAt;
  static const Duration _settle = Duration(milliseconds: 1500);
  bool get _isSettling =>
      _switchedAt != null && DateTime.now().difference(_switchedAt!) < _settle;

  // Resolution picker: available HLS variant video tracks + the active one.
  // `VideoTrack.auto()` lets mpv adapt bitrate to bandwidth (the default).
  List<VideoTrack> _videoTracks = const [];
  VideoTrack? _activeVideo;

  // Out-of-region links need some slack to fill the buffer, but with the
  // shorter readahead a live source should start well inside this window —
  // past it, treat the source as dead and auto-skip.
  static const Duration _stallTimeout = Duration(seconds: 18);

  @override
  void initState() {
    super.initState();
    _subs.add(widget.player.stream.buffering.listen((b) {
      if (!mounted) return;
      setState(() => _buffering = b);
      if (b) {
        _startWatchdog();
      } else {
        _watchdog?.cancel();
      }
    }));
    _subs.add(widget.player.stream.error.listen((e) {
      if (!mounted) return;
      // Drop a stale error bleeding over from the previous channel's stream.
      if (_isSettling) return;
      setState(() => _error = e);
      _fail();
    }));
    // Playback started → cancel watchdog, clear stale error, mark working.
    _subs.add(widget.player.stream.playing.listen((p) {
      if (!p) return;
      _watchdog?.cancel();
      if (mounted && _error != null) setState(() => _error = null);
      widget.onPlaying?.call();
    }));
    // Resolution variants exposed by the current source.
    _subs.add(widget.player.stream.tracks.listen((t) {
      if (!mounted) return;
      // Drop the synthetic "auto"/"no" entries; we add Auto ourselves.
      // Sort highest resolution first (1080p → 720p → 480p …).
      final real = t.video
          .where((v) => v.id != 'auto' && v.id != 'no')
          .toList()
        ..sort((a, b) => (b.h ?? 0).compareTo(a.h ?? 0));
      setState(() => _videoTracks = real);
    }));
    _subs.add(widget.player.stream.track.listen((t) {
      if (!mounted) return;
      setState(() => _activeVideo = t.video);
    }));
  }

  /// Human label for a variant: prefer height (e.g. "720p"), else its title/id.
  String _trackLabel(VideoTrack t) {
    final h = t.h;
    if (h != null && h > 0) return '${h}p';
    final title = t.title;
    if (title != null && title.trim().isNotEmpty) return title.trim();
    return 'Track ${t.id}';
  }

  void _selectTrack(VideoTrack t) {
    widget.player.setVideoTrack(t);
    setState(() => _activeVideo = t);
  }

  void _startWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer(_stallTimeout, () {
      if (!mounted) return;
      if (!widget.player.state.playing) {
        setState(() => _error ??= AppLocalizations.of(context).streamTimedOut);
        _fail();
      }
    });
  }

  /// Report the failure to the parent exactly once for this channel.
  void _fail() {
    if (_reported) return;
    _reported = true;
    widget.onError?.call();
  }

  @override
  void didUpdateWidget(PlayerPanel old) {
    super.didUpdateWidget(old);
    // New channel selected → drop the previous error banner + re-arm reporting.
    if (old.channel?.url != widget.channel?.url) {
      _reported = false;
      _switchedAt = DateTime.now(); // start settle window for stale errors
      _watchdog?.cancel();
      setState(() {
        _error = null;
        _videoTracks = const []; // variants repopulate for the new source
        _activeVideo = null;
      });
    }
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.channel == null)
            const _EmptyState()
          else
            Video(controller: widget.controller, controls: AdaptiveVideoControls),

          if (_buffering && _error == null)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),

          if (_error != null) _ErrorState(error: _error!, onRetry: widget.onRetry),

          if (widget.channel != null)
            Positioned(
              left: 12,
              top: 12,
              child: _NowPlayingBadge(channel: widget.channel!),
            ),

          // Always show when a channel is playing. With a multi-variant HLS
          // source the menu lists Auto + each resolution (1080p/720p/480p…);
          // single-quality sources show just Auto.
          if (widget.channel != null)
            Positioned(
              right: 12,
              top: 12,
              child: _QualityMenu(
                tracks: _videoTracks,
                active: _activeVideo,
                labelOf: _trackLabel,
                onAuto: () => _selectTrack(VideoTrack.auto()),
                onPick: _selectTrack,
              ),
            ),
        ],
      ),
    );
  }
}

/// Resolution selector: "Auto" plus each HLS variant the source exposes.
class _QualityMenu extends StatelessWidget {
  const _QualityMenu({
    required this.tracks,
    required this.active,
    required this.labelOf,
    required this.onAuto,
    required this.onPick,
  });

  final List<VideoTrack> tracks;
  final VideoTrack? active;
  final String Function(VideoTrack) labelOf;
  final VoidCallback onAuto;
  final ValueChanged<VideoTrack> onPick;

  bool get _isAuto => active == null || active!.id == 'auto';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final currentLabel = _isAuto ? l.qualityAuto : labelOf(active!);
    return PopupMenuButton<String>(
      tooltip: l.quality,
      color: Colors.black87,
      onSelected: (id) {
        if (id == 'auto') {
          onAuto();
        } else {
          final t = tracks.where((v) => v.id == id);
          if (t.isNotEmpty) onPick(t.first);
        }
      },
      itemBuilder: (_) => [
        CheckedPopupMenuItem<String>(
          value: 'auto',
          checked: _isAuto,
          child: Text(l.qualityAuto, style: const TextStyle(color: Colors.white)),
        ),
        for (final t in tracks)
          CheckedPopupMenuItem<String>(
            value: t.id,
            checked: !_isAuto && active!.id == t.id,
            child: Text(labelOf(t), style: const TextStyle(color: Colors.white)),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hd, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              currentLabel,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _NowPlayingBadge extends StatelessWidget {
  const _NowPlayingBadge({required this.channel});
  final Channel channel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.sensors, color: Colors.redAccent, size: 16),
          const SizedBox(width: 6),
          Text(
            '${channel.flag != null ? '${channel.flag} ' : ''}${channel.name}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.live_tv, color: Colors.white24, size: 72),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context).pickChannel,
            style: const TextStyle(color: Colors.white54, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.all(16),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.orangeAccent, size: 48),
              const SizedBox(height: 10),
              Text(
                l.streamUnavailable,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                l.streamUnavailableHint,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(l.retry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}