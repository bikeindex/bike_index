# Pre-push cleanup

The cleanup and migration halves of SKILL.md's **Prepare the branch**, in full. Everything here runs against committed work and diffs `origin/main...HEAD` — substitute the base branch from **Orient**, since shell state doesn't carry between commands.

## Simplify, lint, and conform to CLAUDE.md

Invoke the `/simplify` command to review the changed code for reuse, simplification, and efficiency cleanups and apply them. It's quality-only — it won't touch correctness — so it's safe to run unattended; if it reports nothing to clean up, move on.

Skip it when the diff has no code in it — a docs-, skill- or config-only branch gives it nothing to review, and it fans out subagents to find that out.

Then run `bin/lint` to auto-format (it also picks up whatever `/simplify` just changed). Always `bin/lint`, never another formatter or `standardrb` directly. Scope it to the branch's files rather than walking the whole repo:

```bash
{ rtk proxy git diff --name-only --diff-filter=d origin/main...HEAD
  rtk proxy git diff --name-only --diff-filter=d HEAD
} | sort -u | xargs bin/lint
```

`xargs` rather than `bin/lint $(…)`, because zsh doesn't word-split an unquoted command substitution — the interpolated form hands the whole list over as one argument and reports `Not found:` followed by every file. `rtk proxy` for the same reason the greps below need it: the hook rewrites these into a stat whose trailing `Changes:` line then arrives as a filename.

**Both halves are load-bearing.** `origin/main...HEAD` sees only *committed* work, and `/simplify` ran immediately above — so its edits are uncommitted, and a file it touched that the branch hadn't committed yet (a shared controller it reached into, say) is invisible to that range and goes unlinted. The second `git diff HEAD` picks up the working tree. Same union applies to the spec scoping below.

**Check that substitution produced something first.** With no arguments `bin/lint` lints the whole repo (`bin/lint:64` falls through to a bare `standardrb --fix`), so an empty diff turns the scoped command into exactly the whole-repo run it's avoiding.

A clean run over Ruby-only paths prints **nothing at all** — the summary table comes from the ERB formatter, so silence plus exit 0 is the pass, not a swallowed error. `--diff-filter=d` drops deleted paths so they don't show up as "Not found". Files with no linter (`.haml`, `.scss`, `.md`) are skipped, so a branch touching none of the lintable types exits cleanly rather than looking like a failure. It takes directories too, so `bin/lint app/components/foo` works while you're still iterating. Never revert what the linter wrote — if a too-broad run reformats files outside the branch, those fixes stay in the diff.

Scope specs the same way — the ones covering what the branch changed, never a bare `bundle exec rspec` or a whole top-level directory (see the `rspec-testing` skill). CI runs the full suite; a green PR isn't your job to prove locally.

**`bin/rails tailwindcss:build` before the `:js` ones, after the last template edit.** Tailwind's content scan reads the templates, so adding or removing a class in an `.erb` changes the built CSS — and a system spec asserting a computed style (`spec/components/ui/dropdown/component_system_spec.rb` reads `getComputedStyle(...).color`) fails against the stale build until it's rebuilt. A merge that brings in `app/assets/tailwind/**` does it too. The failure names the assertion, not the build, so it reads as a real regression.

Then review the changed files against `CLAUDE.md` (root and any nested ones in touched directories) and fix what doesn't conform — code style, testing conventions, and frontend rules. Only touch lines this branch already changed.

**`bin/update_component_digests` goes after the last code edit, not before.** A `MARKUP_DIGEST` covers everything its cached tree renders out into, so editing a shared component (`UI::ActiveLink`, `UI::Button`) stales the digest of every component that renders it — `PageBlock::Navbar::Wrapper` and `PageBlock::Footer` both, for one edit — and regenerating before `/simplify`'s or the CLAUDE.md pass's own edits just means doing it twice.

### The comment audit

**Required, not conditional on the diff looking clean.** List the comments the branch adds or edits:

```bash
git diff origin/main...HEAD -U0 -- '*.rb' '*.erb' '*.js' '*.ts' '*.coffee' '*.scss' '*.css' '*.rake' '*.yml' 'bin/*' |
  grep -E '^(\+\+\+ |\+.*(#|//|<%#|/\*))'
```

The `+++ b/…` lines keep each hit attached to its file; the code-path filter keeps markdown headings out. It catches trailing comments too, and over-matches on `#{}` interpolation — that's fine, the list is candidates to judge, not verdicts.

**An empty result on a non-empty diff means the pathspec missed the branch, not that the branch is clean** — the same silent-pass the rtk section below describes, from a different cause. `bin/kamal_review` (no extension) and `.github/workflows/*.yml` are why `bin/*` and `*.yml` are on the list; add whatever else the branch touches and re-run rather than reading the blank as a verdict.

Judge each against the **Comments** section of `CLAUDE.md` and reach a verdict of keep / razor / delete on every line — a comment survives only by carrying a *why* the code can't. Deleting is the common outcome, razoring the next most common; leaving a block untouched should be the exception you can justify. Watch hardest for the ones you wrote to explain your own reasoning as you worked: narration of the change, mechanism the code already shows, and a second sentence justifying the first.

### The cycle-type translation check

`CLAUDE.md`'s Translations section has the rule; this is how to find the branch's violations:

```bash
git diff origin/main...HEAD -- '*.en.yml' 'config/locales/en.yml' | grep -in '^+[^+].*bike'
```

Read each hit. Key names (`about_this_bike:`), the product name ("Bike Index"), and copy that really is bike-only are fine; a value saying "bike" about the registration is not. `Registrations::Show::CurrentAlerts::ClaimImpound` and `Registrations::Show::WrapperConsumer` are the pattern for fixing one, and `spec/components/registrations/show/current_alerts/claim_impound/component_spec.rb` shows how to cover it.

### Only if you have rtk: check these greps read a diff at all

Skip this section if `rtk` isn't installed — nothing below applies to a plain shell.

rtk's hook rewrites *some* `git diff` invocations into a summarized stat, and `grep` over a stat matches nothing. Both greps above then report clean having read zero lines, which is indistinguishable from passing. Measured on one branch: the cycle-type command was rewritten and found 0 of its 17 hits, while the comment audit's ran through untouched — so which invocations get rewritten isn't predictable from the command, and has to be checked rather than assumed.

Counting is worse than grepping, because the stat isn't empty. It ends with a `Changes:` line, so `git diff --name-only … | wc -l` reports **1** for a diff that touches none of the paths — the migration and cycle-type checks both read as one hit rather than zero, and chasing a migration the branch never added is a slower failure than missing one. Pipe to `wc -l` only through `rtk proxy`, or read the file list itself.

`rtk proxy` bypasses the hook. Run the check both ways when it comes back empty; disagreement means you were grepping a stat:

```bash
rtk proxy git diff origin/main...HEAD -- '*.en.yml' 'config/locales/en.yml' | grep -in '^+[^+].*bike'
```

Commit everything from this before re-dating migrations.

## Freshen stale migration timestamps

Every migration this branch adds must be dated within the past 2 days.

```bash
git diff origin/main...HEAD --name-only --diff-filter=A -- db/migrate db/analytics_migrate
date -d '2 days ago' +%Y%m%d%H%M%S 2>/dev/null || date -v-2d +%Y%m%d%H%M%S
```

(GNU `date` takes `-d`, BSD/macOS `date` takes `-v` — the fallback covers both.) Compare each filename's leading timestamp against that cutoff. No added migrations, nothing stale, or a timestamp in the *future* → skip. The rollback needs a working local database; if it isn't reachable, say so and leave the timestamps alone rather than failing mid-workflow.

For each stale migration, in this order (rollback must happen while the old version is still on disk):

1. Roll it back: `bin/rails db:migrate:down:primary VERSION=<old-timestamp>` (`db:migrate:down:analytics` for `db/analytics_migrate` files) — the un-namespaced `db:migrate:down` refuses in this multi-database app.
2. `git mv` the file to the same name with a fresh `date +%Y%m%d%H%M%S` timestamp — when re-dating several, keep their relative order with incrementing timestamps.
3. `bin/rails db:migrate` to re-apply and regenerate the structure files — never hand-edit `db/structure.sql`.
4. Commit the renames together with the regenerated structure files.
