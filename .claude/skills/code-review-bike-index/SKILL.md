---
name: code-review-bike-index
description: >-
  Review the current branch against Bike Index's own conventions and fix what
  doesn't conform: an AGENTS.md conformance pass, then the spec, documentation,
  churn, comment, model-comment, backfill, asset, controller, component,
  markup and marketing page audits, and the cycle-type translation and product-name checks. Catches
  and removes comments that only restate the code, including a model's class
  comment that restates its name or sits above the `# == Schema Information`
  block. Trigger on "code-review-bike-index", "review this branch against the
  conventions", "audit the branch", "check the comments on this branch", and
  from the `pr` skill's cleanup. Not a bug hunt — `/code-review` is for
  correctness.
---

# Bike Index code review

## Who runs this

From a session with history, hand this skill to a subagent the way `AGENTS.md`'s **Who runs this** describes. Use no `model` override, because every audit is judgment. Brief it with the base branch, what the branch is for, and any choices the user already made, or it reverts them as churn. It replies with **The reply** below, its fixes left uncommitted in the working tree.

## Scope

Everything here diffs `origin/main...HEAD`, the base being `main` unless the caller names another — substitute it, since shell state doesn't carry between commands. That range sees only committed work: run after committing, or pair each audit with a pass over `git diff HEAD` and `git ls-files --others --exclude-standard`, or a comment you razored in the working tree still reads as present and a new file reads as absent.

**Only touch lines this branch already changed.** The exceptions are the model-comment audit, since `app/models` is clean of what it finds, and whatever files the controller and marketing page audits name a fix in.

## Conform to AGENTS.md

Review the changed files against `AGENTS.md` (root and any nested ones in touched directories) and fix what doesn't conform — code style and testing conventions. A frontend diff also reads the `frontend-conventions` skill: `AGENTS.md` points there rather than stating the frontend rules, so checking it alone misses them — a component that should have been a partial went through this pass on #4308.

## The spec audit

**Required, same as the comment audit below.** List the examples the branch adds:

```bash
git diff origin/main...HEAD -U0 -- 'spec/**/*_spec.rb' |
  grep -E '^(\+\+\+ |\+\s*(it|scenario|specify) )'
```

Judge each one against a single question: **what bug does this fail on?** If you can't name a plausible edit that breaks the example *and* is wrong, delete it — a green assertion that can only go red when someone deliberately changes the thing it restates is a change-detector, and it costs a re-edit on every future change while catching nothing.

The ones to cut, all of which have been written here:

- **Framework behaviour.** `render_inline(described_class.new) { "content" }` then asserting the content rendered — that's ViewComponent's job, not the component's.
- **Passing an argument through.** Handing the component `title:` and asserting the title appears. Nothing between the input and the output can be wrong; assert what the component *decides* instead — which tab is active, which column is dropped.
- **A class list the template writes literally.** Pinning `class="tw:w-full tw:max-w-3xl"` re-asserts the source. The exception is a class the component *computes* — a conditional `active`, a width chosen from an argument — where the branch is the point.
- **What a request spec already covers.** A component spec listing the fields a form renders, next to a request spec that asserts the same names, is one of them maintained for nothing. Keep the one closest to the logic.

Keep, without hesitating, the ones tied to a failure mode: a conditional branch, a computed value, an argument guard that would otherwise fail silently, anything asserting what a fragment cache keys on, and any example written *because* something broke — say so in a comment above it, so the next audit doesn't mistake it for a change-detector.

This applies to the branch's specs, not the suite's. Don't delete pre-existing examples you merely moved between files.

## The documentation audit

When the branch adds or edits `AGENTS.md` or anything under `.claude/skills/`, check every
claim it makes against the code — a doc asserting *why* something is done is as capable of
being wrong as a comment, and nothing runs it. The wrong ones read as obvious. **Grep the file for the subject before adding a line** — a fact the branch states in one section is often already stated in another, and the two drift; #4425 added an architecture note restating the testing line it had edited in the same run, and got it wrong in the restating. Also check what the edit *moved* — a rule relocated into a skill is a rule
that only loads when that skill triggers.

## The churn audit

**Required.** Read the branch's own diff and ask of each hunk what it changes about what the code does. A moved argument, a re-ordered hash, a re-wrapped line: revert it rather than defending it in review.

```bash
git diff origin/main...HEAD --stat
```

Smallest files first — one at `+1 -1` is either the point of the branch or pure churn, and telling which takes a moment. `git checkout origin/main -- <file>` when the whole file is churn; when it rides along inside a real change, put the surrounding lines back so the diff shows only what moved.

**What `bin/lint` wrote is not churn** and stays, including in files the branch otherwise didn't touch — see the rule at the top of `AGENTS.md`.

Sweeping mechanical edits are where this collects.

## The comment audit

**Required, not conditional on the diff looking clean.** List the comments the branch adds or edits:

```bash
git diff origin/main...HEAD -U0 -- '*.rb' '*.erb' '*.haml' '*.js' '*.ts' '*.coffee' '*.scss' '*.css' '*.rake' '*.yml' 'bin/*' |
  grep -E '^(\+\+\+ |\+.*(#|//|<%#|-#|/\*))'
```

The `+++ b/…` lines keep each hit attached to its file; the code-path filter keeps markdown headings out. It over-matches on `#{}` interpolation and catches trailing comments — the list is candidates to judge, not verdicts.

**An empty result on a non-empty diff means the pathspec missed the branch, not that the branch is clean**. `bin/kamal_review` (no extension) and `.github/workflows/*.yml` are why `bin/*` and `*.yml` are on the list; add whatever else the branch touches and re-run rather than reading the blank as a verdict.

Judge each against the **Comments** section of `AGENTS.md` and reach a verdict of keep / razor / delete on every line — a comment survives only by carrying a *why* the code can't. Deleting is the common outcome, razoring the next most common; leaving a block untouched should be the exception you can justify. Watch hardest for the ones you wrote to explain your own reasoning as you worked: narration of the change, mechanism the code already shows, and a second sentence justifying the first.

**A class comment is held to the same bar, line by line.** Delete a line that restates the class name ("The record that a registrant agreed to an education course" over `EducationCourseAcknowledgment`) or repeats a comment already on a method or association inside the class. What survives is what no single line of the class can say: why the table exists, what a column holds beyond its type, how the record outlives something it belongs to. `BikebookModel`'s is the pattern.

## The model-comment audit

**Required.** A model's class comment goes between the `# == Schema Information` block and `class`, never above the schema block — `app/models/organization_message.rb` is the pattern. List every comment above a schema block:

```bash
awk 'FNR==1{buf="";s=0} s{next} /^# == Schema Information/{printf "%s",buf;s=1;next} /^#/ && !/frozen_string_literal/{buf=buf FILENAME": "$(0)"\n"}' app/models/*.rb app/models/*/*.rb
```

`$(0)` is awk's whole line, spelled so the Skill tool doesn't swap in its first argument the way it does for the bare form.

Silence is the pass. Every hit is a class comment in the wrong place: put it through the class-comment bar above, delete the lines that fail it, and move what's left down to sit directly above `class`.

## The backfill audit

**Required.** Ask whether rows already in the database still fit the branch's code. The shapes that leave them behind:

- **A vocabulary stored as data** — an enum value, a jsonb key or list, a class name in a string column. #4458 replaced names `Export#options["headers"]` holds; `Backfills::NotificationDeliveryErrorRenameJob` is a rename.
- **A new column whose value depends on existing data**, not its default — `Backfills::OrganizationRolePriorityJob`.
- **A changed calculated attribute** — existing rows keep the old value until something re-saves them. `Backfills::OrganizationPaidMoneyJob`.

Find what reads the old form before calling one due. A value nothing reads again doesn't need one, and one recording what happened — `Export#written_headers` describes the file that was written — shouldn't be rewritten.

State the verdict in your reply either way, naming the stored values you checked. When one is due, write it without asking — a job in `app/jobs/backfills/` with its spec — and say the PR body leads with it (the `pr` skill's **Write the summary body**).

## The asset audit

**Required when the branch adds a file under `app/assets/images/`.** List them:

```bash
git diff origin/main...HEAD --name-only --diff-filter=A -- app/assets/images
```

Icons and images both go through the markup audit below, which checks each one for a file the repo already has. **One with no existing copy is sized to the slot it renders in.** Read its width (`sips -g pixelWidth`) against the widest it displays — its `max-w-*`, or its grid column — and name both in your reply. Wider than twice that, resize it to twice and save it as WebP, with the `image_tag` dimensions to match. #4821 shipped a 1560px PNG into a 520px column.

## The controller audit

**Required when the branch adds a Stimulus controller or wires one to new markup.** List both:

```bash
git diff origin/main...HEAD --name-only --diff-filter=A -- app/javascript/controllers
git diff origin/main...HEAD -G 'data-controller|controller:' --name-only
```

For each controller named, look for one that already does its job — a shared one in `app/javascript/controllers/ui/` or the top level, or a sibling in another namespace — and for two in the branch's namespace doing the same thing. Fold a duplicate into the shared one, an option on it rather than a second controller, and delete the copy. `bikebook--center-current` into `ui--tabs` and `bikebook--image-fallback` into `image-fallback` are the pattern. **When nothing shared exists, the branch's controller and whatever else does the same job — another controller, or an action inside another page's controller — become one shared controller**, the other page switched over to it too. Flagging the pair and keeping both is a miss. `scroll-to-hash`, which replaced the shop's and the memberships page's scroll actions, is the pattern. Name each one you kept and what it does that nothing shared covers.

## The component audit

**Required when the branch adds a directory under `app/components/`.** List them:

```bash
git diff origin/main...HEAD --name-only --diff-filter=A -- 'app/components/**/component.rb'
```

For each, name the existing component it renders or duplicates. One that wraps a single `UI::*` component in chrome is that component with an argument — ask the user whether to fold it in, since a new `UI::*` argument needs their permission. `UI::BulkTableCard` into `UI::Table::InCard`'s `column_settings:` is the pattern.

## The markup audit

**Required when the branch adds markup or an icon.** Run the `use-existing-markup` skill. It converts the hand-written markup to existing components without asking, covering marketing pages, buttons, icons and shadows. **Whenever it changes anything, tell the user in your reply.** List each conversion with the visible change it makes. A page that looks different after a PR update, with no word about why, is what this prevents. Put its callouts (big shadows, and hover states on things that aren't buttons) in the same reply. When it changes nothing, say so in one line.

## The marketing page audit

**Required when the branch adds or edits a marketing page** — one `use-existing-markup`'s **Marketing pages** section names, or one rendering `SharedBlocks::Marketing::*`. Read its templates whole, the page's own sub-components (`Pages::Shop::Product`) included, with each sidecar `en.yml`.

**Reach a verdict on every numbered check, in your reply, by number.** Every check but the last names its fix: make it, in whatever file it lands in — a sibling page, `SharedBlocks::Marketing::Wrapper`, a footer link. Flagging one of these instead of fixing it is a miss.

1. **Kit blocks.** Every heading with an intro paragraph is `SharedBlocks::Marketing::SectionHeading`, inside a sub-component too, and every figure over a label — a price grid in a `<dl>` as much as a stats row — is `SharedBlocks::Marketing::NumberBlocks`. "No component covers it" is never the verdict for either.
2. **Repeated objects.** A block written out more than once — feature cards, stat tiles, steps, each a copy of the same markup with different copy — is one existing component rendered in a loop over the values: a `SharedBlocks::Marketing::*` block from `use-existing-markup`'s table, or a `UI::*` one.
3. **Gray bands** read `SharedBlocks::Marketing::Wrapper::Component::BAND_CLASSES`, with the section adding its border sides. Where the constant is missing, add it to the wrapper.
4. **Fonts** are the ones the wrapper loads: `tw:font-header` and the body font. Replace every `tw:font-[…]` and delete any font `<link>` the page loads itself.
5. **A value kept in step with something outside the repo is one constant** the template reads — a price that has to match Shopify is a `PRICES` entry, not a literal where it shows.
6. **The controller** rendering the page has `before_action :force_html_response` — `AGENTS.md`'s architecture notes say why, and a redirect into the page is what triggers it.
7. **The preview.** The page's `component_preview.rb` renders it through `SharedBlocks::Marketing::Wrapper`, the way the controller does.
8. **Entry points.** A page that takes over an old destination takes every way in: grep for the old route helper, the external URL and any `/info` post on the subject, and point each at the new page — an `/info` post through a `Blog` slug method and a branch in `InfoController#show`, the way `Blog.why_donate_slug` reaches `/donate` — with an anchor where a link means one section. Add the page to `config/initializers/sitemap_pages.rb`, and drop the `as:` from a redirect route whose helper nothing calls any more. `/shop` (#4821) is the pattern.
9. **Repeated text and values.** List every phrase, figure or link that says the same thing twice on the page: a heading restated by the intro under it, a stat in the hero and again in a number block, a call to action that appears twice, a sentence the closing banner repeats. Compare what the copy *says*, not only identical strings — "Register your bike for free" and "Registration is always free" are one claim. **Don't delete any of them.** Flag each set, quoting every occurrence and where it sits, for the user to choose which to keep.

## The cycle-type translation check

`AGENTS.md`'s Translations section has the rule; this is how to find the branch's violations:

```bash
git diff origin/main...HEAD -- '*.en.yml' 'config/locales/en.yml' | grep -in '^+[^+].*bike'
git diff origin/main...HEAD -- '*.rb' | grep -in '^+[^+].*errors\.add.*bike'
```

The second one is load-bearing: a model's `errors.add(:base, "…")` reaches a flash through `full_messages`, never passing a locale file, so the YAML grep can't see it. `Sale#seller_is_owner` interpolates the cycle type into one.

Read each hit. Key names (`about_this_bike:`), the product name ("Bike Index"), and copy that really is bike-only are fine; a value saying "bike" about the registration is not. `Pages::Registrations::Show::CurrentAlerts::ClaimImpound` and `Pages::Registrations::Show::WrapperConsumer` are the pattern for fixing one, and `spec/components/pages/registrations/show/current_alerts/claim_impound/component_spec.rb` shows how to cover it.

## The product-name check

Copy spells the products "Bike Index" and "Bike Book" — never "BikeIndex", "Bike index", "BikeBook", "Bike book" or "Bikebook":

```bash
git diff origin/main...HEAD -- '*.yml' '*.erb' '*.haml' '*.rb' '*.js' '*.md' |
  grep -nE '^\+[^+].*(BikeIndex|[Bb]ike index|BikeBook|Bike book|Bikebook)'
```

Fix every hit in copy. Code identifiers (`BikeIndexFormBuilder`, `BikeBookUpdateJob`, `Bikebook::`, `bikebook_path`) and the `BikeIndex.org` domain are fine.

## If a command comes back empty

**The commands are plain `git`, so they run with or without rtk.** rtk 1.0.1 passes a piped `git diff` or `git log` through unchanged; an older rtk summarized a `git diff`, added a `Changes:` line to `--name-only` and dropped merges from `git log`. If a grep or count comes back empty on a branch that plainly has matches, `rtk --version` — below 1.0.1, prefix the command with `rtk proxy`.

## The reply

One line per audit that ran: its verdict and what it changed, or "nothing" — the backfill verdict naming the stored values checked, the markup audit's conversions and callouts in full. The marketing page audit gets a line per numbered check. Then any finding you left for the user, like a component to fold into a `UI::*` argument, and every set of repeated text from the marketing page audit. Leave the fixes uncommitted; the caller commits them.
