import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../models/channel.dart';
import '../services/playlist_repository.dart';
import '../widgets/channel_tile.dart';
import '../widgets/player_panel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // media_kit player + render controller. Created once, reused for every zap.
  late final Player _player = Player();
  late final VideoController _controller = VideoController(_player);

  final PlaylistRepository _repo = const PlaylistRepository();

  List<Channel> _all = [];
  bool _loading = true;
  String? _loadError;

  Channel? _current;
  String _query = '';
  String _category = 'All';
  String _group = 'All';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final channels = await _repo.loadChannels();
      if (!mounted) return;
      setState(() {
        _all = channels;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = '$e';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  /// Top-level categories, ordered with Sports first (the main use case).
  List<String> get _categories {
    final set = <String>{for (final c in _all) c.category};
    const order = [
      'Sports', 'News', 'Movies', 'Entertainment', 'Music', 'Kids',
      'Test (always-on)',
    ];
    final extras = set.where((c) => !order.contains(c)).toList()..sort();
    final ordered = [...order.where(set.contains), ...extras];
    return ['All', ...ordered];
  }

  /// Broadcaster groups available within the currently selected category.
  List<String> get _groups {
    final set = <String>{
      for (final c in _all)
        if (_category == 'All' || c.category == _category) c.group,
    };
    final list = set.toList()..sort();
    return ['All', ...list];
  }

  List<Channel> get _filtered {
    final q = _query.trim().toLowerCase();
    return _all.where((c) {
      final matchCategory = _category == 'All' || c.category == _category;
      final matchGroup = _group == 'All' || c.group == _group;
      final matchQuery = q.isEmpty || c.name.toLowerCase().contains(q);
      return matchCategory && matchGroup && matchQuery;
    }).toList();
  }

  void _play(Channel channel) {
    setState(() => _current = channel);
    // Low-latency live tuning; mpv handles HLS + raw mpegts transparently.
    _player.open(Media(channel.url));
  }

  void _retry() {
    final c = _current;
    if (c != null) _player.open(Media(c.url));
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.sports_soccer),
            SizedBox(width: 8),
            Text('World Cup Live TV'),
          ],
        ),
        actions: [
          if (!_loading && _loadError == null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${_all.length} channels',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(wide),
    );
  }

  Widget _buildBody(bool wide) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(child: Text('Failed to load playlist:\n$_loadError', textAlign: TextAlign.center));
    }

    final player = PlayerPanel(
      player: _player,
      controller: _controller,
      channel: _current,
      onRetry: _retry,
    );

    if (wide) {
      return Row(
        children: [
          SizedBox(width: 340, child: _buildList()),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                Expanded(child: AspectRatioBox(child: player)),
              ],
            ),
          ),
        ],
      );
    }

    // Narrow: player on top, list below.
    return Column(
      children: [
        AspectRatio(aspectRatio: 16 / 9, child: player),
        Expanded(child: _buildList()),
      ],
    );
  }

  Widget _buildList() {
    final filtered = _filtered;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search channels…',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        // Primary filter: top-level category (Sports / News / Movies ...).
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (_, i) {
              final cat = _categories[i];
              return ChoiceChip(
                label: Text(cat),
                selected: _category == cat,
                onSelected: (_) => setState(() {
                  _category = cat;
                  _group = 'All'; // reset sub-group when category changes
                }),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        // Secondary filter: broadcaster group within the chosen category.
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _groups.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (_, i) {
              final g = _groups[i];
              return FilterChip(
                label: Text(g),
                selected: _group == g,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => setState(() => _group = g),
              );
            },
          ),
        ),
        const Divider(height: 16),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('No channels match'))
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final c = filtered[i];
                    return ChannelTile(
                      channel: c,
                      selected: c == _current,
                      onTap: () => _play(c),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Keeps the video pinned to 16:9 inside the available space, centered.
class AspectRatioBox extends StatelessWidget {
  const AspectRatioBox({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: AspectRatio(aspectRatio: 16 / 9, child: child),
    );
  }
}
