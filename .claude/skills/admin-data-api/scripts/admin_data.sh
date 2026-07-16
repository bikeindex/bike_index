#!/usr/bin/env bash
# Helper for the AdminData production API (Sidekiq / PgHero status).
# Reads/writes token values in .env.development. Run from the repo root.
#
# Requires in .env.development: ADMIN_DOORKEEPER_APP_CLIENT_ID,
# ADMIN_DOORKEEPER_APP_CLIENT_SECRET, and (after first authorize) ADMIN_DATA_TOKEN
# + ADMIN_DATA_REFRESH. `get` auto-refreshes the token on a 401 using the secret.
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

# Exchange ADMIN_DATA_REFRESH for a new token pair and store it. Returns non-zero
# (with a message) when the secret/refresh token is missing or the grant fails.
do_refresh() {
  local client_id secret refresh resp access new_refresh
  client_id="$(env_get ADMIN_DOORKEEPER_APP_CLIENT_ID)"
  secret="$(env_get ADMIN_DOORKEEPER_APP_CLIENT_SECRET)"
  refresh="$(env_get ADMIN_DATA_REFRESH)"
  [ -n "$secret" ] || { echo "ADMIN_DOORKEEPER_APP_CLIENT_SECRET missing from $ENV_FILE" >&2; return 1; }
  [ -n "$refresh" ] || { echo "ADMIN_DATA_REFRESH missing — run the browser authorize flow (see SKILL.md)" >&2; return 1; }
  resp="$(curl -sS "${BASE}/oauth/token" \
    -d grant_type=refresh_token -d "refresh_token=${refresh}" \
    -d "client_id=${client_id}" -d "client_secret=${secret}")"
  access="$(printf '%s' "$resp" | jq -r '.access_token // empty')"
  new_refresh="$(printf '%s' "$resp" | jq -r '.refresh_token // empty')"
  if [ -z "$access" ] || [ -z "$new_refresh" ]; then
    echo "Refresh failed: $(printf '%s' "$resp" | jq -rc '.error_description // .error // .' 2>/dev/null || printf '%s' "$resp")" >&2
    echo "The refresh token may be revoked — run the browser authorize flow (see SKILL.md)." >&2
    return 1
  fi
  env_set ADMIN_DATA_TOKEN "$access"
  env_set ADMIN_DATA_REFRESH "$new_refresh"
  echo "Refreshed ADMIN_DATA_TOKEN and ADMIN_DATA_REFRESH in $ENV_FILE" >&2
}

# GET the endpoint with the current token. Body → stdout, "HTTP <code>" → stderr;
# returns 0 only on 200.
do_get() {
  local endpoint="$1" token resp code body
  token="$(env_get ADMIN_DATA_TOKEN)"
  [ -n "$token" ] || { echo "ADMIN_DATA_TOKEN missing from $ENV_FILE — run the authorize flow (see SKILL.md)" >&2; return 3; }
  resp="$(curl -sS -w $'\n%{http_code}' -H "Authorization: Bearer ${token}" "${BASE}/api/admin_data/${endpoint}")"
  code="${resp##*$'\n'}"; body="${resp%$'\n'*}"
  echo "HTTP ${code}" >&2
  printf '%s\n' "$body"
  [ "$code" = "200" ]
}

cmd="${1:-}"
case "$cmd" in
  authorize-url)
    client_id="$(env_get ADMIN_DOORKEEPER_APP_CLIENT_ID)"
    [ -n "$client_id" ] || { echo "ADMIN_DOORKEEPER_APP_CLIENT_ID missing from $ENV_FILE" >&2; exit 1; }
    redirect="https%3A%2F%2Fbikeindex.org%2Fdocumentation%2Fauthorize"
    echo "${BASE}/oauth/authorize?client_id=${client_id}&redirect_uri=${redirect}&response_type=code&scope=public"
    ;;

  get) # get <sidekiq|pghero> — auto-refreshes and retries once on a 401/expired token
    endpoint="${2:?usage: get <sidekiq|pghero>}"
    if body="$(do_get "$endpoint")"; then printf '%s\n' "$body"; exit 0; fi
    echo "Token rejected — refreshing and retrying…" >&2
    do_refresh || exit 22
    body="$(do_get "$endpoint")" && { printf '%s\n' "$body"; exit 0; } || exit 22
    ;;

  set-tokens) # set-tokens <access_token> <refresh_token> — for the browser authorize flow
    env_set ADMIN_DATA_TOKEN "${2:?access_token required}"
    env_set ADMIN_DATA_REFRESH "${3:?refresh_token required}"
    echo "Updated ADMIN_DATA_TOKEN and ADMIN_DATA_REFRESH in $ENV_FILE"
    ;;

  refresh) # refresh the token pair now (needs ADMIN_DOORKEEPER_APP_CLIENT_SECRET)
    do_refresh
    ;;

  *)
    echo "usage: admin_data.sh {authorize-url | get <sidekiq|pghero> | set-tokens <access> <refresh> | refresh}" >&2
    exit 64
    ;;
esac
