# AlbumRank

Rate the albums you've heard and see which years, decades, genres and artists you rate highest.

AlbumRank is an Android app built with Flutter. You keep a master list of albums, each rated 1–10 in half stars. The app groups them and ranks each group by its average rating. It also has head-to-head **Face-offs** for settling close calls, charts of your ratings over time, and shareable top-N image cards.

## Highlights

| | |
|---|---|
| **Master list** | Add, edit and delete albums (title, artist, year, genre, rating) with undo. Type a title and AlbumRank fills in the artist, year, genre and cover from iTunes. |
| **Half-star ratings** | 1–10 in half steps, color-coded from red (1) to blue (10). |
| **Rankings** | Year, Decade, Genre and Artist rankings by whole-number average, with ties sharing a rank. Gold, silver and bronze crowns for the top 3. Optional **quality coefficient** rewards groups with many good albums. |
| **Group details** | Every album in a group, sortable by rating, A–Z or year, with a ratings-by-year chart. A faint band photo or cover collage sits behind the screen. |
| **Face-off** | Two albums fly in and collide over a diagonal split of both bands' photos. Pick the better one, then optionally nudge the ratings by half a star. |
| **Stats** | Ratings-by-year chart (scrolling or fit-to-screen), rating spread, and most-rated artists, years and genres. |
| **Sharing** | Top 5, 10 or 25 of any ranking as an image to send through any app. |
| **Backups** | JSON export and import, plus an automatic weekly backup to `Downloads/AlbumRank`. |

## Documentation

- [User guide](docs/user-guide.md): every screen and how to use it.
- [How ranking works](docs/ranking.md): averages, ties, the quality coefficient and Face-off pairing.
- [Architecture](docs/architecture.md): code layout, state management and external services.
- [Data and backups](docs/data-and-backups.md): storage, the backup file format and schema migrations.
- [Development](docs/development.md): setup, testing, building, signing and installing on a phone.

## Quick start

```powershell
flutter pub get
flutter test
flutter run                     # on a connected phone or emulator
flutter build apk --release     # signed if android/key.properties exists
```

See [Development](docs/development.md) for details.

## Requirements

- Android 7.0 (API 24) or newer.
- Internet access only for auto-fill, cover art and band photos. Everything else works offline, and your albums never leave the phone unless you export them.

## Credits

Album info and cover art from the [iTunes Search API](https://performance-partners.apple.com/search-api). Artist photos from the [Deezer API](https://developers.deezer.com/api).

## Roadmap

Publishing on Google Play is tracked in [#10](https://github.com/ncpawlak/albumRanker/issues/10).
