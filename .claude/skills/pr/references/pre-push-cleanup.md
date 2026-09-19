# Pre-push cleanup

The cleanup and migration halves of SKILL.md's **Prepare the branch**, in full. Everything here runs against committed work and diffs `origin/main...HEAD` — substitute the base branch from **Orient**, since shell state doesn't carry between commands. The audits inherit that: run them after committing, or pair them with a pass over `rtk proxy git diff HEAD`, or a comment you razored in the working tree still reads as present.

## Simplify, lint, and conform to CLAUDE.md

Invoke the `/simplify` command to review the changed code for reuse, simplification, and efficiency cleanups and apply them. It's quality-only — it won't touch correctness — so it's safe to run unattended; if it reports nothing to clean up, move on.

Skip it when the diff has no code in it — a docs- or skill-only branch gives it nothing to review, and it fans out subagents to find that out. Config by file extension isn't the test: a `.github/workflows/*.yml` with a `run:` block is a shell script, and reviewing one is how the nightly-reseed branch found its only cleanup.

**Read `git diff` before committing what it produced.** Its review agents edit the working tree to check their own findings, and one that stops mid-verification leaves the edit behind — indistinguishable from the changes you decided to apply.

**On a second run against the same branch, scope it to the commits since the last one** — `/simplify` defaults to the whole branch diff, so re-running it resurfaces every finding already triaged, including the ones deliberately declined. Pass the range (`git diff <last-simplify-commit>..HEAD`) as its argument.

**That range breaks when earlier branch work was split into its own PRs and merged.** Those commits return through a merge from the base, so `<last-simplify-commit>..HEAD` includes all of them plus everything else the base gained — hundreds of files, none of it yours. Check `git log --oneline <last-simplify-commit>..HEAD`; if it lists the base's merges, scope to your own commits (`git show` each) instead. `--no-merges` doesn't rescue it — it hides the merge commits, not the commits they brought in.

Then run `bin/lint` to auto-format (it also picks up whatever `/simplify` just changed). Always `bin/lint`, never another formatter or `standardrb` directly. Scope it to the branch's files rather than walking the whole repo:

```bash
{ rtk proxy git diff --name-only origin/main...HEAD
  rtk proxy git diff --name-only HEAD
} | sort -u | xargs bin/lint
```

`xargs` rather than `bin/lint $(…)` — command substitution splits on spaces in filenames. `rtk proxy` for the same reason the greps below need it: the hook rewrites these into a stat whose trailing `Changes:` line then arrives as a filename.

**Both halves are load-bearing.** `origin/main...HEAD` sees only *committed* work, and `/simplify` just edited the tree — a file it touched that the branch hadn't committed yet is invisible to that range and goes unlinted. Same union applies to the spec scoping and the audits below, which also run before the commit.

**Check that substitution produced something first.** With no arguments `bin/lint` lints the whole repo (it falls through to a bare `standardrb --fix`), so an empty diff turns the scoped command into exactly the whole-repo run it's avoiding.

A clean run over Ruby-only paths prints **nothing at all** — the summary table comes from the ERB formatter, so silence plus exit 0 is the pass. Take that status from `bin/lint` itself — piped to `tail` it's `tail`'s, and the ERB summary prints "All files are clean!" even when standardrb never ran. Paths the branch deleted are skipped silently — "Not found" means a path git has no history for, ie a typo. Files with no linter (`.haml`, `.scss`, `.md`) are skipped. It takes directories too, so `bin/lint app/components/foo` works while you're still iterating.

Scope specs the same way — the ones covering what the branch changed, never a bare `bundle exec rspec` or a whole top-level directory (see the `rspec-testing` skill). CI runs the full suite; a green PR isn't your job to prove locally.

**`bin/rails tailwindcss:build` before the `:js` ones, after the last template edit.** Tailwind's content scan reads the templates, so adding or removing a class in an `.erb` changes the built CSS — and a system spec asserting a computed style (`spec/components/ui/dropdown/component_system_spec.rb` reads `getComputedStyle(...).color`) fails against the stale build until it's rebuilt. A merge that brings in `app/assets/tailwind/**` does it too. The failure names the assertion, not the build, so it reads as a real regression.

Then review the changed files against `CLAUDE.md` (root and any nested ones in touched directories) and fix what doesn't conform — code style, testing conventions, and frontend rules. Only touch lines this branch already changed.

**`bin/update_markup_digests` goes after the last code edit, not before.** A `MARKUP_DIGEST` covers everything its cached tree renders out into — components and partials both — so editing a shared component (`UI::ActiveLink`, `UI::Button`) stales the digest of everything that renders it, `SharedBlocks::Navbar::Wrapper` and `SharedBlocks::Footer` both for one edit, plus any view template carrying a digest comment. Regenerating before `/simplify`'s or the CLAUDE.md pass's own edits just means doing it twice.

It hashes *files*, not output, and globs a component's whole directory — so a comment that renders nothing bumps the digest just the same, whether you put it in the template or in `component.rb`. Somewhere outside the component directory (`.herb.yml`, the PR body) is the free place to say it.

### The spec audit

**Required, same as the comment audit below.** List the examples the branch adds:

```bash
rtk proxy git diff origin/main...HEAD -U0 -- 'spec/**/*_spec.rb' |
  grep -E '^(\+\+\+ |\+\s*(it|scenario|specify) )'
```

Judge each one against a single question: **what bug does this fail on?** If you can't name a plausible edit that breaks the example *and* is wrong, delete it — a green assertion that can only go red when someone deliberately changes the thing it restates is a change-detector, and it costs a re-edit on every future change while catching nothing.

The ones to cut, all of which have been written here:

- **Framework behaviour.** `render_inline(described_class.new) { "content" }` then asserting the content rendered — that's ViewComponent's job, not the component's.
- **Passing an argument through.** Handing the component `title:` and asserting the title appears. Nothing between the input and the output can be wrong; assert what the component *decides* instead — which tab is active, which column is dropped.
- **A class list the template writes literally.** Pinning `class="tw:w-full tw:max-w-3xl"` re-asserts the source. The exception is a class the component *computes* — a conditional `active`, a width chosen from an argument — where the branch is the point.
- **What a request spec already covers.** A component spec listing the fields a form renders, next to a request spec that asserts the same names, is one of them maintained for nothing. Keep the one closest to the logic.

Keep, without hesitating, the ones tied to a failure mode: a conditional branch, a computed value, an argument guard that would otherwise fail silently, `it_behaves_like "cached_markup_digest"`, and any example written *because* something broke — say so in a comment above it, so the next audit doesn't mistake it for a change-detector.

This applies to the branch's specs, not the suite's. Don't delete pre-existing examples you merely moved between files.

### The documentation audit

When the branch adds or edits `CLAUDE.md`/`AGENTS.md` or anything under `.claude/skills/`, check every
claim it makes against the code before pushing — a doc asserting *why* something is done is as capable of
being wrong as a comment, and nothing runs it. The wrong ones read as obvious. Also check what the edit *moved* — a rule relocated into a skill is a rule
that only loads when that skill triggers.

### The churn audit

**Required.** Read the branch's own diff and ask of each hunk what it changes about what the code does. A moved argument, a re-ordered hash, a re-wrapped line: revert it rather than defending it in review.

```bash
rtk proxy git diff origin/main...HEAD --stat
```

Smallest files first — one at `+1 -1` is either the point of the branch or pure churn, and telling which takes a moment. `git checkout origin/main -- <file>` when the whole file is churn; when it rides along inside a real change, put the surrounding lines back so the diff shows only what moved.

**What `bin/lint` wrote is not churn** and stays, including in files the branch otherwise didn't touch — see the rule at the top of `CLAUDE.md`.

Sweeping mechanical edits are where this collects.

### The comment audit

**Required, not conditional on the diff looking clean.** List the comments the branch adds or edits:

```bash
git diff origin/main...HEAD -U0 -- '*.rb' '*.erb' '*.haml' '*.js' '*.ts' '*.coffee' '*.scss' '*.css' '*.rake' '*.yml' 'bin/*' |
  grep -E '^(\+\+\+ |\+.*(#|//|<%#|-#|/\*))'
```

The `+++ b/…` lines keep each hit attached to its file; the code-path filter keeps markdown headings out. It over-matches on `#{}` interpolation and catches trailing comments — the list is candidates to judge, not verdicts.

**An empty result on a non-empty diff means the pathspec missed the branch, not that the branch is clean** — the same silent-pass the rtk section below describes, from a different cause. `bin/kamal_review` (no extension) and `.github/workflows/*.yml` are why `bin/*` and `*.yml` are on the list; add whatever else the branch touches and re-run rather than reading the blank as a verdict.

Judge each against the **Comments** section of `CLAUDE.md` and reach a verdict of keep / razor / delete on every line — a comment survives only by carrying a *why* the code can't. Deleting is the common outcome, razoring the next most common; leaving a block untouched should be the exception you can justify. Watch hardest for the ones you wrote to explain your own reasoning as you worked: narration of the change, mechanism the code already shows, and a second sentence justifying the first.

### The cycle-type translation check

`CLAUDE.md`'s Translations section has the rule; this is how to find the branch's violations:

```bash
rtk proxy git diff origin/main...HEAD -- '*.en.yml' 'config/locales/en.yml' | grep -in '^+[^+].*bike'
```

Read each hit. Key names (`about_this_bike:`), the product name ("Bike Index"), and copy that really is bike-only are fine; a value saying "bike" about the registration is not. `Pages::Registrations::Show::CurrentAlerts::ClaimImpound` and `Pages::Registrations::Show::WrapperConsumer` are the pattern for fixing one, and `spec/components/pages/registrations/show/current_alerts/claim_impound/component_spec.rb` shows how to cover it.

### Only if you have rtk: `rtk proxy` anything you grep or count

Skip this section if `rtk` isn't installed — nothing below applies to a plain shell.

rtk's hook rewrites every `git diff` and `git log`. A `git diff` without `-U0` comes back summarized, its hunk lines indented, so `grep '^+…'` reads clean having matched nothing; `--name-only` gains a trailing `Changes:` line, so `wc -l` reports **1** for a diff that touches no matching path, and `bin/lint` takes it as a filename. `git log` loses its merge commits either way. Put `rtk proxy` on every diff you grep, count or hand to `xargs`.

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
