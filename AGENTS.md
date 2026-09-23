Bike Index is a Rails webapp

[mise](https://mise.jdx.dev/) is used for Ruby and Node version management.

# Development

Run `eval "$(ruby bin/env --export)"` once so `$DEV_PORT` (and `$BASE_URL`, `$REDIS_URL`) are set with the right WORKSPACE_ID fallback.

**A spawned `.claude/worktrees/…` checkout runs `bin/workspace_setup --without_seeds` before anything else** — until it has, `bin/env` falls back to the *main* checkout's port, database and Redis. The `sandbox-test-setup` skill has it.

**A workspace's database generally starts empty** — created and migrated, but not seeded, so `Bike.count` is 0 and real pages render nothing. Run `bundle exec rails db:seed` when you need records to try something in development; `bikeindex_development_$WORKSPACE_ID` is a per-workspace throwaway, so seeding or re-seeding it is safe and never needs asking.

**`bin/rails restart` for anything a reload misses** — a renamed initializer, a pin dropped from `config/importmap.rb`, a Lookbook registry that's stopped listing new scenarios, a gem a merge bumped. It bounces puma alone, so bin/dev's watchers survive and dev Sidekiq doesn't (`rerun` watches `app,db,lib`, not `config`). Fine to run against a server someone else started; starting or killing `bin/dev` isn't — **except in a spawned `.claude/worktrees/…` checkout, which is yours alone: start it there yourself.** The `sandbox-test-setup` skill has which checkout is whose.

**A renamed initializer is the one that reads as anything but a stale boot**: `config/routes.rb` reloads, dies partway through its draw on the missing constant, and everything below that line 404s while the page itself raises a bare `NameError` on a route helper.

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
- Use full class/module names everywhere — `UI::Forms::Combobox::Component`, not the `Combobox::Component` that lexical scope also resolves from inside `UI::Forms`. A class naming *itself* is the exception: `self.class.perform_in`, not a re-typed `EmailJobs::ScheduledSurveyJob.perform_in` — `BikeJobs::UpdateTheftAlertFacebookJob` is the pattern, and it keeps the next namespace rename off these lines
- **A namespace under `Admin::` or `Pages::` shadows a top-level one of the same name** — `Pages::Search` hides the `Search::` controllers from every `.rb` nested in it. Nothing fails at boot; it raises only where something reads the shadowed constant, so check a new namespace against `Object.const_defined?("LandingPages", false)` after an eager load. Rename the collision away rather than prefixing call sites with `::` — job namespaces carry the `*_jobs` suffix, `LandingPageOrganizations` holds the landing-page slugs. Templates are exempt: a compiled template's `Module.nesting` is the component class alone, so a bare `Saml::` there still reaches the top level.
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

**Branch around `translation`, never inside its key.** `translation(found? ? ".found_at" : ".impounded_at")` hides both keys, so i18n-tasks reports them unused and they get deleted — write `found? ? translation(".found_at") : translation(".impounded_at")`, repeating the interpolation arguments rather than hoisting the key into a local. A set of any size is a `case` with a literal key per branch. It's what hid `thread_show`'s `:removed_message`, which matched no key at all.

Run `bundle exec rails prepare_translations` after hand-editing a `component.en.yml`; `bin/lint` doesn't normalize YAML. It strips comments, so a note about the copy — a casing convention, a term to leave untranslated — has to live in `component.rb`.

**A component's copy lives in that component's own sidecar, and orphaning is never a reason to leave it somewhere else.** The sync relocates the other four locales on its next run, and non-English readers fall back to English only until it does — a scope that doesn't match its component doesn't expire.

**Don't hand-edit `config/locales/translation.*.yml` for a new key either** — the sync writes those four too. A lookup in another locale raises rather than falling back in test, so the three `:nl` specs (`shared_blocks/footer`, `navbar/wrapper`, `header_tags`) go red until the sync reaches the key.

When a sync lands on the base, apply the base's move onto your files rather than the reverse, then check for a scope both sides created: it auto-merges into two sibling keys of the same name and YAML keeps the last.

**i18n-tasks sees only `en`, and `config/locales/translation.*.yml` has to stay out of its `data.read`** — reading them makes `normalize` rewrite all four, which translation.io rewrites back on its next run; routing them nowhere deletes them. All they'd report is a scope move's orphan, which the sync prunes anyway.

## Subagents

When a command fans out to subagents — `/simplify`, `/code-review`, or an ad-hoc fan-out — pick the model by how much of the *search* the agent has to invent, not by how simple the task sounds:

- **`model: "haiku"`** when the command is already specified: "run this grep and summarise it", "read these four files and pull out X". There's nothing to devise.
- **`model: "sonnet"`** when the agent has to work out *how* to look ("every call site of X", "which specs touch Y"). Haiku compensates by flailing, and the per-token discount doesn't survive it.
- **Omit `model:`** (inherit the session model) for judgement — the passes that catch an unvalidated param landing in a fragment cache key, or a shared partial's N+1.

Delegate the enumeration rather than eyeballing a grep — a hand-written grep anchors on one method name and misses the call sites that don't use it.

## Testing

Uses RSpec. All business logic should be tested. The `rspec-testing` skill covers project-specific style (`context`+`let`, request specs over controller specs, avoiding mocks). A test that fails intermittently is the `fixing-flaky-failures` skill — coverage is never what gives way to make CI green.

**Verify with `bundle exec rspec` over the spec files covering what you changed — usually one to three.** Not `bin/turbo_tests`, `bin/ci`, or a whole directory (`spec/integration`, `spec/components`) — that's a suite run by another name. "It renders on every page, so anything could break" is the rationalization to watch for. A red example is a reason to re-run that example, not its directory. **Redesigning a page means running that page's own integration spec**, whose filename names the route rather than anything you edited — `registrations_search_spec.rb` drove markup #4268 had replaced weeks earlier, and nothing else failed. Say which specs you ran and why those. A `:js` spec failing on a missing Tailwind build is the `sandbox-test-setup` skill, not a reason to switch runners.

**A spec that lands on `/admin` seeds `Organization.example` in a `before`.** The dashboard reads it
under the reading role, so a superuser login that redirects there raises `ActiveRecord::ReadOnlyError`
on a write to `organizations` — which reads as a database misconfiguration rather than a missing
record. `spec/integration/admin/news_images_spec.rb` and `spec/requests/admin/dashboard_request_spec.rb`
both do it.

**Assert on what a drain produces, not on the flag that precedes it.** A column a job reconciles when it runs records what was true at write time — `Ownership#skip_email` is one — so it answers a different question than the one you're asking.

**Never hand-edit a VCR cassette**, and never `git checkout` away one a spec run re-recorded. To clear stale contents, `rm` the file and re-run the spec.

**Name a cassette in lowercase, without the constant** — `stripe-update_prices_job`, not `StripeJobs::UpdatePricesJob`. A namespace rename then leaves every cassette alone, and the name greps to its own filename, which the constant form doesn't: VCR rewrites `::` and `.` to `_` on the way to disk.

## Frontend Development

Uses Stimulus.js for JavaScript and Tailwind CSS for styling. SCSS and CoffeeScript files exist but are deprecated. The `bin/dev` command handles Tailwind and JS builds. The `frontend-conventions` skill has the conventions.

Check whether the dev server is up: `curl -fs "$BASE_URL/" >/dev/null`. If it isn't, **stop and ask the user to start it** so Tailwind and JS asset watchers are running before any frontend work — or, in a spawned `.claude/worktrees/…` checkout, start it yourself.

**`app/views` holds more `.haml` than `.erb`** — deprecated, but 301 files against 266, so a grep for call sites that passes `--include='*.erb'` and stops there misses the majority of the directory. Anything a view can reach needs `*.haml` in the pathspec too; the miss surfaces as a `NoMethodError` at render, caught only by a spec that renders that page.

## Pull requests

- When creating a PR, run the `/pr` workflow rather than calling `gh pr create` directly — `/pr` detects frontend diffs and captures desktop+mobile screenshots, which it posts as a `## Screenshots` comment (never in the body, so the summary stays first). `.claude/hooks/pr-guardrails.sh` denies the authoring commands until that skill is loaded.
- **Merging a PR is the human's, including when they ask you to do it in the moment.** Say the PR is ready and leave it. The same hook denies it, and won't be talked round — but it only covers agents running here, so treat the rule as the thing to follow rather than the hook as the thing to get past.
- To attach a local image (screenshot, .png/.jpg, CleanShot capture) to an existing GitHub PR, the `gh` CLI **cannot upload images** — use the `github-pr-images` skill, which drives a real browser to GitHub's user-attachments uploader.

## Architecture notes

- **`app/components` has five top-level folders, and a new component goes in exactly one of them**: `ui` (the design system — reusable controls and primitives, of which `ui/forms` is every form control; reading a domain constant doesn't disqualify one, `UI::Forms::Turnstile` reads `EmailDomain.risky_email?`), `atoms` (small renderers reused across pages — `Atoms::Serial`, `Atoms::Admin::Badges::User`), `pages` (one namespace per route, `Pages::Admin::Bikes::Table`), `shared_blocks` (the chrome around a page — navbar, footer, alerts), and `emails`. Nothing else belongs at the top level.
- **A new state on the registration show page is a new alert, not a branch inside a sibling.** `Pages::Registrations::Show::CurrentAlerts::Wrapper` holds a flat array whose members each render themselves or nothing, so adding one costs an array entry and no conditionals — `SentToNewOwner` is the pattern. The tell that a branch landed in the wrong component: its class comment stops describing the class, its `en.yml` scope mixes two vocabularies, and its preview and spec each grow an "except this one case" note.
- **Moving a file silently un-suppresses whatever was keyed to its old path.** `.herb.yml` excludes lint rules by path, `config/brakeman.ignore` hashes the file path into each fingerprint, and `config/i18n-tasks.yml` routes deep component scopes by path — so a rename re-enables the rule, obsoletes the entry, and leaves a write rule pointing at nothing, and none of the three says so until CI fails or a key lands in the wrong sidecar. Grep the repo root and `config/` for the old path, not just `app/`; re-fingerprint brakeman from `brakeman -f json` rather than hand-editing the path.
- **Changing a `PublicImage::VARIANTS` transformation re-keys every variant** — the key digests the transformations. Existing objects orphan and regenerate lazily, and the heic R2 cassette re-records: `rm` it and re-run rather than committing the appended interactions.
- **`UI::ButtonLink::Component(method:)` renders a `button_to` — a block-level `<form>`, not the inline `<a>` it replaced — unless a `confirm:` comes with it, which puts the method on a Turbo link instead.** It can't nest inside another `form_for`, and it closes an open `<p>` the way any flow element does — so a `link_to … method:` converted in prose silently breaks the paragraph around it, and one converted beside an `f.submit` has to move out of the form. Layout classes belong on the wrapper via `form: {class:}`, which replaces Rails' own `button_to` class rather than adding to it.
- **A component built but never rendered can't call a route helper.** A component built only to read values off it never gets a `#controller`, so any `*_path` on one raises `ViewComponent::ControllerCalledBeforeRenderError` — which names `#controller` rather than the helper. Build the URL in whichever component is actually rendering, off the values the data object exposes.
- **A Tailwind `@utility`'s position in the generated sheet follows the properties it declares.** Adding a declaration to an existing one moves the whole rule, so it can drop behind a class it used to outrank and silently undo a sibling declaration — `rounded-none` added to `twfullbleed` put the full-bleed card's sides and top back. Force each declaration (`tw:border-x-0!`) rather than relying on where the rule lands.
- **Multi-database**: primary (`ApplicationRecord`) + analytics (`AnalyticsRecord`). Use `db:migrate:down:analytics` for analytics migrations
- **Soft delete**: some models use `acts_as_paranoid` with `deleted_at` column; use `unscoped` in admin controllers when needed
- **Fragment caches carry the locale; `Rails.cache.fetch` doesn't.** `ApplicationComponentHelper#cache` folds `I18n.locale` into every key, so a component's own locale-less `cache_key` is fine. A `Rails.cache.fetch` in a service skips that, and one locale serves another's copy — `UserServices::MenuItemsOrg` did. Locale comes from a request param or `Accept-Language` as much as `user.preferred_language`, so `current_user` in the key doesn't stand in for it.
- **A bike is written on every user-facing edit path, so `cache_key_with_version` already moves.** `BikeServices::Updator` merges `updated_by_user_at: Time.current` into its `@bike.update`, and the records edited through the bike's nested attributes (marketplace listing, stolen record, address) all save that way — so "editing X doesn't touch the bike" is nearly always wrong, and a fragment cache keyed on the bike needs no extra term for X. Probing it with a bare `bike.update(...)` in `rails runner` bypasses the updator and shows no change; go through the controller.
- **A version constraint in the `Gemfile` needs a matching `.github/dependabot.yml` ignore.** Dependabot widens the constraint rather than skipping the update, so a pin with no ignore entry is silently reverted by a later bump PR — `redis` went that way in #4215, undoing #4175 and leaving its comment behind to explain a pin that was no longer there.
- **Every user has a `password_digest`** — `User#set_calculated_attributes` gives passwordless accounts a random one so `has_secure_password` is satisfied. So it answers nothing about whether someone chose a password; `passwordless_user?` is that question.
- **`Organization#is_invoiced?` is neither a money question nor a feature check.** It means an active invoice, the org's own or its `parent_organization`'s, and a $0 invoice sets it — which is how law enforcement gets features. `paid_money?` is the money question. It diverges from `enabled_feature_slugs` in both directions too: regional children and ambassadors get slugs with no invoice, and a child of an invoiced parent gets the flag with no slugs.
- **`user_emails.email` is not unique** — no unique index, no uniqueness validation, and only confirmed rows share a partial index, so the same address can sit on two accounts. `UserEmail.where(email:)` therefore reaches rows belonging to whoever else holds it; scope an address lookup to its user (`user.user_emails.friendly_find`, or a `user_id` term) before writing to what comes back.

# Initial setup

```bash
bundle install # install ruby dependencies
bundle exec rails db:create db:migrate # create the databases
bundle exec rails db:seed # populate them (test users, organizations, bikes)
```
