# Local macOS (Conductor workspace or spawned worktree)

In a `.claude/worktrees/…` checkout, `bin/workspace_setup --without_seeds` comes first
(SKILL.md).

Ruby comes from [mise](https://mise.jdx.dev/), but Claude Code's shell sometimes spawns
subprocesses without its shims on PATH, so bare `ruby` is `/usr/bin/ruby` (2.6). **Ruby
is installed; PATH is wrong** — don't reinstall or edit the Gemfile. It shows up as:

- `Could not find 'bundler' (4.0.x)` from `bundle`, or from a `bin/` script that boots Rails
- `uninitialized constant Pathname` or `undefined method 'intersect?' for Array` from a
  `bin/` script (`bin/rspec`, `bin/lint`)

```bash
ruby -v   # not the .tool-versions pin? then:
export PATH="$HOME/.local/share/mise/shims:$PATH"
```

Use the shims (they follow `.tool-versions`), not `mise exec`, which can still resolve
to 2.6 here. Then `bundle exec rspec …` and `bin/lint` work normally.

No `eval "$(ruby bin/env --export)"` needed for Ruby commands — `config/boot.rb` loads
`bin/env` itself. Export it only when the shell reads the values (`curl "$BASE_URL"`).

A pending-migration abort from `rails_helper` → `bundle exec rails db:create db:migrate`.

Postgres, redis and the network are your local environment's, so the only other thing
that bites here is the CSS build in SKILL.md.
