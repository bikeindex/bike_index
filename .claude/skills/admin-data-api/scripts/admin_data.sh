#!/usr/bin/env bash
# Helper for the AdminData production API (Sidekiq / PgHero status).
# Reads/writes token values in .env.development (located relative to this script,
# so it works from any cwd). Run it directly, e.g.
#   .claude/skills/admin-data-api/scripts/admin_data.sh check
#
# Requires in .env.development: ADMIN_DOORKEEPER_APP_CLIENT_ID,
# ADMIN_DOORKEEPER_APP_CLIENT_SECRET, and (after first authorize) ADMIN_DATA_TOKEN
# + ADMIN_DATA_REFRESH. Tokens auto-refresh on a 401 using the secret.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
ENV_FILE="$REPO_ROOT/.env.development"
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

# Exchange ADMIN_DATA_REFRESH for a new token pair and store it.
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

# do_get with a one-shot refresh + retry on failure (typically a 401). Body → stdout.
get_or_refresh() {
  local endpoint="$1" body
  if body="$(do_get "$endpoint")"; then printf '%s' "$body"; return 0; fi
  echo "Token rejected — refreshing and retrying…" >&2
  do_refresh || return 1
  do_get "$endpoint"
}

# jq: "nothing abnormal" verdict for each payload. Hit rates and unused/duplicate
# indexes are informational; "System stats not enabled" is a disabled feature, not a fault.
SIDEKIQ_VERDICT='
  ( [ .queues[] | select(.latency>30 or .size>400 or .paused)
      | "queue \(.name) size=\(.size) latency=\(.latency)\(if .paused then " PAUSED" else "" end)" ] ) as $backlog
  | ( [ ($backlog[]),
        (if .stats.retry_size>0 then "retry_size=\(.stats.retry_size)" else empty end),
        (if (.processes|length)==0 then "no worker processes" else empty end),
        (if ((.processes|length)>0 and ([.processes[].quiet]|all)) then "all workers quiet" else empty end) ] ) as $r
  | "summary: enqueued=\(.stats.enqueued) retry=\(.stats.retry_size) scheduled=\(.stats.scheduled_size) processes=\(.processes|length)\n"
    + (if ($r|length)==0 then "verdict: OK — nothing abnormal" else "verdict: ABNORMAL — " + ($r|join("; ")) end)
'
PGHERO_VERDICT='
  def alen(f): (f | if type=="array" then length else 0 end);
  ( [ to_entries[] | select(.value|type=="object" and has("error"))
      | select(.value.error != "System stats not enabled") | "\(.key): \(.value.error)" ] ) as $errs
  | ( [ ($errs[]),
        (if alen(.long_running_queries)>0 then "long_running_queries=\(alen(.long_running_queries))" else empty end),
        (if alen(.blocked_queries)>0 then "blocked_queries=\(alen(.blocked_queries))" else empty end),
        (if alen(.invalid_indexes)>0 then "invalid_indexes=\(alen(.invalid_indexes))" else empty end),
        (if alen(.sequence_danger)>0 then "sequence_danger=\(alen(.sequence_danger))" else empty end),
        (if alen(.transaction_id_danger)>0 then "transaction_id_danger" else empty end),
        (if alen(.autovacuum_danger)>0 then "autovacuum_danger=\(alen(.autovacuum_danger))" else empty end),
        (if ((.index_hit_rate|tonumber? // 1) < 0.90) then "index_hit_rate=\(.index_hit_rate)" else empty end) ] ) as $r
  | "summary: connections=\(.total_connections)/\(.settings.max_connections // "?") db=\(.database_size) running=\(alen(.running_queries)) index_hit=\((.index_hit_rate|tostring)[0:5]) table_hit(info)=\((.table_hit_rate|tostring)[0:5]) unused_indexes=\(alen(.unused_indexes))\n"
    + (if ($r|length)==0 then "verdict: OK — nothing abnormal" else "verdict: ABNORMAL — " + ($r|join("; ")) end)
'

cmd="${1:-}"
case "$cmd" in
  authorize-url)
    client_id="$(env_get ADMIN_DOORKEEPER_APP_CLIENT_ID)"
    [ -n "$client_id" ] || { echo "ADMIN_DOORKEEPER_APP_CLIENT_ID missing from $ENV_FILE" >&2; exit 1; }
    redirect="https%3A%2F%2Fbikeindex.org%2Fdocumentation%2Fauthorize"
    echo "${BASE}/oauth/authorize?client_id=${client_id}&redirect_uri=${redirect}&response_type=code&scope=public"
    ;;

  get) # get <sidekiq|pghero> — auto-refreshes and retries once on a 401
    body="$(get_or_refresh "${2:?usage: get <sidekiq|pghero>}")" || exit 22
    printf '%s\n' "$body"
    ;;

  check) # full health check: sidekiq, then pghero — prints a summary + OK/ABNORMAL verdict each
    echo "== SIDEKIQ =="
    body="$(get_or_refresh sidekiq)" || exit 22
    printf '%s' "$body" | jq -r "$SIDEKIQ_VERDICT"
    echo ""; echo "== PGHERO =="
    body="$(get_or_refresh pghero)" || exit 22
    printf '%s' "$body" | jq -r "$PGHERO_VERDICT"
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
    echo "usage: admin_data.sh {check | get <sidekiq|pghero> | authorize-url | set-tokens <access> <refresh> | refresh}" >&2
    exit 64
    ;;
esac
