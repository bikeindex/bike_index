# Local macOS (Conductor workspace)

Ruby 4.0.6 is installed via [mise](https://mise.jdx.dev/), but Claude
Code's shell sometimes spawns subprocesses without the mise shim on
PATH — bare `ruby` then resolves to `/usr/bin/ruby` (2.6). **The Ruby is
installed; the PATH just isn't right** — don't reinstall, don't edit
the Gemfile. It surfaces differently depending on the entry point:

- `bundle` / `bundle exec` → `Could not find 'bundler' (4.0.x)`
- a `bin/` script (`bin/rspec`, `bin/lint`) → `uninitialized constant Pathname`

Check first; only prefix PATH if `ruby -v` doesn't already print 4.0.6
(`mise exec -- ruby`/`bundle` are unreliable in this harness — they
can still resolve to system 2.6, so use the direct prefix):

```bash
ruby -v
# If it's not 4.0.6:
export PATH="$HOME/.local/share/mise/shims:$PATH"
```

The shims directory rather than an `installs/ruby/<version>/bin` path:
it resolves through `mise.toml`, so it doesn't go stale at the next Ruby
bump, and it covers Node too.

Then run specs the normal way:

```bash
bundle exec rspec spec/path/to/file_spec.rb
```

(No need to `eval "$(ruby bin/env --export)"` first — `config/boot.rb` loads
`bin/env` for every Ruby entry point, so `WORKSPACE_ID` / `DEV_PORT` /
`BASE_URL` / `REDIS_URL` are already set inside the process. Only export
them into the shell when the shell itself reads them, e.g. `curl "$BASE_URL/..."`.)

If `rails_helper` aborts complaining about a pending migration, run
`bundle exec rails db:create db:migrate` first
(`ActiveRecord::Migration.maintain_test_schema!`).

`bin/turbo_tests` (and so `bin/ci`) runs each worker against its own
`bikeindex_test_<WORKSPACE_ID>` database, which nothing creates on
demand — a fresh workspace fails with `ActiveRecord::NoDatabaseError:
Database not found`. `bin/rake parallel:prepare` creates them, and
`bin/ci` runs it as its own step.

Lint with `bin/lint` (same PATH prefix if needed). Postgres, redis,
and the jsdelivr proxy are handled by your local dev environment, so
nothing else here applies **except** the Tailwind build in SKILL.md,
which can still bite a fresh Conductor workspace where `bin/dev`
hasn't run.
