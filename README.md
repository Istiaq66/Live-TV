# Kickora

Flutter live-TV / IPTV player for World Cup football and other channels.

## Stack

- **media_kit** (libmpv) — plays HLS `.m3u8` **and** raw mpegts/TS streams.
  Cross-platform: Windows, Android, iOS, Linux, macOS.
- Channels load from a bundled M3U playlist (`assets/playlist.m3u`).

## Architecture

```
lib/
  models/channel.dart            # Channel data model
  services/m3u_parser.dart       # M3U → Channel[], infers category + group + flag
  services/playlist_repository.dart  # loads the bundled asset
  widgets/player_panel.dart      # video surface + buffering/error/now-playing overlay
  widgets/channel_tile.dart      # list row
  screens/home_screen.dart       # player + filtered channel list
  main.dart                      # MediaKit.ensureInitialized() + app shell
```

## Features

- Player reused across channel switches (single `Player` + `VideoController`).
- Filter by **category** (Sports / News / Movies / Music / Kids / Entertainment),
  then by **broadcaster group**, plus free-text search.
- Buffering spinner, stream-error state with Retry, now-playing badge.
- Responsive: side-by-side on wide screens, drawer list on phones.

## Run

```bash
flutter pub get
flutter run -d windows      # or -d <android-device-id>, chrome, etc.
```

## Notes

- Android: `usesCleartextTraffic=true` is enabled — many sources are plain `http://`.
- The playlist is community IPTV; individual streams go offline, change, or are
  geo-blocked frequently. The error overlay + Retry handle dead links gracefully.
- To use your own list, replace `assets/playlist.m3u` (or point
  `PlaylistRepository` at a network URL).
- Streaming third-party copyrighted feeds may be illegal in your jurisdiction —
  use legally-licensed sources for production.