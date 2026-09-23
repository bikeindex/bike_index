# Conductor cloud sandbox (Amazon Linux)

`/home/vercel-sandbox/workspace` on Amazon Linux 2023 (`dnf`, user `vercel-sandbox` with
passwordless `sudo`). **Nothing is preinstalled** — no mise, Ruby or compiler — so
`ruby`/`bundle`/`bin/lint` fail with `env: 'ruby': No such file or directory`. Egress is
open, so mise's normal build path works.

## Once (~2–3 min)

```bash
# shared-mime-info: the mimemagic gem fails to install without it
sudo dnf install -y gcc gcc-c++ make openssl-devel readline-devel zlib-devel \
  libyaml-devel libffi-devel gdbm-devel ncurses-devel shared-mime-info
curl -fsSL https://mise.run | sh   # -> ~/.local/bin/mise
export PATH="$HOME/.local/bin:$PATH"
cd /home/vercel-sandbox/workspace && mise trust --yes && mise install
```

## Each shell

```bash
export PATH="$HOME/.local/bin:$PATH"
eval "$(mise activate bash)"
bundle install
```

If a subprocess drops the shims (as on macOS), prefix the install directly:
`export PATH="$HOME/.local/share/mise/installs/ruby/<pin>/bin:$PATH"`.

## Database-backed specs

Postgres and redis aren't installed either: `dnf search postgresql` / `dnf search redis`
for the current packages, start them, then follow **By hand** in `web-sandbox.md` for
the `rails` role and `bin/workspace_setup` (skip its `apt`/`service` specifics). For
records, `bundle exec rails db:seed` — it needs ImageMagick (`dnf search imagemagick`).
