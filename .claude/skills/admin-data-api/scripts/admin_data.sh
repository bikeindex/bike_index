#!/usr/bin/env bash
# Helper for the AdminData production API (Sidekiq / PgHero status).
# Reads/writes token values in .env.development. Run from the repo root.
set -euo pipefail

ENV_FILE=".env.development"
BASE="https://bikeindex.org"

env_get() { grep -E "^$1=" "$ENV_FILE" 2>/dev/null | head -1 | cut -d= -f2- || true; }

# Upsert KEY=VALUE in .env.development (replace in place, or append if absent).
env_set() {
  local key="$1" value="$2" tmp
  tmp="$(mktemp)"
  if grep -qE "^$key=" "$ENV_FILE" 2>/dev/null; then
    # Use a non-/ delimiter; tokens can contain / but not | or newlines.
    sed "s|^$key=.*|$key=$value|" "$ENV_FILE" >"$tmp" && mv "$tmp" "$ENV_FILE"
  else
    cat "$ENV_FILE" >"$tmp"; printf '%s=%s\n' "$key" "$value" >>"$tmp"; mv "$tmp" "$ENV_FILE"
  fi
}

cmd="${1:-}"
case "$cmd" in
  authorize-url)
    client_id="$(env_get ADMIN_DOORKEEPER_APP_CLIENT_ID)"
    [ -n "$client_id" ] || { echo "ADMIN_DOORKEEPER_APP_CLIENT_ID missing from $ENV_FILE" >&2; exit 1; }
    redirect="https%3A%2F%2Fbikeindex.org%2Fdocumentation%2Fauthorize"
    echo "${BASE}/oauth/authorize?client_id=${client_id}&redirect_uri=${redirect}&response_type=code&scope=public"
    ;;

  get) # get <sidekiq|pghero> — prints "HTTP <status>" then the JSON body
    endpoint="${2:?usage: get <sidekiq|pghero>}"
    token="$(env_get ADMIN_DATA_TOKEN)"
    [ -n "$token" ] || { echo "ADMIN_DATA_TOKEN missing from $ENV_FILE — run the authorize flow (see SKILL.md)" >&2; exit 1; }
    resp="$(curl -sS -w $'\n%{http_code}' -H "Authorization: Bearer ${token}" "${BASE}/api/admin_data/${endpoint}")"
    code="${resp##*$'\n'}"; body="${resp%$'\n'*}"
    echo "HTTP ${code}"
    echo "$body"
    [ "$code" = "200" ] || exit 22
    ;;

  set-tokens) # set-tokens <access_token> <refresh_token>
    env_set ADMIN_DATA_TOKEN "${2:?access_token required}"
    env_set ADMIN_DATA_REFRESH "${3:?refresh_token required}"
    echo "Updated ADMIN_DATA_TOKEN and ADMIN_DATA_REFRESH in $ENV_FILE"
    ;;

  refresh) # refresh — needs ADMIN_DOORKEEPER_APP_CLIENT_SECRET; falls back to browser flow otherwise
    client_id="$(env_get ADMIN_DOORKEEPER_APP_CLIENT_ID)"
    secret="$(env_get ADMIN_DOORKEEPER_APP_CLIENT_SECRET)"
    refresh="$(env_get ADMIN_DATA_REFRESH)"
    [ -n "$secret" ] || { echo "No ADMIN_DOORKEEPER_APP_CLIENT_SECRET — use the browser authorize flow instead (see SKILL.md)" >&2; exit 1; }
    [ -n "$refresh" ] || { echo "ADMIN_DATA_REFRESH missing — use the browser authorize flow" >&2; exit 1; }
    resp="$(curl -sS "${BASE}/oauth/token" \
      -d grant_type=refresh_token -d "refresh_token=${refresh}" \
      -d "client_id=${client_id}" -d "client_secret=${secret}")"
    echo "$resp"
    ;;

  *)
    echo "usage: admin_data.sh {authorize-url | get <sidekiq|pghero> | set-tokens <access> <refresh> | refresh}" >&2
    exit 64
    ;;
esac
