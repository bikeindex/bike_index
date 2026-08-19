---
name: sandbox-test-setup
description: >-
  Bike Index Ruby + RSpec environment setup, for the three environments this repo
  actually runs in: a local macOS Conductor workspace, the Conductor cloud sandbox,
  and Claude Code's Linux web sandbox. Identifies which one you're in by path and
  points at its reference; each covers getting `ruby`, `bundle`, `bin/lint`, a
  database and a browser working there. Read it whenever a session runs RSpec,
  `bundle` or `bin/lint`, needs a running dev server, or hits any of these:
  `env: 'ruby': No such file or directory`, `Could not find 'bundler' (4.0.0.beta2)`,
  `Bundler::RubyVersionMismatch`, `command not found: rspec`,
  `uninitialized constant Pathname` from a `bin/` script,
  `Sprockets::Rails::Helper::AssetNotFound`, `tailwind.css is not present`,
  `LoadError: Could not open library 'vips.so.42'`, or a Playwright
  browser-not-found or build-number mismatch. The fix is almost never a reinstall
  or a Gemfile edit — it's a PATH, an env var, or a service that isn't running.
---

# Running Ruby + RSpec for Bike Index

Three environments, told apart by the path you're working in. Read the one that
matches; the other two won't apply and are the bulk of the material.

| Path | Environment | Read |
| --- | --- | --- |
| `/Users/…/conductor/workspaces/…` | local macOS Conductor workspace | `references/local-macos.md` |
| `/home/vercel-sandbox/workspace` (Amazon Linux 2023) | Conductor cloud sandbox | `references/conductor-cloud.md` |
| `/home/user/bike_index` | Claude Code web sandbox | `references/web-sandbox.md` |

What separates them is how much is missing, and that's worth knowing before you
start debugging. On macOS the Ruby is installed and only the PATH is wrong. In the
Conductor cloud sandbox nothing is preinstalled but egress is open, so mise builds
the pinned Ruby in a couple of minutes. In the web sandbox egress is filtered too,
so Ruby comes from a GitHub source build and several tools have to be pointed at
what the image already ships.

Two things hold in all three.

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

## Whose machine it is decides who starts `bin/dev`

`CLAUDE.md` says to stop and ask rather than starting a dev server. That holds on
the two environments a human owns — the macOS workspace and the Conductor cloud
sandbox. The web sandbox is the exception, since nobody else is in that container;
`references/web-sandbox.md` covers starting it there.
