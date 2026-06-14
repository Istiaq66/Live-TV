import 'package:flutter/material.dart';

import '../models/channel.dart';

class ChannelTile extends StatelessWidget {
  const ChannelTile({
    super.key,
    required this.channel,
    required this.selected,
    required this.onTap,
  });

  final Channel channel;
  final bool selected;
  final VoidCallback onTap;

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
      trailing: selected
          ? Icon(Icons.play_arrow, color: theme.colorScheme.primary)
          : null,
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