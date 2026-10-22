# AlbumRank

Android app (Flutter) for rating albums 1–10 and ranking years, decades, genres and artists by their average rating.

## Features

- Master list of albums (title, artist, year, genre, 1–10 rating) with add / edit / delete and undo.
- Auto-fill from the iTunes Search API while typing; works offline with manual entry.
- Rankings by Year, Decade, Genre, Artist (whole-number averages, shared ranks for ties) plus an all-albums leaderboard.
- Optional **quality coefficient**: rewards groups with more good albums using `(sum + 5·2) / (n + 2)`.
- Stats tab: rating spread and most-rated artists, years and genres.
- Ratings color-coded red (1) → blue (10).
- JSON export/import, plus a weekly automatic backup to `Downloads/AlbumRank` on Android (keeps the newest 5).

## Develop

```
flutter test
flutter run
flutter build apk --release   # needs android/key.properties for release signing
```

App icon sources live in `assets/icon/`; regenerate platform icons with `dart run flutter_launcher_icons`.
