# Pre-push cleanup

The cleanup and migration halves of SKILL.md's **Prepare the branch**, in full. Everything here runs against committed work and diffs `origin/main...HEAD` — substitute the base branch from **Orient**, since shell state doesn't carry between commands.

## Simplify, lint, and conform to AGENTS.md

Invoke the `/simplify` command to review the changed code for reuse, simplification, and efficiency cleanups and apply them. It's quality-only — it won't touch correctness — so it's safe to run unattended; if it reports nothing to clean up, move on.

Skip it when the diff has no code in it — a docs- or skill-only branch gives it nothing to review, and it fans out subagents to find that out. Config by file extension isn't the test: a `.github/workflows/*.yml` with a `run:` block is a shell script, and reviewing one is how the nightly-reseed branch found its only cleanup.

**Tell each review agent to read other commits with `git show <ref>:<path>`, never a checkout.** They share the working tree, so one that checks out the base to compare leaves the others reading pre-branch files and reporting on code that isn't there — it happened on #4677.

**Read `git diff` as soon as the agents return, before running anything.** An agent that stops mid-verification leaves its edit in the tree — including a sweeping edit it reverted to test, which then reads as your regression.

**Brief the agents with the constraint, not the shape you think satisfies it.** "A cell block is instance_exec'd, so a component method is unreachable inside one" is a fact they can work from; "the lambda is required, judge only how it's used" is a conclusion, and it hid that `method(:…)` is how four sibling org tables already bind exactly that. Likewise "the user asked for a shared component" is a constraint, while "the user requested this new component" is a conclusion — it kept `UI::BulkTableCard` from the reuse reviewer, when the shared component was `UI::Table::InCard` extended. Declining a finding is yours to do on the way back, not theirs to be told up front — the exception is a *second* run, where naming what a previous pass already triaged is what keeps them off it.

**On a second run against the same branch, scope it to the commits since the last one** — `/simplify` defaults to the whole branch diff, so re-running it resurfaces every finding already triaged, including the ones deliberately declined. Pass the range (`git diff <last-simplify-commit>..HEAD`) as its argument.

**The previous run's merge from the base names that commit** — `git log --merges -2 --format=%h origin/main..HEAD | tail -1`. It's the *second* one because **Prepare the branch** merges before it cleans, so this run's own merge is already the most recent by the time you get here, and `-1` scopes the range to that merge alone — an empty diff, which reads as a clean branch rather than a wrong range. A run that had nothing to merge left no commit, so the range can reach back further than the last run; that costs a re-triage, not a wrong scope. A merge made *between* runs — the user asking to merge main — errs the other way: it's newer than the last run, so the range silently drops the commits before it. Read the session for one before trusting the count.

**That range breaks when earlier branch work was split into its own PRs and merged.** Those commits return through a merge from the base, so `<last-simplify-commit>..HEAD` includes all of them plus everything else the base gained — hundreds of files, none of it yours. Check `git log --oneline <last-simplify-commit>..HEAD`; if it lists the base's merges, scope to your own commits (`git show` each) instead. `--no-merges` doesn't rescue it — it hides the merge commits, not the commits they brought in. **Scoping to your own commits breaks too when one is a stacked PR squash-merged in**: the squash carries every base merge the stacked branch took, so `git show` lists the base's files as its own (#4882's squash into #4805 named 72, only 23 of which differ from main). Keep only the files that also appear in `git diff --name-only origin/main...HEAD`.

Then run `bin/lint` to auto-format (it also picks up whatever `/simplify` just changed). Always `bin/lint`, never another formatter or `standardrb` directly. Scope it to the branch's files rather than walking the whole repo:

```bash
{ git diff --name-only origin/main...HEAD
  git diff --name-only HEAD
  git ls-files --others --exclude-standard
} | sort -u | xargs bin/lint
```

`xargs` rather than `bin/lint $(…)` — command substitution splits on spaces in filenames.

**All three are load-bearing.** `origin/main...HEAD` sees only *committed* work, and `/simplify` just edited the tree — a file it touched that the branch hadn't committed yet is invisible to that range and goes unlinted. `git diff HEAD` in turn sees only *tracked* files, so a file the branch adds is in neither until it's staged: a new component template lints clean by never being linted, and CI's `lint_and_scan` is what finds it. `--exclude-standard` keeps the gitignored paths out. Same union applies to the spec scoping below and to `code-review-bike-index`'s audits, which also run before the commit.

**Check that substitution produced something first.** With no arguments `bin/lint` lints the whole repo (it falls through to a bare `standardrb --fix`), so an empty diff turns the scoped command into exactly the whole-repo run it's avoiding.

A clean run over Ruby-only paths prints **nothing at all** — the summary table comes from the ERB formatter, so silence plus exit 0 is the pass. Take that status from `bin/lint` itself — piped to `tail` it's `tail`'s, and the ERB summary prints "All files are clean!" even when standardrb never ran. Paths the branch deleted are skipped silently — "Not found" means a path git has no history for, ie a typo. Files with no linter (`.haml`, `.scss`, `.md`) are skipped. It takes directories too, so `bin/lint app/components/foo` works while you're still iterating.

Scope specs the same way — the ones covering what the branch changed, never a bare `bundle exec rspec` or a whole top-level directory (see the `rspec-testing` skill). CI runs the full suite; a green PR isn't your job to prove locally. Scoping too far down is the live risk: walk the changed `app/` paths to their `spec/` siblings rather than the specs the change *feels* like it's about — a helper edited in passing has its own, and one like `spec/helpers/header_tag_helper_spec.rb` asserts its whole options hash with `eq`, so an added key reds it.

**`bin/rails tailwindcss:build` before the `:js` ones, after the last template edit.** Tailwind's content scan reads the templates, so adding or removing a class in an `.erb` changes the built CSS — and a system spec asserting a computed style (`spec/components/ui/dropdown/component_system_spec.rb` reads `getComputedStyle(...).color`) fails against the stale build until it's rebuilt. A merge that brings in `app/assets/tailwind/**` does it too. The failure names the assertion, not the build, so it reads as a real regression.

Then invoke the `code-review-bike-index` skill with the Skill tool: the `AGENTS.md` conformance pass and every audit — spec, documentation, churn, comment, model-comment, backfill, asset, controller, component, markup and marketing page — and the cycle-type translation and product-name checks. **Required every run**, not just when the diff looks messy — a docs- or skill-only branch included, unlike `/simplify`, since its documentation audit is the check those branches get. Its fixes come back uncommitted, and its reply goes into yours: the backfill verdict, every markup conversion with the commit it landed in, and every finding it left for the user — repeated marketing copy included.

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
