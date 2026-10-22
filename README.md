# AlbumRank

Android app (Flutter) for rating albums 1–10 and ranking years, decades, genres and artists by their average rating.

## Features

- Master list of albums (title, artist, year, genre, 1–10 rating) with add / edit / delete and undo.
- Half-star ratings set with a large score, −/+ buttons (half a star each) and a colored slider; group averages stay whole numbers.
- Album rows show cover art; albums without art get a tile in their rating color with the artist's initials.
- Share button on Rankings and group details makes a top 5/10/25 image card to send through any app.
- Artist and genre names are matched case-insensitively on save; Settings › Duplicate names merges existing spellings (e.g. Babymetal / BABYMETAL).
- Auto-fill from the iTunes Search API while typing; works offline with manual entry.
- Rankings by Year, Decade, Genre, Artist (whole-number averages, shared ranks for ties) plus an all-albums leaderboard. Ranks 1–3 get gold, silver and bronze crowns (ties share a crown).
- Group details sort by rating, A–Z or year (newest first); the last choice is remembered.
- **Face-off** tab: pick match-ups (tied, within ½ or any), rounds (5/10/20/∞), an artist/genre/year and ratings, then two albums fly in and collide. Tap the better one (or "too close to call"), then raise the winner or lower the loser by half a star, or keep the ratings. Each album's win–loss record is shown on its edit screen, and a recap lists every match-up.
- Decade, genre and artist details (with 2+ albums) show a ratings-by-year graph of just that group; tap a dot to open the album.
- Optional **quality coefficient**: rewards groups with more good albums using `(sum + 5·2) / (n + 2)`.
- Stats tab: ratings-by-year chart (a dot per album, an average line, and a dashed quality line when the coefficient is on; the line bridges empty years; scrolls sideways or fits to screen; tap a year to open it), rating spread, and most-rated artists, years and genres.
- Ratings color-coded red (1) → blue (10).
- JSON export/import, plus a weekly automatic backup to `Downloads/AlbumRank` on Android (keeps the newest 5).

## Develop

```
flutter test
flutter run
flutter build apk --release   # needs android/key.properties for release signing
```

App icon sources live in `assets/icon/`; regenerate platform icons with `dart run flutter_launcher_icons`.
