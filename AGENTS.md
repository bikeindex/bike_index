Bike Index is a Rails webapp

[mise](https://mise.jdx.dev/) is used for Ruby and Node version management.

# Development

Run `eval "$(ruby bin/env --export)"` once so `$DEV_PORT` (and `$BASE_URL`, `$REDIS_URL`) are set with the right WORKSPACE_ID fallback.

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
- Keep comments pithy — often they aren't necessary. Explain *why* only where a reader would otherwise get it wrong; don't narrate the change that introduced the code, and don't defend a choice against an edit nobody would make — a failing test already defends it
- **Prefer composition over inheritance and `include`.** Share behavior by calling an object that owns it, not by mixing a module into several classes or adding a base class. A `module` extracted only to be `include`d in two classes is usually one of those classes with a parameter — pass the difference in as an argument instead. Rails' own extension points (`ApplicationRecord`, `ApplicationJob`, `ActiveSupport::Concern` for controller filters) are fine; new mixins of our own are what to avoid.
- **Service objects** (`app/services/`): a stateless service is a `module` with `extend Functionable` (see the `functionable` gem) — inputs passed as args, no instance state, private methods via `conceal` + a `# private below here` block. Don't write a stateless service as a `class` with `def self.` methods.

## Subagents

When a command fans out to subagents — `/simplify`, `/code-review`, or an ad-hoc fan-out — pick the model by how much of the *search* the agent has to invent, not by how simple the task sounds:

- **`model: "haiku"`** when the command is already specified: "run this grep and summarise it", "read these four files and pull out X". There's nothing to devise.
- **`model: "sonnet"`** when the agent has to work out *how* to look ("every call site of X", "which specs touch Y"). A weaker model compensates by flailing — on a real enumeration here it reached the same answer as sonnet, but took 3x the tool calls, 1.6x the wall clock and more total tokens, so the per-token discount didn't survive.
- **Omit `model:`** (inherit the session model) for judgement — the passes that catch an unvalidated param landing in a fragment cache key, or a shared partial's N+1.

Worth delegating enumeration at all rather than eyeballing a grep: in that same test both subagents found two call sites the hand-written grep missed, because it anchored on the wrong method name.

## Testing

Uses RSpec. All business logic should be tested. The `rspec-testing` skill covers project-specific style (`context`+`let`, request specs over controller specs, avoiding mocks).

## Frontend Development

Uses Stimulus.js for JavaScript and Tailwind CSS for styling. SCSS and CoffeeScript files exist but are deprecated. The `bin/dev` command handles Tailwind and JS builds. The `frontend-conventions` skill covers project-specific class prefixes (`tw:`, `twinput`, `twlabel`, `twlink`), the `number_display` helper, and ViewComponent rules.

Check whether the dev server is up: `curl -fs "$BASE_URL/" >/dev/null`. If it isn't, **stop and ask the user to start it** so Tailwind and JS asset watchers are running before any frontend work.

## Pull requests

- When creating a PR, run the `/pr` workflow rather than calling `gh pr create` directly — `/pr` detects frontend diffs, captures desktop+mobile screenshots, and embeds them in the PR body.
- To attach a local image (screenshot, .png/.jpg, CleanShot capture) to an existing GitHub PR, the `gh` CLI **cannot upload images** — use the `github-upload-image-to-pr` skill, which drives a real browser to GitHub's user-attachments uploader.

## Architecture notes

- **Multi-database**: primary (`ApplicationRecord`) + analytics (`AnalyticsRecord`). Use `db:migrate:down:analytics` for analytics migrations
- **Soft delete**: some models use `acts_as_paranoid` with `deleted_at` column; use `unscoped` in admin controllers when needed
- **Admin search**: `sortable_search_params` auto-includes any param starting with `search_`

# Initial setup

```bash
bundle install # install ruby dependencies
bundle exec rails db:create db:migrate # create the databases
```
