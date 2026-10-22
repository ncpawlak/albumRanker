# How ranking works

All the math lives in `lib/logic/ranking.dart`. Ratings are stored as half stars (1, 1.5 … 10), and every calculation uses whole half-star units, so results never suffer from floating-point drift.

## Group averages

A group's average is shown as a **whole number**, rounded half up:

```
average = round_half_up(sum of ratings / number of albums)
```

Examples: 7 and 8 average 7.5, shown as **8**. 7, 7 and 8 average 7.33, shown as **7**.

## Ranking and ties

Groups are sorted by average, high to low. Ties use **competition ranking**: equal averages share a rank and the next rank is skipped (1, 2, 2, 4).

Within a tie the display order is:

1. more albums first;
2. then alphabetical by name.

**Min albums** drops groups with fewer albums before ranking, so the remaining groups re-rank from 1.

The **Albums** leaderboard ranks every album by its own rating with the same tie rule.

## Quality coefficient

A plain average lets a one-album artist rated 9 beat an artist with eight albums rated 8. The optional quality coefficient pads every group with two imaginary albums rated 5, which pulls small groups toward the middle:

```
quality = (sum of ratings + 5 × 2) / (number of albums + 2)
```

It's shown with one decimal.

| Group | Plain average | Quality |
|---|---|---|
| One album rated 8 | 8 | (8 + 10) / 3 = **6.0** |
| Four albums rated 7 | 7 | (28 + 10) / 6 = **6.3** |
| Three albums rated 8 | 8 | (24 + 10) / 5 = **6.8** |
| Twenty albums rated 6 | 6 | (120 + 10) / 22 = **5.9** |

The weight of 2 was chosen as the middle of the range (1.5–3) that ranked a set of test scenarios fairly: four 7s beat one 8, but twenty 6s still lose to three 8s.

Because quality scores cluster between 4 and 8, their colors stretch that band across the full red-to-blue scale so differences are visible.

## Rating colors

Each rating maps to a hue from red (1) through orange, yellow, green and teal to blue (10). Text on top of a color switches between dark and white for readability. See `lib/theme/rating_colors.dart`.

## Ratings-by-year chart

`lib/logic/year_chart.dart` builds one point per year from the earliest to the latest album year:

- years without albums are kept so the timeline is continuous; they have no dots, and the average line bridges them;
- each year's average and quality score use the same rules as group rankings;
- in fit-to-screen mode, the x-axis labels the first and last year plus decade starts that don't crowd them.

## Face-off pairing

`lib/logic/faceoff.dart` picks match-ups:

- **Pool:** albums matching the chosen artist, genre or year (ignoring capitals) and, if any are selected, the chosen ratings.
- **Allowed pairs:** *Tied* means equal ratings, *Within ½* means at most one half star apart, *Any* means any two.
- **Choosing the next pair:** pairs already played this session are skipped. Among the rest, the pairs whose two albums have appeared least often are preferred, and one is picked at random. The left and right sides are also random.
- Ratings can change between rounds, so each new pair is chosen from the current ratings.

### Rating suggestions after a pick

| Situation | Options offered |
|---|---|
| Winner already rated higher | None; the ratings agree. |
| Tied ratings | Raise the winner ½, or lower the loser ½. |
| Upset (winner rated lower) | Raise the winner ½, lower the loser ½, or both. |

Options that would go past 10 or below 1 are left out. **Keep ratings** is always available.
