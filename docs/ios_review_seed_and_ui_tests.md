# iOS review seed account & UI test determinism

Context for the App Store review seed (`ios_review@bikeindex.org`) and why the
seeded bikes for the iOS UI tests had to become deterministic. Written
2026-07-21 while on `cicd/add-ios_review-seed-account` (commits `786ed3d0b`,
`4f9a99ee9`).

## The accounts and what uses them

### `ios_review@bikeindex.org`

Seeded by `db/seeds/seed_ios_review_bikes.rb`, run from `db/seeds.rb` and
re-run on every deploy by `bin/docker-entrypoint` (idempotent, keyed on
`ios_review.bikes.exists?`).

Bikes (all labels deterministic after `4f9a99ee9`):

| Status | Bike | Serial |
|---|---|---|
| Found (impounded) | 2016 Specialized Sirrus | `IOSREVIEW01` |
| Unregistered PN | 2020 FX 2 | `unknown` |
| With owner | 2018 Jamis Allegro (black, flat bar) | `IOSREVIEWJA18` |
| Graduated | 2021 Allez (Brakebills) | `IOSREVIEW01` |

No Riese & Müller Load4 on this account — its photos are identical to the
`user@fakegmail.com` bike and the homepage recovery showcase, so screenshots
would show duplicate imagery. The Jamis Allegro is the "clean registration"
demo bike instead.

Used by (in `~/dev/bike_index_ios`, branch `release_v1.7.1`):

- `MainContentUITestCase` — taps the first bike in each of the four status
  grids, so `ios_review` must have at least one bike per status.
- `ScreenshotUITest.test_ios_review_claims_a_bike` — signs in, taps the found
  (impounded) bike, taps Claim.
- `StaleBikeUITest.test_staleBikesAreRemoved` — see below.
- `UniversalLinksUITest` — deep links only, no data assertions.

### `transfer_provider@bikeindex.org` / `transfer_recipient@bikeindex.org`

Seeded by `db/seeds/seed_test_users.rb` (users) and
`db/seeds/seed_transfer_bike.rb` (one bike, now **2019 Specialized Sirrus** —
was a random weighted manufacturer with no year/model). Used only by
`StaleBikeUITest.test_transferredBikesAreRemoved`: the provider transfers the
bike to the recipient, the test asserts it disappears from the provider's
by-status grid, and `tearDown` transfers it back so the next run starts clean.

### `user@bikeindex.org` (TEST_USERNAME) and `member@brakebills.edu`

Still used by the generic navigation tests
(`BikeIndexUITests.swift`, `ManufacturerKeyboardUITestCase.swift`) via
`startWithSignIn()` — they don't assert on specific bikes, so no seed change
needed. `member@brakebills.edu` is the second account in
`StaleBikeUITest.test_staleBikesAreRemoved`.

## The StaleBike disjoint-label assertion

`test_staleBikesAreRemoved` (UITests/StaleBikeUITest.swift):

1. Sign in as `ios_review`, group **by status**, record every rendered bike
   label. The label is the `"<year> <manufacturer>"` string rendered in the UI
   (`Bike.displayTitle` in `BikeIndex/Model/Bike.swift`).
2. Log out, sign in as `member@brakebills.edu`, record their labels.
3. Assert the two label sets are **disjoint** — if `member`'s screen shows any
   of `ios_review`'s labels, the app failed to clear the previous user's data
   on account switch (the bug the test exists to catch).

It compares labels, **not bike IDs**: the accessibility identifiers embed a
section position, so they aren't a stable bike identity across users. That
only works if two different bikes can never render the same label. Before the
determinism commit, both accounts' unregistered bikes used
`SeedHelpers.weighted_frame_maker_id` (random manufacturer, no year), so the
labels were random manufacturer names — a collision (both drawing the same
maker) produces a **false-positive failure** even though no stale bikes exist.

The fix pins every label and keeps them mutually distinct:

| Account | Labels |
|---|---|
| `ios_review` | `2016 Specialized`, `2020 FX 2`, `2021 Allez`, `2018 Jamis` |
| `transfer_provider` | `2019 Specialized` |
| `member@brakebills.edu` | **still random** (see caveat) |

## Open items

1. **`member@brakebills.edu`'s bike label is still a random weighted
   manufacturer with no year** — created via
   `seed_unregistered_parking_notification` in
   `db/seeds/seed_organization_bikes_and_associations.rb` (the same helper
   that makes `user@`'s unregistered PN bike, also random). Its label can
   still coincidentally match one of `ios_review`'s four fixed labels
   (low odds, but the maker list is small). To make the StaleBike test fully
   deterministic, apply the same year/frame_model pinning to the `member`
   call in that seed file (and consider the same for `user@`, which shares
   the helper).
2. **Existing review databases won't pick up the new labels.** Both seed
   files guard on `owner.bikes.exists?`, so a database seeded before
   `4f9a99ee9` keeps its old random-maker bikes. Fix with a one-off
   `Bike.destroy_all` for the affected users (`ios_review`,
   `transfer_provider`) and a redeploy, or a fresh database.
3. CI: `.github/workflows/ios-e2e.yml` currently only runs `UnitTests`; the
   UI test suite is not wired into CI yet. When it is, point it at a sandbox
   where these seeds have run (the seeds are deploy-triggered via
   `bin/docker-entrypoint`, not part of `rails db:seed`'s dev-only path —
   verify this assumption before relying on it for a CI database).
