# User guide

AlbumRank has five tabs: **Albums**, **Rankings**, **Face-off**, **Stats** and **Settings**.

## Albums

Your master list. Search by title, artist or genre with the bar at the top.

### Adding an album

1. Tap **+**.
2. Start typing the title (or artist). After a moment, matches from iTunes appear. Tap one to fill in the title, artist, year, genre and cover art. No internet? Type everything in yourself.
3. Set the rating:
   - the big number shows the current rating;
   - **−** and **+** move half a star;
   - the colored slider sets it quickly.
4. Save.

If the album is already in your list (same title and artist, ignoring capitals and spacing), AlbumRank offers to open the existing one instead.

### Names stay consistent

Artist and genre names are matched without regard to capitals or extra spaces. If you type `breaking benjamin` and you already have `Breaking Benjamin`, the album uses the existing spelling so the artist isn't split in two. Changing only the capitals on an album's own artist (e.g. `Babymetal` → `BABYMETAL`) is treated as a correction and applied to every album by that artist.

### Editing and deleting

Tap an album to edit it. Its edit screen also shows its Face-off record (wins and losses). Swipe an album in the list, or tap **Delete** on its edit screen, to remove it; **Undo** in the message brings it back.

### Cover art

Albums picked from iTunes show their cover. Others get a tile in their rating color with the artist's initials.

## Rankings

Choose how to group: **Year**, **Decade**, **Genre**, **Artist**, or **Albums** for a leaderboard of every album.

- Each group shows its average rating as a whole number, colored on the rating scale.
- Groups with the same average share a rank (1, 2, 2, 4). Within a tie, groups with more albums are listed first.
- Ranks 1–3 get gold, silver and bronze crowns; ties share a crown.
- **Min albums** hides groups with fewer albums than you choose, so a single 10 doesn't top the list.
- **Quality coefficient** ranks by a one-decimal score that favors groups with many good albums over groups with one great one. See [How ranking works](ranking.md).
- The share button (top right) makes an image of the top 5, 10 or 25.

### Group details

Tap a group to see its albums.

- **Sort by** rating, A–Z or year (newest first). Year sorting isn't offered on year screens. Your last choice is remembered.
- Decade, genre and artist groups with 2 or more albums show a **ratings-by-year chart**. Tap a dot to open that album.
- A faint background sits behind the screen:
  - **Artist:** a photo of the band, found automatically on Deezer.
  - **Year, decade and genre:** a tilted collage of the group's best covers.
- **Wrong band photo?** Tap the image icon in the top bar (artist screens only) to search Deezer and pick the right photo, or choose **No image**.

## Face-off

Settle close calls head to head.

1. Choose the setup:
   - **Match-ups:** *Tied* (exact same rating), *Within ½* (no more than half a star apart) or *Any*.
   - **Rounds:** 5, 10, 20 or ∞.
   - Optionally limit to one **artist, genre or year**, and to specific **ratings**.
   - The screen shows how many match-ups that setup allows.
2. Tap **Start face-off**. Two albums fly in from opposite sides and collide in front of both bands' photos, split by a glowing 45° line.
3. Tap the better album, or **Too close to call**.
4. If your pick disagrees with the ratings (the winner isn't rated higher), you can:
   - raise the winner by half a star;
   - lower the loser by half a star;
   - after an upset, do both;
   - or keep the ratings as they are.
5. Continue to the next match-up or stop. The recap lists every match-up and any rating changes.

A pair never repeats within a session, and albums that have appeared least are picked first. Every pick adds to each album's win–loss record.

## Stats

- Totals: albums, average rating, artists and genres.
- **Ratings by year:** a dot per album (stacked when several share a rating), a line for each year's average, and a dashed quality line when the quality coefficient is on. Years without albums leave a gap in the dots; the line bridges them. The chart scrolls sideways, or tap **Fit to screen** to see it all at once. Tap a year to open it.
- **Rating spread:** how many albums sit at each rating.
- Most-rated artists, years and genres.

## Settings

### Appearance
- **Dark / Light** theme.
- **Background images:** turn band photos and cover collages on or off everywhere, including Face-off.
- **Artist backgrounds:** every artist and their current photo. Tap one to re-search Deezer for a better image.

### Library
- **Duplicate names:** artists or genres spelled more than one way (e.g. `Babymetal` and `BABYMETAL`). Pick the spelling to keep and merge.

### Backup
- **Export:** save your whole library as a JSON file.
- **Import:** replace your library with a backup file (you'll be asked to confirm).
- **Automatic backup:** once a week, when you open the app, a backup is saved to `Downloads/AlbumRank`. The newest 5 are kept.

See [Data and backups](data-and-backups.md) for the file format.
