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
  build go green. **Equally: any spec that fails intermittently while you verify
  your own work** — deciding whether your change caused a flake, or whether to
  ship past one, is this skill's problem too, and it arrives with no CI run, no
  `:flaky` tag, and nobody but you calling it flaky.
---

# Fixing flaky failures

Covers diagnosing the real mechanism, attributing a flake to a change, this
repo's `flaky:` retry harness, and the known false-flake causes — a missing
Tailwind build, the shared Redis autocomplete cache, Turbo frame timing,
probe-run interference.

## The rule that overrides everything else here

**You may not reduce test coverage to make a flaky test pass.** Not as a last
resort, not "temporarily", not when the coverage looks redundant, not when you
have already decided the failing step is a harness artifact rather than a real
bug.

All of these are reducing coverage, and none of them is a fix:

- Deleting an assertion, a step, a helper call, or a whole example.
- Loosening a matcher so it can't fail (`have_css(count: 2)` → `have_css`,
  an exact string → a regex, `have_no_content` → nothing).
- `skip`/`pending`/`xit`, or excluding the spec from a CI shard.

A flaky test is a *reporting* problem — the suite is telling you something real
and telling you unreliably. Every item above changes the reporting and leaves
the underlying behaviour untested, which is strictly worse than the flake: a
flake wastes your time, silently-missing coverage wastes an incident.

If the only fix you can see requires giving up coverage, that is a decision for
the user — describe what you'd have to give up and ask. Do not make that trade
yourself and mention it in the summary afterwards; announcing a scope reduction
is not the same as getting agreement for it.

The one exception that isn't an exception: if the assertion is *wrong* — it
asserts behaviour the app never promised — then fixing it is correcting a bad
test, not reducing coverage. Say explicitly why it was wrong.

## Retries and longer waits: allowed, but earn them first

`:flaky` (and raising an existing `flaky: N`) and a bigger `wait:` are a
different category from the list above, because they keep every assertion and
still require it to pass. Nothing goes untested. They're a legitimate last
resort — reach for them when the diagnosis below has genuinely run out, not as
the first thing you try.

What "earn them" means in practice:

- Diagnose first. Instrument, read the failure literally, check the known causes
  below. Most flakes here have a mechanism you can find in one focused pass, and
  a retry over a findable cause just makes it intermittent for longer.
- Leave a comment saying what you found and why the retry stands in for a fix —
  the harness artifact, the contention, the thing you ruled out. The existing
  `flaky: 4` on `search_registrations_spec` is the pattern: it names WebDriver's
  unreliable `go_forward` onto a `turbo-action: advance` entry and explains why
  more retries than the default. A bare `flaky: true` with no comment tells the
  next person nothing and will outlive the problem.
- Say plainly in your summary that you papered over it rather than fixed it, so
  the user can decide whether that's good enough.

Two signals that a retry is the *wrong* answer even as a last resort: an example
that fails through all its retries (the cause is structural, and a bigger N won't
help), and a wait you can't say what it's waiting for. A bump is honest when the
assertion starts before the work does — a held route released, a job enqueued,
an expensive response — and the comment names that.

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

### 3. Instrument rather than theorise

When you can't reproduce, you can still make the browser tell you what happened.
Copy the spec to a scratch file, record the events the app actually emits, and
run it — a log beats an argument, and this routinely overturns the theory you
were about to ship:

```ruby
page.execute_script(<<~JS)
  window.__events = []
  const stamp = (name, extra) => window.__events.push(Object.assign({name, t: Math.round(performance.now())}, extra))
  document.addEventListener("turbo:before-fetch-response", (e) => {
    stamp("response", {target: e.target?.id, url: e.detail?.fetchResponse?.response?.url, prevented: e.defaultPrevented})
  })
JS
# ...drive the spec...
# A file, not puts - rtk's rspec wrapper reports a summary and drops the run's stdout
File.open("tmp/probe.log", "a") { |f| page.evaluate_script("window.__events").each { |e| f.puts e.inspect } }
```

Parameterise the scratch spec over the variable you suspect (`[0, 8].each do |delay|`
around an injected `sleep`) so one run compares the fast and slow paths. Delete the
scratch file when you're done. Two things this buys that reasoning doesn't: it
distinguishes "the event never arrived" from "the event arrived and the assertion
misread it", and it tells you *when* things happened, which is usually the answer.

### 4. Try to reproduce, and treat failure-to-reproduce as information

```bash
for i in 1 2 3; do bundle exec rspec <the spec file> 2>&1 | grep -E "examples, " | tail -1; done
```

Green locally three times doesn't mean "not reproducible, add a retry". It
narrows the cause to something CI has and you don't: **contention** (CI runs 5
parallel shards on one runner) or **ordering** (a different seed, or state left
by another example). Reason about which, then look for the mechanism.

For contention, slow the renderer rather than the machine — CPU hogs slow the Ruby
side too, so a loop of runs takes minutes and the extra load is spent where the race
isn't. CDP throttles the browser alone, and the driver hands you a session:

```ruby
page.driver.with_playwright_page do |playwright_page|
  session = playwright_page.context.new_cdp_session(playwright_page)
  session.send_message("Emulation.setCPUThrottlingRate", params: {rate: 6})
end
```

A rate that leaves the spec green over ~20 runs is evidence, not proof: it stretches
main-thread work, not the network or a parallel shard's I/O.

Which is why it can't reach a race about *when a response arrives*. The common one here
is a lazily loaded Stimulus controller, since the module is a fetch — hold it on the
route and the late connect is deterministic, no loop:

```ruby
playwright_page.route(%r{serial_controller}, ->(route, request) { held << request.url; sleep 1; route.continue })
```

Registering a route disables the http cache, so the reload asks again. Assert on what
the handler held: a route that stops matching (a moved asset path) otherwise leaves the
example green on a page that held nothing back. Measured against `register--serial`'s
connect-time reconcile, throttling at 6, 12 and 25 left it green over 30+ runs; the
route hold failed it every time.

Caveat when measuring locally: after a heavy record-creating run (seeding,
probe scripts, a big suite), `:js` specs fail spuriously for a while. Re-measure
in a quiet environment before concluding a spec is flaky.

### 5. Blaming your own change needs both arms measured together

"Is this spec flaky?" and "did my change make it flaky?" are different questions.
The second one is where sequential sampling lies to you: local load drifts — a
browser left open, another suite, the machine waking up — so a sample taken now
and one taken an hour ago aren't comparable, and whichever arm ran while things
were busy looks guilty.

Revert *only* the suspect change and run both arms the same number of times, back
to back, then compare. Measured that way here, a patch blamed for `:js` failures
on sequential samples (0 failures in 9 clean runs against 5 in 13 patched ones)
came out at 2/6 versus the baseline's 1/6 — indistinguishable, and the spec was
flaky on its own. Sample sizes this small can't separate a 17% failure rate from
a 7% one, so treat a handful of green runs as weak evidence in either direction.

Ruling ordering out is cheap and worth doing first: RSpec prints `Randomized with
seed N`, and `--seed N` replays that order. A failing seed that passes on replay
leaves timing, not ordering or leaked state.

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

**Interacting with a page whose controllers haven't connected.** `application.js`
lazy loads every Stimulus controller, so a freshly rendered page answers to none of
them until each module lands: a combobox filters nothing, a one-shot event (like
form-persist's restore) reaches no listener, and a `fill_in`'s text can end up in
whatever autofocus left focused. Waiting on any one controller proves nothing about
the rest — `wait_for_stimulus` (`spec/support/system_spec_helpers.rb`) waits for
every identifier the page names.

**Interacting before the legacy page script has bound.** The same shape, one era
back: `init.coffee`'s `loadPageScript` constructs the per-page class in
`$(document).ready`, while `click_link` returns with the new document still
parsing — so an interaction landing between the two is swallowed with nothing on
the page to say so. `wait_for_page_script`
(`spec/support/system_spec_helpers.rb`) waits on `window.pageScript`; reach for
it after any navigation into a jQuery-driven control.

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

**A probe that measures itself instead of the app.** When a spec observes
behaviour by listening for an event, check whether what it reads is a property of
the app or of the listener's position. `event.defaultPrevented` read *inside* a
`document` listener only reflects `preventDefault` calls from listeners that
already ran, so it reports registration order as much as the app's verdict.
Measured in this repo, same event, same run: read in the listener `false`, read on
the next tick `true`. Defer the read so every listener has had its turn:

```js
document.addEventListener("turbo:before-fetch-response", (event) => {
  if (event.target?.id !== "results_frame") return
  // Next tick: the verdict no longer depends on where this sits in the order
  setTimeout(() => { document.body.dataset.testRejected = event.defaultPrevented ? "true" : "false" })
})
```

Order is easy to invert without noticing, because the two sides have different
lifetimes: `document` listeners survive a Turbo Drive body swap, while Stimulus
controllers disconnect and re-add theirs at the *end* of the list on reconnect. So
a probe registered before a Turbo visit ends up ahead of the controller it's
watching. Two habits that keep this class of bug visible: record the verdict for
both outcomes (`"true"`/`"false"`) rather than only writing the marker on success,
so a wrong verdict fails loudly instead of timing out as if the event never
arrived; and prefer asserting the user-visible consequence alongside the internal
verdict.

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
- Or — where you fell back to a retry or a longer wait — you say so as the
  headline rather than the footnote, and the comment in the spec records what you
  ruled out, so the next person starts where you stopped.
- Comments describing the flake are corrected if your diagnosis contradicts
  them — a wrong comment sends the next person down the same wrong path.
- You say plainly that CI is the only real verification, rather than implying
  local green proves it.

## Working on an already-tagged spec

`flaky:` retries only run on CI (`RETRY_FLAKY`, see `spec/rails_helper.rb`).
`flaky: true` retries twice; `flaky: <n>` overrides the count. So local runs
don't retry, and a `flaky:`-tagged spec failing once locally is not
automatically "the known flake" — it may be a plain reproducible failure that
the tag has been hiding on CI.

Removing a now-unnecessary `flaky:` tag after you've fixed the cause is good
housekeeping — that direction adds signal rather than removing it.
