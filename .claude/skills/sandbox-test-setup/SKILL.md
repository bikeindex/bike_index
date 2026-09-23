---
name: sandbox-test-setup
description: >-
  Bike Index Ruby + RSpec environment setup for each place this repo runs: a local
  macOS Conductor workspace, a spawned `.claude/worktrees/…` git worktree, and Claude
  Code's Linux web sandbox — getting `ruby`, `bundle`, `bin/lint`, a database, seeds, a
  dev server and a browser working there.
  **Read it before the first command in a spawned worktree**, which starts with
  `bin/workspace_setup` (without it `bin/env` hands back the main checkout's port,
  database and Redis). Read it whenever a session runs RSpec, `bundle` or `bin/lint`,
  needs a dev server or seeded data, or hits: a missing `.workspace_id` or
  `node_modules`, a `$BASE_URL` serving another branch, `Could not find 'bundler'
  (4.0.x)`, `command not found: rspec`, `uninitialized constant Pathname` or `undefined method 'intersect?' for Array` from a
  `bin/` script, `Sprockets::Rails::Helper::AssetNotFound`, `tailwind.css is not
  present`, `LoadError: Could not open library 'vips.so.42'`, `executable not found:
  "identify"`, or a Playwright browser-not-found, build-number mismatch or `Running as
  root without --no-sandbox is not supported`. The fix is almost never a reinstall or a
  Gemfile edit — it's a PATH, an env var, or a service that isn't running.
---

# Running Ruby + RSpec for Bike Index

Read the reference for the path you're in; the others don't apply.

| Path | Environment | Read |
| --- | --- | --- |
| `/Users/…/conductor/workspaces/…` | local macOS Conductor workspace | `references/local-macos.md` |
| `…/.claude/worktrees/…` | spawned git worktree — set it up first, below | `references/local-macos.md` |
| `/home/user/bike_index` | Claude Code web sandbox | `references/web-sandbox.md` |

## A spawned worktree sets itself up first

Before the first `rspec`, `bundle`, `bin/lint`, `bin/env` or dev server:

```bash
bin/workspace_setup --without_seeds
```

It allocates an ID from the `dev_workspaces` registry, writes `.workspace_id`, and runs
`bin/setup`, which creates this workspace's databases. Run `bundle exec rails db:seed`
when you need records. Expect a full `npm install`.

**Never write `.workspace_id` yourself** — `bin/workspace_setup` then skips allocation,
leaving an ID the registry never handed out. And skipping setup entirely silently falls
back to `DEV_PORT=3042` and Redis db 0: the main checkout's port, database and cache —
and a `bin/setup` from there loads the schema over the main checkout's database.

## Build the CSS (every environment)

`AssetNotFound` from any spec that renders the layout (an html request spec, any `:js`
spec) means `app/assets/builds/tailwind.css` is missing — a fresh workspace where
`bin/dev` hasn't run. It isn't pre-existing; build it. `The asset "email.css" is not
present` (anything rendering an email, including `db:seed`) is the SCSS half:

```bash
bundle exec rails tailwindcss:build dartsass:build
```

## A stale `public/assets` shadows your JavaScript

Any `bin/turbo_tests` or `assets:precompile` run leaves `public/assets/.sprockets-manifest.json`,
and the test environment serves `controllers/**/*.js` from it. So a `:js` spec runs the
*old* Stimulus controller and fails as if your change were wrong, while `bin/dev` works.
Confirm, then `rm -rf public/assets` (gitignored, no need to ask):

```bash
grep -o "controllers/[a-z_/]*controller[^\"]*" public/assets/.sprockets-manifest.json | head
```

## Who starts `bin/dev`

Where a human works — a Conductor workspace, the main checkout — ask (AGENTS.md). In a
spawned worktree or the web sandbox, the checkout is yours: start it yourself.
