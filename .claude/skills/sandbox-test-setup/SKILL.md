---
name: sandbox-test-setup
description: >-
  Bike Index Ruby + RSpec environment setup, for the environments this repo actually
  runs in: a local macOS Conductor workspace, a spawned `.claude/worktrees/…` git
  worktree, the Conductor cloud sandbox, and Claude Code's Linux web sandbox.
  Identifies which one you're in by path and points at its reference; each covers
  getting `ruby`, `bundle`, `bin/lint`, a database and a browser working there.
  **Read it before the first command in a spawned worktree** — that one starts with
  `bin/workspace_setup`, without which `bin/env` hands back the main checkout's port,
  database and Redis. Read it whenever a session runs RSpec,
  `bundle` or `bin/lint`, needs a running dev server, or hits any of these:
  a missing `.workspace_id` or `node_modules`, a `$BASE_URL` serving another branch,
  `env: 'ruby': No such file or directory`, `Could not find 'bundler' (4.0.x)`, `command not found: rspec`,
  `uninitialized constant Pathname` or `undefined method 'intersect?' for Array` from a `bin/` script,
  `Sprockets::Rails::Helper::AssetNotFound`, `tailwind.css is not present`,
  `LoadError: Could not open library 'vips.so.42'`, or a Playwright
  browser-not-found or build-number mismatch. The fix is almost never a reinstall
  or a Gemfile edit — it's a PATH, an env var, or a service that isn't running.
---

# Running Ruby + RSpec for Bike Index

Environments are told apart by the path you're working in. Read the one that
matches; the others won't apply and are the bulk of the material.

| Path | Environment | Read |
| --- | --- | --- |
| `/Users/…/conductor/workspaces/…` | local macOS Conductor workspace | `references/local-macos.md` |
| `…/.claude/worktrees/…` | spawned git worktree — set it up first, below | `references/local-macos.md` |
| `/home/vercel-sandbox/workspace` (Amazon Linux 2023) | Conductor cloud sandbox | `references/conductor-cloud.md` |
| `/home/user/bike_index` | Claude Code web sandbox | `references/web-sandbox.md` |

## A spawned worktree sets itself up first

In a `.claude/worktrees/…` checkout this comes before the first `rspec`, `bundle`,
`bin/lint`, `bin/env` or dev server:

```bash
bin/workspace_setup --without_seeds
```

It allocates the ID from the `dev_workspaces` registry, writes `.workspace_id`, then
runs `bin/setup` — which symlinks `node_modules` and `storage` from the root checkout
and creates this workspace's databases. `--without_seeds` is what Conductor's initial
setup passes; `bundle exec rails db:seed` when you need records (AGENTS.md).

**Never write `.workspace_id` yourself.** `bin/workspace_setup` skips allocation when
the file already exists, leaving the checkout on an ID the registry never handed out.

Skip the setup entirely and `bin/env` falls through to `DEV_PORT=3042` and Redis db 0 —
the *main checkout's* port, database and cache. Nothing errors; `$BASE_URL` just serves
another branch, and `bin/setup` run from there would load the schema over the
production-derived `bikeindex_development`.

Two things hold everywhere.

## Tailwind build (every environment)

The application layout calls `stylesheet_link_tag 'tailwind'`. Without
`app/assets/builds/tailwind.css`, specs that render the layout (request
specs hitting `format: :html`, or any `:js, type: :system` spec) fail
with `Sprockets::Rails::Helper::AssetNotFound`. This applies to both
the sandboxes AND a fresh Conductor workspace where `bin/dev` /
`tailwindcss:build` haven't run yet. **Don't write the failure off as
"pre-existing" — build Tailwind:**

```bash
bundle exec rails tailwindcss:build
```

(See the `integration-testing` skill — same rule applies to
layout-rendering request specs, not just system specs.)

## A `:js` spec runs precompiled JS when `public/assets` exists

`public/assets/.sprockets-manifest.json` — left behind by any `bin/turbo_tests` or
`bin/rails assets:precompile` run — is what the test environment resolves
`controllers/**/*.js` through, so a Stimulus controller you just edited is
served at whatever digest that manifest names. **The spec then exercises the
old JavaScript and fails as if the change were wrong**, while the same page in
`bin/dev` (which compiles live) behaves correctly.

That split — works in the browser, fails under `rspec` — is the tell. Confirm
before debugging the code:

```bash
grep -o "controllers/shared_blocks/[a-z_]*controller[^\"]*" public/assets/.sprockets-manifest.json | head
```

Then delete `public/assets` — `rm -rf public/assets`, no need to ask. It's
gitignored, and neither `bin/dev` nor the test environment needs it: both compile
live without it.

## Whose machine it is decides who starts `bin/dev`

`AGENTS.md` says to stop and ask rather than starting a dev server. That holds on
the two environments a human owns — the macOS workspace and the Conductor cloud
sandbox. The web sandbox is the exception, since nobody else is in that container;
`references/web-sandbox.md` covers starting it there.
