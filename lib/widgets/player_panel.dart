import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

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
  });

  final Player player;
  final VideoController controller;
  final Channel? channel;
  final VoidCallback onRetry;

  /// Fired once per channel when playback errors — lets the parent auto-skip.
  final VoidCallback? onError;

  @override
  State<PlayerPanel> createState() => _PlayerPanelState();
}

class _PlayerPanelState extends State<PlayerPanel> {
  bool _buffering = false;
  String? _error;
  bool _reported = false; // guard: report each failure once per channel
  Timer? _watchdog; // fires if a source buffers forever without erroring
  final List<StreamSubscription> _subs = [];

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
      setState(() => _error = e);
      _fail();
    }));
    // Playback started → cancel watchdog + clear any stale error.
    _subs.add(widget.player.stream.playing.listen((p) {
      if (!p) return;
      _watchdog?.cancel();
      if (mounted && _error != null) setState(() => _error = null);
    }));
    // Resolution variants exposed by the current source.
    _subs.add(widget.player.stream.tracks.listen((t) {
      if (!mounted) return;
      // Drop the synthetic "auto"/"no" entries; we add Auto ourselves.
      final real = t.video
          .where((v) => v.id != 'auto' && v.id != 'no')
          .toList();
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
        setState(() => _error ??= 'Stream timed out');
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

          if (widget.channel != null && _videoTracks.isNotEmpty)
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

  String get _currentLabel {
    final a = active;
    if (a == null || a.id == 'auto') return 'Auto';
    return labelOf(a);
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Quality',
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
          child: const Text('Auto', style: TextStyle(color: Colors.white)),
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
              _currentLabel,
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
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sports_soccer, color: Colors.white24, size: 72),
          SizedBox(height: 12),
          Text(
            'Pick a channel to start watching',
            style: TextStyle(color: Colors.white54, fontSize: 16),
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
              const Text(
                'Stream unavailable',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'This source may be offline or geo-blocked. Try another.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}