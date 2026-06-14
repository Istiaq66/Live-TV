import 'package:flutter/material.dart';

import '../models/channel.dart';
import '../services/stream_health.dart';

class ChannelTile extends StatelessWidget {
  const ChannelTile({
    super.key,
    required this.channel,
    required this.selected,
    required this.status,
    required this.isFavorite,
    required this.onTap,
    required this.onToggleFavorite,
  });

  final Channel channel;
  final bool selected;
  final StreamStatus status;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      selected: selected,
      selectedTileColor: theme.colorScheme.primary.withValues(alpha: 0.15),
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Text(
          channel.flag ?? _initials(channel.name),
          style: const TextStyle(fontSize: 13),
        ),
      ),
      title: Text(
        channel.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        channel.group,
        style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatusDot(status: status),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: isFavorite ? 'Remove favorite' : 'Add favorite',
            icon: Icon(
              isFavorite ? Icons.star : Icons.star_border,
              color: isFavorite ? Colors.amber : theme.hintColor,
              size: 20,
            ),
            onPressed: onToggleFavorite,
          ),
          if (selected)
            Icon(Icons.play_arrow, color: theme.colorScheme.primary),
        ],
      ),
      onTap: onTap,
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length.clamp(0, 2)).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}

/// Small coloured indicator reflecting a stream's health-check result.
class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});
  final StreamStatus status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case StreamStatus.checking:
        return const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case StreamStatus.online:
        return const _Dot(Colors.greenAccent, 'Online');
      case StreamStatus.offline:
        return const _Dot(Colors.redAccent, 'Offline');
      case StreamStatus.unknown:
        return const _Dot(Colors.white24, 'Not checked');
    }
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color, this.tooltip);
  final Color color;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}