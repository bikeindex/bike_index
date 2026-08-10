---
name: fixing-flaky-failures
description: >-
  How to fix a test that fails intermittently in Bike Index — one that passes
  locally but fails on CI, fails on one shard, passes on re-run, or is already
  tagged `:flaky`. **Read this before touching any spec that is failing
  intermittently, and before adding, raising, or relying on a `flaky:` tag or a
  `wait:` bump.** Trigger on a CI failure the user calls flaky, unreliable,
  intermittent, "green locally", "passes on retry", "fix CI", or a pasted
  `gh run`/Actions URL whose failure isn't reproducible; also whenever you catch
  yourself about to delete, skip, loosen, or retry an assertion to make a red
  build go green. Covers diagnosing the real mechanism, this repo's `flaky:`
  retry harness, and the known false-flake causes (missing Tailwind build, shared
  Redis autocomplete cache, Turbo frame timing, probe-run interference).
---

# Fixing flaky failures

## The rule that overrides everything else here

**You may not reduce test coverage to make a flaky test pass.** Not as a last
resort, not "temporarily", not when the coverage looks redundant, not when you
have already decided the failing step is a harness artifact rather than a real
bug.

All of these are reducing coverage, and none of them is a fix:

- Deleting an assertion, a step, a helper call, or a whole example.
- Loosening a matcher so it can't fail (`have_css(count: 2)` → `have_css`,
  an exact string → a regex, `have_no_content` → nothing).
- Adding `:flaky`, or raising an existing `flaky: N` to a bigger N.
- Bumping `wait:` when you don't have a specific reason to believe the thing
  being waited on legitimately takes that long.
- `skip`/`pending`/`xit`, or excluding the spec from a CI shard.

A flaky test is a *reporting* problem — the suite is telling you something real
and telling you unreliably. Every item above changes the reporting and leaves
the underlying behaviour untested, which is strictly worse than the flake: a
flake wastes your time, silently-missing coverage wastes an incident.

The two legitimate outcomes are: **fix the cause**, or **leave it failing and
say so**. If the only fix you can see requires giving up coverage, that is a
decision for the user — describe what you'd have to give up and ask. Do not
make that trade yourself and mention it in the summary afterwards; announcing a
scope reduction is not the same as getting agreement for it.

The one exception that isn't an exception: if the assertion is *wrong* — it
asserts behaviour the app never promised — then fixing it is correcting a bad
test, not reducing coverage. Say explicitly why it was wrong.

## Diagnose before you touch anything

### 1. Get the real failure, not the summary

```bash
gh run view <run-id> --repo bikeindex/bike_index --json jobs \
  --jq '.jobs[] | "\(.databaseId) \(.name) \(.conclusion)"'
gh run view --repo bikeindex/bike_index --job <job-id> --log-failed
```

The log is large and ANSI-coloured; pipe through `sed 's/\x1b\[[0-9;]*m//g'`
and grep for `Failure/Error`, `expected`, and `rspec ./spec/...` to get the
failing example ids and the actual message.

### 2. Read the message literally

The exact failure text usually names the mechanism, and it is easy to skim past
into a wrong assumption. Worked example from this repo: `expected nil to match
/\/bikes\/\d+/` was long assumed to mean "the click was lost". It doesn't —
Capybara returns a nil `current_path` **only** for an `about:` scheme
(`capybara/session.rb`: `return nil if uri&.scheme == 'about'`), so the browser
was on `about:blank` and the page had gone away. Different cause, different fix.
Check the matcher's source when a message is surprising.

### 3. Try to reproduce, and treat failure-to-reproduce as information

```bash
for i in 1 2 3; do bundle exec rspec <the spec file> 2>&1 | grep -E "examples, " | tail -1; done
```

Green locally three times doesn't mean "not reproducible, add a retry". It
narrows the cause to something CI has and you don't: **contention** (CI runs 5
parallel shards on one runner) or **ordering** (a different seed, or state left
by another example). Reason about which, then look for the mechanism.

Caveat when measuring locally: after a heavy record-creating run (seeding,
probe scripts, a big suite), `:js` specs fail spuriously for a while. Re-measure
in a quiet environment before concluding a spec is flaky.

## Known causes in this repo

Work through these before inventing a new theory — most flakes here are one of
them, and several look like timing but aren't.

**Not actually flaky — the environment is wrong.** A missing
`app/assets/builds/tailwind.css` makes `tw:hidden` silently not apply, so
visibility assertions fail in ways that read as flakes. See the
[`integration-testing`](../integration-testing/SKILL.md) skill's Tailwind
section. Same class of thing: an unmigrated test DB, a stale VCR cassette.

**Shared state across examples.** The autocomplete cache (`autc:test:*`) lives
in a Redis DB shared across `:js` examples and survives 600s, and `load_all`
never invalidates it — so a stale entry from an earlier spec changes what a
combobox returns. The fix is `Autocomplete::Loader.clear_redis` in `before`,
not a retry. Browser history is the same shape: `reset_browser_history`
(`spec/support/system_spec_helpers.rb`) drops entries earlier examples left, so
`go_back`/`go_forward` walk this example's own stack.

**Clicking something that is being re-rendered.** The dominant `:js` flake.
A Turbo frame that reloads (an eager frame, `reloadFrameIfUrlStale` on
`turbo:load`, a broadcast morph) detaches the element mid-click, and the click
lands nowhere. Fix it by waiting for the settled state the user would wait for,
then clicking:

```ruby
expect(page).to have_css("turbo-frame#results_frame[complete]:not([busy])", wait: 10)
retry_on_detach { first(".bike-box-item .title-link a").click }
```

`retry_on_detach` (`spec/support/system_spec_helpers.rb`) rescues the raw
`Playwright::Error` for a detached node, which Capybara's own retry does not.
This is *not* a coverage reduction: the assertions are untouched, the click just
happens on a DOM that has stopped moving.

**Programmatic back/forward.** Playwright drives these specs and there is no
BFCache, so `go_back`/`go_forward` onto a `turbo-action: advance` entry is
genuinely unreliable. Prefer not to chain a real navigation onto the tail of a
back/forward sequence. If a spec must, expect to need the settle-then-click
pattern above.

**A wait that starts before the work does.** Occasionally a bump is honest: if
the assertion begins before the request is even sent (a held route released, a
job enqueued) and the response is expensive, the budget was simply wrong. Say
so in a comment naming what the wait covers — that's what distinguishes it from
papering over a race.

## What a finished fix looks like

- Every assertion that existed before still exists.
- The change names a mechanism ("the frame reloads on `turbo:load` and detaches
  the link"), not a symptom ("this is flaky on CI").
- You can explain why the fix addresses that mechanism, even though you probably
  can't reproduce the original failure locally.
- Comments describing the flake are corrected if your diagnosis contradicts
  them — a wrong comment sends the next person down the same wrong path.
- You say plainly that CI is the only real verification, rather than implying
  local green proves it.

## Working on an already-tagged spec

`flaky:` retries only run on CI (`RETRY_FLAKY`, see `spec/rails_helper.rb`).
`flaky: true` retries twice; `flaky: <n>` overrides the count. Two things follow:

- An example that fails through all its retries is telling you the cause is
  structural, not random. More retries will not help — that's the signal to go
  find the mechanism.
- Local runs don't retry, so a `flaky:`-tagged spec failing once locally is not
  automatically "the known flake".

Removing a now-unnecessary `flaky:` tag after you've fixed the cause is good
housekeeping — that direction adds signal rather than removing it.
