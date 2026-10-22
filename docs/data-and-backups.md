# Data and backups

## Where data lives

Everything is stored on the phone in the app's SharedPreferences. Nothing is sent anywhere except search terms to iTunes and Deezer.

| Key | Contents |
|---|---|
| `albumrank.library` | The album list (same JSON format as a backup file) |
| `albumrank.theme` | `dark` or `light` |
| `albumrank.qualityCoefficient` | Rank by quality score instead of plain average |
| `albumrank.groupSort` | Last sort on group details: `rating`, `title` or `year` |
| `albumrank.chartCondensed` | Ratings-by-year chart fits to screen instead of scrolling |
| `albumrank.backgrounds` | Background images on or off (default on) |
| `albumrank.artistImages.v2` | Cached band photos: artist name (lower-case) → URL, `""` = none |
| `albumrank.lastAutoBackup`, `albumrank.lastAutoBackupPath` | When and where the last automatic backup was written |

Uninstalling the app deletes all of this. Export a backup first.

## Backup file format

Exports, automatic backups and the stored library all use the same JSON:

```json
{
  "app": "AlbumRank",
  "schemaVersion": 1,
  "exportedAt": "2026-10-22T09:47:33.000",
  "albums": [
    {
      "id": "m1x2y3-abc123",
      "title": "Take A Look In The Mirror",
      "artist": "Korn",
      "year": 2003,
      "genre": "Rock",
      "rating": 7.5,
      "artworkUrl": "https://is1-ssl.mzstatic.com/…/600x600bb.jpg",
      "externalId": "itunes:1440765560",
      "wins": 2,
      "losses": 1,
      "createdAt": "2026-10-20T18:02:11.000",
      "updatedAt": "2026-10-22T09:40:05.000"
    }
  ]
}
```

| Field | Required | Notes |
|---|---|---|
| `id` | yes | Unique; generated from the time plus a random number |
| `title`, `artist`, `genre` | yes | Trimmed on load |
| `year` | yes | Whole number |
| `rating` | yes | 1–10 in steps of 0.5. Whole ratings are written as integers (`7`, not `7.0`) so older app versions can read them |
| `artworkUrl` | no | Cover image URL |
| `externalId` | no | Source ID, e.g. `itunes:<collectionId>` |
| `wins`, `losses` | no | Face-off record; left out when 0 |
| `createdAt`, `updatedAt` | yes | ISO 8601 |

### Import rules

- Import **replaces** the whole library (you're asked to confirm).
- Files tagged with a different `app` (e.g. from a future sibling app) are rejected.
- Files from a newer `schemaVersion` are rejected with a message, rather than loaded wrong.
- Any invalid album (missing field, rating out of range) rejects the whole file, so you never end up with half an import.
- Duplicates (same title and artist, ignoring capitals and spacing) are collapsed to the first one.

## Automatic backups

`AutoBackupService` runs when the app opens:

- only on Android, only if the library isn't empty, and only if 7 days have passed since the last one;
- writes `Downloads/AlbumRank/AlbumRank-auto-YYYY-MM-DD_HHMMSS.json` through `MainActivity.kt` using MediaStore, so no storage permission is needed (on Android 9 and older it goes to the app's own `Downloads/AlbumRank` folder instead);
- keeps the newest 5 auto-backups and deletes older ones; manual exports are never touched;
- failures are logged and never block the app from starting.

## Changing the schema

When adding a field to `Album`:

1. Give it a default so older data still loads (as `wins` and `losses` do).
2. If old data needs transforming, bump `AlbumRepository.schemaVersion` and add a step to `_migrate`:

   ```dart
   if (fromVersion < 2) albums = [for (final a in albums) {...a, 'newField': defaultValue}];
   ```

3. Add a test that loads a version-1 file.

Changing how artist photos are matched? Bump the cache key in `ArtistImageService` (e.g. `.v3`) so earlier automatic matches are looked up again.
