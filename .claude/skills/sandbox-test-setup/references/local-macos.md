# Local macOS (Conductor workspace or spawned worktree)

In a `.claude/worktrees/…` checkout, `bin/workspace_setup --without_seeds` comes first
(SKILL.md).

Ruby comes from [mise](https://mise.jdx.dev/). macOS's `path_helper` puts `/usr/bin` ahead
of its shims in every non-interactive shell, so the `mise-shims.sh` SessionStart hook
re-prepends them for each Bash command, subagents' included. A shell that rebuilds PATH
still gets `/usr/bin/ruby` (2.6).
**Ruby is installed; PATH is wrong** — don't reinstall or edit the Gemfile. It shows up as:

- `Could not find 'bundler' (4.0.x)` from `bundle`, or from a `bin/` script that boots Rails
- `uninitialized constant Pathname` or `undefined method 'intersect?' for Array` from a
  `bin/` script (`bin/rspec`, `bin/lint`)
- a `syntax error` from bare `ruby -c`/`ruby -e` on an endless `def` or `{x:}` shorthand

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
