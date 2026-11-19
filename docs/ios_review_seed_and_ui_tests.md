# iOS seed accounts & UI test determinism

Which seeded accounts the iOS app's UI tests (`bikeindex/bike_index_ios`,
`UITests/`) sign in as, and why some of their bikes have fixed labels.

## Jamis is reserved

`SeedHelpers.weighted_frame_maker_id` never picks Jamis, and every random
manufacturer in the seeds comes from it. So a seed that passes in Jamis gets a
bike whose label no randomly generated bike can share. The bikes that need a
fixed label all use it, each with its own year:

| Account | Bike | Label |
|---|---|---|
| `ios_review@bikeindex.org` | 2024 Jamis Coda | `2024 Jamis` |
| `transfer_provider@bikeindex.org` | 2019 Jamis Allegro | `2019 Jamis` |
| `member@brakebills.edu` | 2021 Jamis, unregistered parking notice | `2021 Jamis` |

The app labels a bike `"<year> <manufacturer>"`, falling back to
`"<manufacturer> <serial>"` without a year (`Bike.displayTitle` in
`BikeIndex/Model/Bike.swift`).

## The accounts and what uses them

### `user@bikeindex.org` (`TEST_USERNAME`)

The default sign-in (`.github/workflows/ios-e2e.yml` sets `TEST_USERNAME`).
`MainContentUITestCase` uses it and needs at least one bike on the by-status
and by-manufacturer grids. It's also the first account in
`StaleBikeUITest.test_staleBikesAreRemoved`. Its bikes are random
manufacturers with no year, so never Jamis.

### `member@brakebills.edu`

The second account in `test_staleBikesAreRemoved`, which signs in as `user@`,
records its bike labels, signs out, signs in as `member`, and asserts the two
label sets are **disjoint**. A shared label means the app kept the previous
user's bikes after an account switch. It compares labels, not bike IDs, because
the accessibility identifiers embed a section position.

Both accounts used to get an unregistered parking-notice bike from the same
random helper, labelled `"<manufacturer> unknown"`, so drawing the same maker
failed the test with no stale bikes at all. `member`'s is now `2021 Jamis`.

### `transfer_provider@bikeindex.org` / `transfer_recipient@bikeindex.org`

Seeded by `db/seeds/seed_test_users.rb` (users) and
`db/seeds/seed_transfer_bike.rb` (the provider's one bike). Used only by
`StaleBikeUITest.test_transferredBikesAreRemoved`: the provider transfers its
first by-status bike to the recipient, the test asserts it's gone from the
provider's grid, and `tearDown` transfers it back.

### `user@fakegmail.com`

`ScreenshotUITest` signs in as it for the Riese & Müller Load4 it owns.

### `ios_review@bikeindex.org`

The App Store review account, seeded by `db/seeds/seed_ios_review_bikes.rb`
with one claimed bike. No UI test signs in as it. It deliberately has no
Riese & Müller, whose photos would duplicate `user@fakegmail.com`'s bike and
the homepage recovery showcase.

## When the seeds run

`rails db:seed` runs all of them. On sandbox, `bin/docker-entrypoint` re-runs
`seed_test_users`, `seed_transfer_bike`, `seed_ios_review_bikes` and
`seed_oauth_app` on every deploy; the bike seeds skip an account that already
has a bike, so a change to an existing account's bike reaches sandbox through
its nightly `reload_database` (`.github/workflows/review-app.yml`), which drops
and reseeds it. `.github/workflows/ios-e2e.yml` runs the iOS suite against
`sandbox.review.bikeindex.org`, with `UITests` currently disabled in its matrix.
