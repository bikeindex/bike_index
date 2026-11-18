# iOS review seed account & UI test determinism

Context for the App Store review seed (`ios_review@bikeindex.org`) and why the
seeded bikes for the iOS UI tests had to become deterministic.

## The accounts and what uses them

### `ios_review@bikeindex.org`

Seeded by `db/seeds/seed_ios_review_bikes.rb`, run from `db/seeds.rb` and
re-run on every deploy by `bin/docker-entrypoint` (idempotent, keyed on
`ios_review.bikes.exists?`).

One bike: a registered, claimed **2024 Giant Escape (3)** (black, aluminum),
labelled `2024 Giant`.

No Riese & Müller Load4 on this account — its photos are identical to the
`user@fakegmail.com` bike and the homepage recovery showcase, so screenshots
would show duplicate imagery.

Used by (in `~/dev/bike_index_ios`, branch `release_v1.7.1`):

- `MainContentUITestCase` — needs at least one bike on the grid.
- `ScreenshotUITest` — uses `user@fakegmail.com`, not this account.
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
only works if two different bikes can never render the same label. Before these
seeds, the accounts' bikes used
`SeedHelpers.weighted_frame_maker_id` (random manufacturer, no year), so the
labels were random manufacturer names — a collision (both drawing the same
maker) produces a **false-positive failure** even though no stale bikes exist.

The fix pins every label and keeps them mutually distinct:

| Account | Labels |
|---|---|
| `ios_review` | `2024 Giant` |
| `transfer_provider` | `2019 Specialized` |
| `member@brakebills.edu` | **still random** (see caveat) |

## Open items

1. **`member@brakebills.edu`'s bike label is still a random weighted
   manufacturer with no year** — created via
   `seed_unregistered_parking_notification` in
   `db/seeds/seed_organization_bikes_and_associations.rb` (the same helper
   that makes `user@`'s unregistered PN bike, also random). Its label can
   still coincidentally match `ios_review`'s fixed label
   (low odds, but the maker list is small). To make the StaleBike test fully
   deterministic, apply the same year/frame_model pinning to the `member`
   call in that seed file (and consider the same for `user@`, which shares
   the helper).
2. **Existing review databases won't pick up the new labels.** Both seed
   files guard on `owner.bikes.exists?`, so a database seeded before
   them keeps its old random-maker bikes. Fix with a one-off
   `Bike.destroy_all` for the affected users (`ios_review`,
   `transfer_provider`) and a redeploy, or a fresh database.
3. CI: `.github/workflows/ios-e2e.yml` currently only runs `UnitTests`; the
   UI test suite is not wired into CI yet. When it is, point it at a sandbox
   where these seeds have run — `rails db:seed` runs them, and
   `bin/docker-entrypoint` re-runs them on every sandbox deploy.
