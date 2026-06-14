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
  });

  final Player player;
  final VideoController controller;
  final Channel? channel;
  final VoidCallback onRetry;

  @override
  State<PlayerPanel> createState() => _PlayerPanelState();
}

class _PlayerPanelState extends State<PlayerPanel> {
  bool _buffering = false;
  String? _error;
  final List<StreamSubscription> _subs = [];

  @override
  void initState() {
    super.initState();
    _subs.add(widget.player.stream.buffering.listen((b) {
      if (mounted) setState(() => _buffering = b);
    }));
    _subs.add(widget.player.stream.error.listen((e) {
      if (mounted) setState(() => _error = e);
    }));
    // Clear stale error once playback actually starts.
    _subs.add(widget.player.stream.playing.listen((p) {
      if (p && mounted && _error != null) setState(() => _error = null);
    }));
  }

  @override
  void didUpdateWidget(PlayerPanel old) {
    super.didUpdateWidget(old);
    // New channel selected → drop the previous error banner.
    if (old.channel?.url != widget.channel?.url && _error != null) {
      setState(() => _error = null);
    }
  }

  @override
  void dispose() {
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
        ],
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