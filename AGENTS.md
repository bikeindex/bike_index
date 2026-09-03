Bike Index is a Rails webapp

[mise](https://mise.jdx.dev/) is used for Ruby and Node version management.

# Development

Run `eval "$(ruby bin/env --export)"` once so `$DEV_PORT` (and `$BASE_URL`, `$REDIS_URL`) are set with the right WORKSPACE_ID fallback.

**Renaming a `config/initializers/` file needs a `bin/dev` restart.** Initializers don't re-run on reload, so a running server still holds the old constant and none of the new one — and `config/routes.rb`, which does reload, then dies partway through its draw. Everything routed below that line 404s and the page reading the constant raises a bare `NameError` on a route helper, which reads as anything but a stale boot.

## Code style

Run `bin/lint` to automatically format the code. Always use `bin/lint`, don't use other formatters.

**Pass it the files or directories you changed** — `bin/lint app/components/ui/table app/models/bike.rb`. A bare `bin/lint` walks the whole repo, which is slow and reformats files you aren't working on. Save it for a final check before pushing.

**Never revert what the linter wrote.** If a too-broad `bin/lint` reformats files outside your change, leave those fixes in the diff — don't `git checkout` them away. Scope the next run more tightly instead.

### Code guidelines:

- Code in a functional way. Avoid mutation (side effects) when you can.
- Don't mutate arguments
- Don't monkeypatch
- make methods private if possible
- Omit named arguments' values from hashes (ie prefer `{x:, y:}` instead of `{x: x, y: y}`)
- Prefer less code, by character count (excluding whitespace and comments). Use `bin/char_count {FILE OR FOLDER}` to get the non-whitespace character count
- prefer un-abbreviated variable names
- Use full class/module names everywhere — `UI::Forms::Combobox::Component`, not the `Combobox::Component` that lexical scope also resolves from inside `UI::Forms`
- **A namespace under `Admin::` or `Pages::` shadows a top-level one of the same name** — `Pages::Search` hides the `Search::` controllers from every `.rb` nested in it. Nothing fails at boot; it raises only where something reads the shadowed constant, so check a new namespace against `Object.const_defined?("LandingPages", false)` after an eager load. Rename the collision away rather than prefixing call sites with `::` — job namespaces carry the `*_jobs` suffix, `LandingPageOrganizations` holds the landing-page slugs. Templates are exempt: a compiled template's `Module.nesting` is the component class alone, so a bare `Saml::` there still reaches the top level.
- Default to no comment — see **Comments** below for when one earns its place
- **Prefer composition over inheritance and `include`.** Share behavior by calling an object that owns it, not by mixing a module into several classes or adding a base class. A `module` extracted only to be `include`d in two classes is usually one of those classes with a parameter — pass the difference in as an argument instead. Rails' own extension points (`ApplicationRecord`, `ApplicationJob`, `ActiveSupport::Concern` for controller filters) are fine; new mixins of our own are what to avoid.
- **Service objects** (`app/services/`): a stateless service is a `module` with `extend Functionable` (see the `functionable` gem) — inputs passed as args, no instance state, private methods via `conceal` + a `# private below here` block. Don't write a stateless service as a `class` with `def self.` methods.
- **Class methods go in a `class << self` block** when the class has more than 5 of them, or when any of them should be private — `BugReport` is the pattern.
- **An endless method takes a trailing `if`/`unless` on the *definition*, not the body.** `def centering = "mx-auto" if @alignment == :center` evaluates the condition once, in the class body where the ivar is still nil, so the method is never defined and every call raises `NameError`. Give it a real body when the result is conditional.

### Comments

- **Default to no comment.** Code shows *how*; a comment earns its place only by carrying *why* — a non-obvious constraint, a deliberate deviation, a gotcha, a workaround.
- **Never narrate the code.** "Loop over users", "parse the body" — the line below already says it.
- **Never narrate the change.** "Fixed X", "updated to Y", "as requested". The diff and the commit hold that history; a comment repeating it outlives the change and goes stale.
- **Don't defend a choice against an edit nobody would make.** A failing test already defends it.
- **Warranted ≠ warranted as written — razor the wording too.** Keep the one non-obvious fact a reader needs *at that line*, and cut the rest: mechanism the code already shows, where the value gets used downstream, second-order consequences, and the justification's justification. Multi-line blocks rarely survive intact:

  ```ruby
  # Levenshtein can't use an index, so Postgres would scan every bike. The `%`
  # operator hits index_bikes_on_serial_normalized_no_space_trgm instead, and
  # takes its threshold from a session setting, which we set to 0.2 rather than
  # the 0.3 default because 0.3 dropped too many real matches when we measured it.
  ```

  becomes

  ```ruby
  # `%` reads its threshold from a session setting; 0.2 rather than the 0.3
  # default keeps ~98% of the LEVENSHTEIN < 3 matches
  ```

- **Re-earn the comment when you edit the code under it.** Rewrite it to fit the new shape rather than appending a clause per change.

None of this governs magic comments, `# rubocop:disable` (keep its justification), or `TODO:`/`HACK:`/`NOTE:` markers.

### Translations

A registration is as often an e-scooter, a stroller or a wheelchair, so **never hardcode "bike" in a value that means the cycle type** — interpolate `%{bike_type}` and pass `bike_type: bike.type`. `Pages::Registrations::Show::CurrentAlerts::ClaimImpound` is the pattern. Key names (`about_this_bike:`), the product name, and copy that really is bike-only are fine.

Run `bundle exec rails prepare_translations` after hand-editing a `component.en.yml`; `bin/lint` doesn't normalize YAML.

A spec that renders in another locale — `spec/components/shared_blocks/footer/component_spec.rb` does, in `:nl` — fails on a key the sync-generated `config/locales/translation.*.yml` don't carry yet, since `raise_on_missing_translations` is on in test. Add the key inline to all four; the next sync overwrites them.

**Moving a key to another scope means moving its translations too.** Renaming a component or a service relocates its keys in `en.yml`, but the four `translation.*.yml` still hold the old scope — so every non-English reader silently drops back to English until the next sync re-translates. Nothing catches it: `prepare_translations` reports clean (`en.yml` is complete, and the orphans sit under the `ignore_unused` scopes), and no spec renders those rows in another locale. Carry the existing values across by hand, in all four, in the same commit as the rename — editing lines, not round-tripping the YAML, which re-wraps every folded string in these generated files and buries the move in a whole-file diff. A sync landing on the base conflicts with the re-nesting: apply the base's move onto your files rather than the reverse — its move is a few lines against your hundred. Then look for a scope both sides created; it auto-merges into two sibling keys of the same name, YAML keeps the last, and nothing reads these files to complain (i18n-tasks' `config/locales/%{locale}.yml` glob never matches `translation.*.yml`).

## Subagents

When a command fans out to subagents — `/simplify`, `/code-review`, or an ad-hoc fan-out — pick the model by how much of the *search* the agent has to invent, not by how simple the task sounds:

- **`model: "haiku"`** when the command is already specified: "run this grep and summarise it", "read these four files and pull out X". There's nothing to devise.
- **`model: "sonnet"`** when the agent has to work out *how* to look ("every call site of X", "which specs touch Y"). A weaker model compensates by flailing — on a real enumeration here it reached the same answer as sonnet, but took 3x the tool calls, 1.6x the wall clock and more total tokens, so the per-token discount didn't survive.
- **Omit `model:`** (inherit the session model) for judgement — the passes that catch an unvalidated param landing in a fragment cache key, or a shared partial's N+1.

Worth delegating enumeration at all rather than eyeballing a grep: in that same test both subagents found two call sites the hand-written grep missed, because it anchored on the wrong method name.

## Testing

Uses RSpec. All business logic should be tested. The `rspec-testing` skill covers project-specific style (`context`+`let`, request specs over controller specs, avoiding mocks). A test that fails intermittently is the `fixing-flaky-failures` skill — coverage is never what gives way to make CI green.

**Verify with `bundle exec rspec` over the spec files covering what you changed — usually one to three.** Not `bin/turbo_tests` or `bin/ci`. CI runs the whole suite on push; yours is a smoke test, and every extra minute of it delays the next fix. A whole directory — `spec/integration`, `spec/components` — is a suite run by another name, whichever runner you use. "It renders on every page, so anything could break" is the rationalization to watch for: run the specs that assert the behaviour you changed and let CI find the rest. A red example is not a reason to re-run its directory — re-run that example. Say which specs you ran and why those. A `:js` spec failing on a missing Tailwind build is the `sandbox-test-setup` skill, not a reason to switch runners.

**Never hand-edit a VCR cassette**, and never `git checkout` away one a spec run re-recorded — cassettes only change by being recorded, and a re-recording gets committed on whatever branch you're on. To clear stale contents, `rm` the file and re-run the spec.

## Frontend Development

Uses Stimulus.js for JavaScript and Tailwind CSS for styling. SCSS and CoffeeScript files exist but are deprecated. The `bin/dev` command handles Tailwind and JS builds. The `frontend-conventions` skill has the conventions.

Check whether the dev server is up: `curl -fs "$BASE_URL/" >/dev/null`. If it isn't, **stop and ask the user to start it** so Tailwind and JS asset watchers are running before any frontend work.

## Pull requests

- When creating a PR, run the `/pr` workflow rather than calling `gh pr create` directly — `/pr` detects frontend diffs and captures desktop+mobile screenshots, which it posts as a `## Screenshots` comment (never in the body, so the summary stays first).
- To attach a local image (screenshot, .png/.jpg, CleanShot capture) to an existing GitHub PR, the `gh` CLI **cannot upload images** — use the `github-pr-images` skill, which drives a real browser to GitHub's user-attachments uploader.

## Architecture notes

- **`app/components` has five top-level folders, and a new component goes in exactly one of them**: `ui` (the design system — a component whose arguments are only about style), `atoms` (small renderers reused across pages — `Atoms::Serial`, `Atoms::Admin::Badges::User`), `pages` (one namespace per route, `Pages::Admin::Bikes::Table`), `shared_blocks` (the chrome around a page — navbar, footer, alerts), and `emails`. Nothing else belongs at the top level.
- **Moving a file silently un-suppresses whatever was keyed to its old path.** `.herb.yml` excludes lint rules by path, `brakeman.ignore` hashes the file path into each fingerprint, and `config/i18n-tasks.yml` routes deep component scopes by path — so a rename re-enables the rule, obsoletes the entry, and leaves a write rule pointing at nothing, and none of the three says so until CI fails or a key lands in the wrong sidecar. Grep the repo root and `config/` for the old path, not just `app/`; re-fingerprint brakeman from `brakeman -f json` rather than hand-editing the path.
- **Changing a `PublicImage::VARIANTS` transformation re-keys every variant** — the key digests the transformations. Existing objects orphan and regenerate lazily, and the heic R2 cassette re-records: `rm` it and re-run rather than committing the appended interactions.
- **Multi-database**: primary (`ApplicationRecord`) + analytics (`AnalyticsRecord`). Use `db:migrate:down:analytics` for analytics migrations
- **Soft delete**: some models use `acts_as_paranoid` with `deleted_at` column; use `unscoped` in admin controllers when needed
- **A bike is written on every user-facing edit path, so `cache_key_with_version` already moves.** `BikeServices::Updator` merges `updated_by_user_at: Time.current` into its `@bike.update`, and the records edited through the bike's nested attributes (marketplace listing, stolen record, address) all save that way — so "editing X doesn't touch the bike" is nearly always wrong, and a fragment cache keyed on the bike needs no extra term for X. Probing it with a bare `bike.update(...)` in `rails runner` bypasses the updator and shows no change, which is what makes the wrong answer look measured; go through the controller.
- **Every user has a `password_digest`** — `User#set_calculated_attributes` gives passwordless accounts a random one so `has_secure_password` is satisfied. So it answers nothing about whether someone chose a password; `passwordless_user?` is that question.
- **`Pages::Admin::Users::Cell` costs ~9 queries per row.** It always renders `Atoms::Admin::Badges::User`, which computes its tags in `initialize` — a donations `SUM`, `recovered_records` (which loads every bike id the user owns first), theft alerts, roles — and none of it survives a preload, because each check builds a fresh relation. Fine on a show page, ~214 queries for a 25-row index. Where the old cell was just a name, keep the plain link.

# Initial setup

```bash
bundle install # install ruby dependencies
bundle exec rails db:create db:migrate # create the databases
```
