# Conductor cloud sandbox (Amazon Linux)

Identify by the path `/home/vercel-sandbox/workspace` on Amazon Linux 2023
(`ID_LIKE=fedora`, `dnf`, user `vercel-sandbox` with passwordless `sudo`).
**Nothing is preinstalled** — no mise, no Ruby, no compiler — so bare
`ruby`/`bundle`/`bin/lint` fail with `env: 'ruby': No such file or directory`.

Unlike the Claude Code web sandbox, egress here is wide open: `cache.ruby-lang.org`,
`rubygems.org`, `registry.npmjs.org`, `cdn.jsdelivr.net`, and `api.github.com`
are all reachable. So take mise's normal build path — **skip the
GitHub-source hand-build and the jsdelivr proxy**; neither is needed here.

### One-time setup (~2–3 min)

```bash
# 1. Compiler + headers (mise/ruby-build compiles Ruby from source).
#    shared-mime-info is required: the mimemagic gem errors at install without it.
sudo dnf install -y gcc gcc-c++ make openssl-devel readline-devel \
  zlib-devel libyaml-devel libffi-devel gdbm-devel ncurses-devel \
  shared-mime-info

# 2. Install mise (not preinstalled)
curl -fsSL https://mise.run | sh          # -> ~/.local/bin/mise

# 3. Build the Ruby + Node pinned in mise.toml. `mise install` reads the file;
#    the Ruby compile is ~2 min because cache.ruby-lang.org is reachable here.
export PATH="$HOME/.local/bin:$PATH"
cd /home/vercel-sandbox/workspace
mise trust --yes
mise install
```

### Each shell

Activate mise so its shims put the pinned Ruby and a matching Bundler on PATH
(Bundler 4.0.x ships as a default gem — no separate `gem install bundler`):

```bash
export PATH="$HOME/.local/bin:$PATH"
eval "$(mise activate bash)"
ruby --version      # => ruby 4.0.6 ... [x86_64-linux]
bundle install      # ~8s once shared-mime-info is present; vendor/bundle + .bundle are gitignored
```

`bin/lint`, `bundle exec rspec`, etc. then work normally. If a subprocess
drops the mise shim (same harness quirk as Local macOS), prefix the install
dir directly instead of reactivating (match the version in `mise.toml`):

```bash
export PATH="$HOME/.local/share/mise/installs/ruby/4.0.6/bin:$PATH"
```

### Database-backed specs

Postgres and redis aren't preinstalled here either. Install the server packages
from dnf (`dnf search postgresql` / `dnf search redis` for the current version
suffix), start the daemons, then the psql / db:migrate steps in `web-sandbox.md`'s
**Services + DB** apply unchanged (its `service …` / `apt` wording is web-sandbox
specific, but the SQL and Rails commands are the same). The Tailwind build in
SKILL.md still applies to any spec that renders the layout.
