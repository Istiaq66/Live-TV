import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../config.dart';
import '../l10n/app_localizations.dart';
import '../main.dart' show setAppLocale, localeNotifier;
import '../models/channel.dart';
import '../models/fixture.dart';
import '../services/fixtures_service.dart';
import '../services/playlist_repository.dart';
import '../services/preferences_service.dart';
import '../services/stream_health.dart';
import '../widgets/channel_tile.dart';
import '../widgets/player_panel.dart';
import 'privacy_policy_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // media_kit player + render controller. Created once, reused for every zap.
  // Moderate demuxer buffer: enough to absorb jitter on overseas links without
  // the long initial fill / long rebuffer a huge buffer forces on live streams.
  late final Player _player = Player(
    configuration: const PlayerConfiguration(bufferSize: 16 * 1024 * 1024),
  );
  late final VideoController _controller = VideoController(_player);

  final PlaylistRepository _repo = const PlaylistRepository();
  final StreamHealthChecker _checker = StreamHealthChecker();
  final FixturesService _fixtures = FixturesService();
  PreferencesService? _prefs;

  List<Channel> _all = [];
  bool _loading = true;
  String? _loadError;

  // App version string for the About dialog, e.g. "1.1.0 (1)".
  String _version = '';

  // Persisted: favorite stream URLs.
  Set<String> _favorites = {};

  static const String _favCategory = '★ Favorites';

  // Health-check state, keyed by stream URL so it survives filter changes.
  final Map<String, StreamStatus> _status = {};
  bool _checking = false;

  Channel? _current;
  String _query = '';
  String _category = 'All';
  String _group = 'All';
  // Never auto-hide by the probe — it has false negatives (rejects working
  // streams). Users opt in via the toolbar toggle; status fills in from real
  // playback + manual health-check.
  bool _onlineOnly = false;

  // Auto-skip bookkeeping: sources already attempted in the current tune, and a
  // cap so a run of dead links can't cascade endlessly.
  final Set<String> _tried = {};
  int _autoSkips = 0;
  static const int _maxAutoSkips = 6;

  // Bumped on each manual retry so PlayerPanel re-arms its failure reporting
  // for the same channel (see PlayerPanel.retrySignal).
  int _retrySignal = 0;

  @override
  void initState() {
    super.initState();
    _tunePlayer();
    _load();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _version = '${info.version} (${info.buildNumber})');
    } catch (_) {
      // Non-fatal: About just omits the version if it can't be read.
    }
  }

  /// Tune libmpv for live streams. Keep readahead/cache short so the first
  /// frame appears fast and a stall refills quickly (a deep cache makes both
  /// the initial load and every rebuffer long). Still enough slack to ride out
  /// normal jitter; don't wait forever on a dead host.
  Future<void> _tunePlayer() async {
    // mpv properties are native-only; the web backend has no such API (and the
    // stub NativePlayer doesn't define setProperty, so don't reference it at
    // compile time on web). Call via dynamic and skip on web.
    if (kIsWeb) return;
    final dynamic p = _player.platform;
    if (p == null) return;
    try {
      await p.setProperty('cache', 'yes');
      await p.setProperty('demuxer-readahead-secs', '10');
      await p.setProperty('cache-secs', '10');
      // Resume as soon as a small amount is buffered instead of refilling fully.
      await p.setProperty('cache-pause-wait', '1');
      await p.setProperty('network-timeout', '10');
    } catch (_) {
      // Backend without setProperty — leave defaults.
    }
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _repo.loadChannels(),
        PreferencesService.create(),
      ]);
      if (!mounted) return;
      final channels = results[0] as List<Channel>;
      final prefs = results[1] as PreferencesService;

      setState(() {
        _all = channels;
        _prefs = prefs;
        _favorites = prefs.favorites();
        _loading = false;
      });

      // Resume the last-watched channel (auto-skip recovers if it's now dead).
      final lastUrl = prefs.lastWatched();
      if (lastUrl != null) {
        final match = channels.where((c) => c.url == lastUrl);
        if (match.isNotEmpty) _play(match.first);
      }

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = '$e';
        _loading = false;
      });
    }
  }

  void _toggleFavorite(Channel c) {
    setState(() {
      if (!_favorites.add(c.url)) _favorites.remove(c.url);
    });
    _prefs?.saveFavorites(_favorites);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  /// Top-level categories in a general-TV order (Entertainment leads).
  List<String> get _categories {
    final set = <String>{for (final c in _all) c.category};
    const order = [
      'Entertainment', 'News', 'Movies', 'Music', 'Kids', 'Sports',
      'Religious', 'Test (always-on)',
    ];
    final extras = set.where((c) => !order.contains(c)).toList()..sort();
    final ordered = [...order.where(set.contains), ...extras];
    return ['All', if (_favorites.isNotEmpty) _favCategory, ...ordered];
  }

  bool _inCategory(Channel c) => _category == _favCategory
      ? _favorites.contains(c.url)
      : _category == 'All' || c.category == _category;

  /// Broadcaster groups available within the currently selected category.
  List<String> get _groups {
    final set = <String>{
      for (final c in _all)
        if (_inCategory(c)) c.group,
    };
    final list = set.toList()..sort();
    return ['All', ...list];
  }

  List<Channel> get _filtered {
    final q = _query.trim().toLowerCase();
    return _all.where((c) {
      final matchGroup = _group == 'All' || c.group == _group;
      final matchQuery = q.isEmpty || c.name.toLowerCase().contains(q);
      final matchOnline =
          !_onlineOnly || _status[c.url] == StreamStatus.online;
      return _inCategory(c) && matchGroup && matchQuery && matchOnline;
    }).toList();
  }

  /// Probes every channel currently passing the category/group/search filters.
  Future<void> _checkVisible() async {
    if (_checking) return;
    // Snapshot the URLs to check against the *non*-online filter, so enabling
    // "online only" mid-check doesn't shrink the set out from under us.
    final q = _query.trim().toLowerCase();
    final visible = _all.where((c) {
      final mg = _group == 'All' || c.group == _group;
      final mq = q.isEmpty || c.name.toLowerCase().contains(q);
      return _inCategory(c) && mg && mq;
    }).toList();
    final urls = visible.map((c) => c.url).toList();
    if (urls.isEmpty) return;

    // Probe each stream with its own headers so header-gated origins aren't
    // wrongly marked offline.
    final headers = <String, Map<String, String>>{
      for (final c in visible)
        if (c.headers.isNotEmpty) c.url: c.headers,
    };

    setState(() {
      _checking = true;
      for (final u in urls) {
        _status[u] = StreamStatus.checking;
      }
    });

    await _checker.checkAll(
      urls,
      headers: headers,
      onResult: (url, alive) {
        if (!mounted) return;
        setState(() {
          _status[url] = alive ? StreamStatus.online : StreamStatus.offline;
        });
      },
    );

    if (mounted) setState(() => _checking = false);
  }

  void _play(Channel channel, {bool userInitiated = true}) {
    if (userInitiated) {
      // Fresh user pick → reset the auto-skip session.
      _tried.clear();
      _autoSkips = 0;
    }
    _tried.add(channel.url);
    setState(() => _current = channel);
    // Low-latency live tuning; mpv handles HLS + raw mpegts transparently.
    // Pass per-stream HTTP headers (UA/Referer/Origin) so origins that 403
    // without them still play. play:true autostarts; the extra play() consumes
    // the tap's user-activation so browsers don't leave it paused on web.
    _player.open(_mediaFor(channel), play: true).then((_) {
      if (mounted) _player.play();
    });
    _prefs?.saveLastWatched(channel.url);
  }

  void _retry() {
    final c = _current;
    if (c == null) return;
    // Treat a manual retry as a fresh attempt: re-arm the auto-skip session and
    // bump the retry signal so PlayerPanel re-enables failure reporting (it
    // only resets on a channel-url change otherwise, and retry reopens the same
    // url). Without this, a retried source that fails again can't auto-skip.
    _tried
      ..clear()
      ..add(c.url);
    _autoSkips = 0;
    setState(() => _retrySignal++);
    // Mirror _play: autostart and consume the tap's user-activation so the
    // stream runs immediately instead of loading paused (needing a 2nd tap).
    _player.open(_mediaFor(c), play: true).then((_) {
      if (mounted) _player.play();
    });
  }

  Media _mediaFor(Channel c) => Media(
        proxiedUrl(c.url, c.headers),
        httpHeaders: c.headers.isEmpty ? null : c.headers,
      );

  /// Current channel actually started playing → mark it online for real. This
  /// is the authoritative signal; the health-check probe is only a guess.
  void _onStreamPlaying() {
    final c = _current;
    if (c == null) return;
    if (_status[c.url] != StreamStatus.online) {
      setState(() => _status[c.url] = StreamStatus.online);
    }
  }

  /// Called when the player reports a playback error: mark the source offline
  /// and hop to the next viable source for the same channel / group.
  void _onStreamError() {
    final failed = _current;
    if (failed == null) return;
    if (_status[failed.url] != StreamStatus.offline) {
      setState(() => _status[failed.url] = StreamStatus.offline);
    }

    final l = AppLocalizations.of(context);
    if (_autoSkips >= _maxAutoSkips) {
      _toast(l.noWorkingSource);
      return;
    }

    final next = _nextSource(failed);
    if (next == null) {
      _toast(l.sourceDownNoOther(failed.name));
      return;
    }
    _autoSkips++;
    _toast(l.sourceDownTryingAnother(failed.name));
    _play(next, userInitiated: false);
  }

  /// Best alternative for a failed channel: same base name first, then same
  /// broadcaster group; known-online preferred, never a tried/offline one.
  Channel? _nextSource(Channel failed) {
    bool viable(Channel c) =>
        !_tried.contains(c.url) && _status[c.url] != StreamStatus.offline;

    final key = _baseKey(failed);
    final pool = <Channel>[];
    final seen = <String>{};
    void add(Iterable<Channel> cs) {
      for (final c in cs) {
        if (viable(c) && seen.add(c.url)) pool.add(c);
      }
    }

    add(_all.where((c) => _baseKey(c) == key)); // same channel, other servers
    add(_all.where((c) => c.group == failed.group)); // same broadcaster group
    if (pool.isEmpty) return null;

    // online (0) before unknown (1).
    int rank(Channel c) => _status[c.url] == StreamStatus.online ? 0 : 1;
    pool.sort((a, b) => rank(a).compareTo(rank(b)));
    return pool.first;
  }

  /// Normalises a channel name so duplicates across providers collapse:
  /// "ESPN 2", "ESPN 2 HD", "ESPN 2 720p" → "espn 2".
  static String _baseKey(Channel c) {
    const noise = {
      'hd', 'fhd', 'uhd', 'sd', '4k', '720p', '1080p', '480p', '576p',
      'alt', 'playlist', 'internacional', 'live', 'tv',
    };
    final cleaned = c.name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9+ ]'), ' ');
    final tokens = cleaned
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty && !noise.contains(t));
    return tokens.join(' ').trim();
  }

  /// Navigation drawer: matches + language + legal/about entries.
  Widget _buildDrawer() {
    final l = AppLocalizations.of(context);
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF1B5E20)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.live_tv, color: Colors.white, size: 40),
                  const SizedBox(height: 8),
                  Text(
                    l.appName,
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  Text(l.appTagline, style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.sports_soccer),
              title: Text(l.drawerTodayFootball),
              subtitle: Text(l.drawerMatchesToday),
              onTap: () {
                Navigator.of(context).pop(); // close drawer
                _showFixtures();
              },
            ),
            ListTile(
              leading: const Icon(Icons.language),
              title: Text(l.language),
              onTap: () {
                Navigator.of(context).pop();
                _showLanguagePicker();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: Text(l.privacyPolicy),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(l.about),
              subtitle: Text(_version.isEmpty ? '' : l.versionLabel(_version)),
              onTap: () {
                Navigator.of(context).pop();
                _showAbout();
              },
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '${l.madeBy}${_version.isEmpty ? '' : ' • v$_version'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Language switcher: System (follow device) / English / বাংলা.
  void _showLanguagePicker() {
    final current = localeNotifier.value?.languageCode;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) {
        Widget tile(String label, String? code) => RadioListTile<String?>(
              value: code,
              groupValue: current,
              title: Text(label),
              onChanged: (_) {
                setAppLocale(code == null ? null : Locale(code));
                Navigator.of(sheetCtx).pop();
              },
            );
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              tile('System', null),
              tile('English', 'en'),
              tile('বাংলা', 'bn'),
            ],
          ),
        );
      },
    );
  }

  void _showAbout() {
    final l = AppLocalizations.of(context);
    showAboutDialog(
      context: context,
      applicationName: l.appName,
      applicationVersion: _version.isEmpty ? null : l.versionLabel(_version),
      applicationIcon: const Icon(Icons.live_tv, size: 40, color: Color(0xFF1B5E20)),
      applicationLegalese: '© 2026 Istiaq Ahmed',
      children: [
        const SizedBox(height: 12),
        Text(l.aboutBody1),
        const SizedBox(height: 12),
        Text(l.aboutBody2),
      ],
    );
  }

  /// Bottom sheet listing today's football matches (TheSportsDB). Tapping a
  /// match jumps to the Sports category so the user can pick the broadcaster.
  void _showFixtures() {
    final l = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetCtx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          builder: (_, scrollController) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Row(
                    children: [
                      const Icon(Icons.sports_soccer),
                      const SizedBox(width: 8),
                      Text(
                        l.fixturesTitle,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: FutureBuilder<List<Fixture>>(
                    future: _fixtures.todayFootball(),
                    builder: (_, snap) {
                      if (snap.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snap.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              l.fixturesLoadError('${snap.error}'),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }
                      final list = snap.data ?? const [];
                      if (list.isEmpty) {
                        return Center(child: Text(l.fixturesEmpty));
                      }
                      return ListView.separated(
                        controller: scrollController,
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final f = list[i];
                          return ListTile(
                            leading: CircleAvatar(child: Text(f.whenLabel.split(':').first)),
                            title: Text(f.title),
                            subtitle: Text('${f.league} • ${f.whenLabel}'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.of(sheetCtx).pop();
                              _openMatch(f);
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Tap-through from a fixture: surface the Sports channels so the user can
  /// choose the broadcaster airing it.
  void _openMatch(Fixture f) {
    setState(() {
      _category = 'Sports';
      _group = 'All';
    });
    _toast(AppLocalizations.of(context).showingSportsFor(f.title));
  }

  void _toast(String msg) {
    if (!mounted) return;
    final m = ScaffoldMessenger.of(context);
    m.clearSnackBars();
    m.showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      drawer: _buildDrawer(),
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.live_tv),
            const SizedBox(width: 8),
            Text(AppLocalizations.of(context).appName),
          ],
        ),
        actions: [
          if (!_loading && _loadError == null) ...[
            IconButton(
              tooltip: AppLocalizations.of(context).showOnlineOnly,
              isSelected: _onlineOnly,
              icon: const Icon(Icons.wifi_tethering_off),
              selectedIcon: const Icon(Icons.wifi_tethering),
              onPressed: () => setState(() => _onlineOnly = !_onlineOnly),
            ),
            IconButton(
              tooltip: AppLocalizations.of(context).healthCheck,
              icon: _checking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.network_check),
              onPressed: _checking ? null : _checkVisible,
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12, left: 4),
              child: Center(
                child: Text(
                  '${_filtered.length}/${_all.length}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ],
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
      return Center(
        child: Text(
          AppLocalizations.of(context).loadFailed(_loadError!),
          textAlign: TextAlign.center,
        ),
      );
    }

    final player = PlayerPanel(
      player: _player,
      controller: _controller,
      channel: _current,
      onRetry: _retry,
      retrySignal: _retrySignal,
      onError: _onStreamError,
      onPlaying: _onStreamPlaying,
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
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: AppLocalizations.of(context).searchHint,
              isDense: true,
              border: const OutlineInputBorder(),
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
              ? Center(child: Text(AppLocalizations.of(context).noChannelsMatch))
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final c = filtered[i];
                    return ChannelTile(
                      channel: c,
                      selected: c == _current,
                      status: _status[c.url] ?? StreamStatus.unknown,
                      isFavorite: _favorites.contains(c.url),
                      onTap: () => _play(c),
                      onToggleFavorite: () => _toggleFavorite(c),
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
