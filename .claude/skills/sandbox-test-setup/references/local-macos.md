# Local macOS (Conductor workspace)

Ruby 4.0.6 is installed via [mise](https://mise.jdx.dev/), but Claude
Code's shell sometimes spawns subprocesses without the mise shim on
PATH — bare `ruby` then resolves to `/usr/bin/ruby` (2.6) and `bundle`
fails with `Could not find 'bundler' (4.0.0.beta2)`. **The Ruby is
installed; the PATH just isn't right** — don't reinstall, don't edit
the Gemfile.

Check first; only prefix PATH if `ruby -v` doesn't already print 4.0.6
(`mise exec -- ruby`/`bundle` are unreliable in this harness — they
can still resolve to system 2.6, so use the direct prefix):

```bash
ruby -v
# If it's not 4.0.6:
export PATH="/Users/seth/.local/share/mise/installs/ruby/4.0.6/bin:$PATH"
```

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

Lint with `bin/lint` (same PATH prefix if needed). Postgres, redis,
and the jsdelivr proxy are handled by your local dev environment, so
nothing else here applies **except** the Tailwind build in SKILL.md,
which can still bite a fresh Conductor workspace where `bin/dev`
hasn't run.
