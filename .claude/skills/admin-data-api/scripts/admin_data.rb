#!/usr/bin/env ruby
# frozen_string_literal: true

#
# Helper for the production endpoints the admin OAuth app reaches: Sidekiq / PgHero
# status and the admin bug reports.
# Reads/writes token values in .env.development (located relative to this script,
# so it works from any cwd). Run it directly, e.g.
#   .claude/skills/admin-data-api/scripts/admin_data.rb check
#
# Requires in .env.development: ADMIN_DOORKEEPER_APP_CLIENT_ID,
# ADMIN_DOORKEEPER_APP_CLIENT_SECRET, and (after first authorize) ADMIN_DATA_TOKEN
# + ADMIN_DATA_REFRESH. Tokens auto-refresh on a 401 using the secret.

require "net/http"
require "uri"
require "json"
require "dotenv"

BASE = "https://bikeindex.org"
REPO_ROOT = File.expand_path("../../../..", __dir__)
ENV_FILE = File.join(REPO_ROOT, ".env.development")

BUG_REPORTS = "/admin/bug_reports" # Admin pages rather than API routes, same admin token
PATHS = {
  "sidekiq" => "/api/admin_data/sidekiq",
  "pghero" => "/api/admin_data/pghero",
  "bug_reports" => "#{BUG_REPORTS}.json"
}.freeze

def env_get(key)
  return nil unless File.exist?(ENV_FILE)

  Dotenv.parse(ENV_FILE)[key]
end

# Upsert KEY=VALUE in .env.development, preserving the rest of the file. dotenv is
# read-only (no file writer), so the token write-back stays an in-place line edit.
def env_set(key, value)
  content = File.exist?(ENV_FILE) ? File.read(ENV_FILE) : ""
  if content.match?(/^#{Regexp.escape(key)}=.*$/)
    content = content.sub(/^#{Regexp.escape(key)}=.*$/) { "#{key}=#{value}" }
  else
    content += "\n" unless content.empty? || content.end_with?("\n")
    content += "#{key}=#{value}\n"
  end
  File.write(ENV_FILE, content)
end

def request(method, url, headers: {}, form: nil)
  uri = URI(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = uri.scheme == "https"
  req = {get: Net::HTTP::Get, post: Net::HTTP::Post, patch: Net::HTTP::Patch}.fetch(method).new(uri)
  headers.each { |k, v| req[k] = v }
  req.set_form_data(form) if form
  http.request(req)
end

def parse_params(args)
  args.to_h do |arg|
    abort("params are key=value, got: #{arg}") unless arg.include?("=")
    arg.split("=", 2)
  end
end

# Exchange ADMIN_DATA_REFRESH for a new token pair and store it. Returns true on success.
def refresh_token!
  client_id = env_get("ADMIN_DOORKEEPER_APP_CLIENT_ID")
  secret = env_get("ADMIN_DOORKEEPER_APP_CLIENT_SECRET")
  refresh = env_get("ADMIN_DATA_REFRESH")
  return warn_false("ADMIN_DOORKEEPER_APP_CLIENT_SECRET missing from #{ENV_FILE}") if secret.to_s.empty?
  return warn_false("ADMIN_DATA_REFRESH missing — run the browser authorize flow (see SKILL.md)") if refresh.to_s.empty?

  res = request(:post, "#{BASE}/oauth/token", form: {
    "grant_type" => "refresh_token", "refresh_token" => refresh,
    "client_id" => client_id, "client_secret" => secret
  })
  data = begin
    JSON.parse(res.body)
  rescue
    {}
  end
  access = data["access_token"].to_s
  new_refresh = data["refresh_token"].to_s
  if access.empty? || new_refresh.empty?
    warn "Refresh failed: #{data["error_description"] || data["error"] || res.body}"
    return warn_false("The refresh token may be revoked — run the browser authorize flow (see SKILL.md).")
  end
  env_set("ADMIN_DATA_TOKEN", access)
  env_set("ADMIN_DATA_REFRESH", new_refresh)
  warn "Refreshed ADMIN_DATA_TOKEN and ADMIN_DATA_REFRESH in #{ENV_FILE}"
  true
end

def warn_false(message)
  warn message
  false
end

# Returns [status(Integer or nil), body] - a nil status is having no token to send
def token_request(method, path, form: nil)
  token = env_get("ADMIN_DATA_TOKEN")
  if token.to_s.empty?
    warn "ADMIN_DATA_TOKEN missing from #{ENV_FILE} — run the authorize flow (see SKILL.md)"
    return [nil, nil]
  end
  res = request(method, "#{BASE}#{path}", headers: {"Authorization" => "Bearer #{token}"}, form:)
  warn "HTTP #{res.code}"
  [res.code.to_i, res.body]
end

# token_request, refreshing the token and retrying once on a 401. Returns body or nil -
# anything else (403, a 422 from update) is reported rather than retried.
def with_token(method, path, form: nil)
  status, body = token_request(method, path, form:)
  return body if status == 200
  if status && status != 401
    warn body.to_s[0, 500]
    return nil
  end

  warn "Token rejected — refreshing and retrying…" if status == 401
  return nil unless refresh_token!

  status, body = token_request(method, path, form:)
  (status == 200) ? body : nil
end

def get_endpoint(endpoint, params = {})
  path = PATHS.fetch(endpoint) { abort("unknown endpoint #{endpoint} — one of: #{PATHS.keys.join(", ")}") }
  with_token(:get, params.any? ? "#{path}?#{URI.encode_www_form(params)}" : path)
end

def array_length(value)
  value.is_a?(Array) ? value.length : 0
end

# "nothing abnormal" verdicts. A queue backlogs at latency > 30s or size > 400 (not
# transient depth). PgHero hit rates and unused/duplicate indexes are informational,
# and "System stats not enabled" is a disabled feature, not a fault.
def sidekiq_verdict(data)
  stats = data["stats"] || {}
  processes = data["processes"] || []
  reasons = []
  (data["queues"] || []).each do |q|
    next unless q["latency"].to_f > 30 || q["size"].to_i > 400 || q["paused"]

    reasons << "queue #{q["name"]} size=#{q["size"]} latency=#{q["latency"]}#{" PAUSED" if q["paused"]}"
  end
  reasons << "retry_size=#{stats["retry_size"]}" if stats["retry_size"].to_i > 0
  if processes.empty?
    reasons << "no worker processes"
  elsif processes.all? { |p| p["quiet"] }
    reasons << "all workers quiet"
  end
  <<~OUT.chomp
    summary: enqueued=#{stats["enqueued"]} retry=#{stats["retry_size"]} scheduled=#{stats["scheduled_size"]} processes=#{processes.length}
    #{verdict_line(reasons)}
  OUT
end

def pghero_verdict(data)
  reasons = []
  data.each do |key, value|
    next unless value.is_a?(Hash) && value.key?("error") && value["error"] != "System stats not enabled"

    reasons << "#{key}: #{value["error"]}"
  end
  reasons << "long_running_queries=#{array_length(data["long_running_queries"])}" if array_length(data["long_running_queries"]) > 0
  reasons << "blocked_queries=#{array_length(data["blocked_queries"])}" if array_length(data["blocked_queries"]) > 0
  reasons << "invalid_indexes=#{array_length(data["invalid_indexes"])}" if array_length(data["invalid_indexes"]) > 0
  reasons << "sequence_danger=#{array_length(data["sequence_danger"])}" if array_length(data["sequence_danger"]) > 0
  reasons << "transaction_id_danger" if array_length(data["transaction_id_danger"]) > 0
  reasons << "autovacuum_danger=#{array_length(data["autovacuum_danger"])}" if array_length(data["autovacuum_danger"]) > 0
  reasons << "index_hit_rate=#{data["index_hit_rate"]}" if data["index_hit_rate"] && data["index_hit_rate"].to_f < 0.90
  max_conn = (data["settings"] || {})["max_connections"] || "?"
  <<~OUT.chomp
    summary: connections=#{data["total_connections"]}/#{max_conn} db=#{data["database_size"]} running=#{array_length(data["running_queries"])} index_hit=#{data["index_hit_rate"].to_s[0, 5]} table_hit(info)=#{data["table_hit_rate"].to_s[0, 5]} unused_indexes=#{array_length(data["unused_indexes"])}
    #{verdict_line(reasons)}
  OUT
end

def verdict_line(reasons)
  reasons.empty? ? "verdict: OK — nothing abnormal" : "verdict: ABNORMAL — #{reasons.join("; ")}"
end

case ARGV[0]
when "authorize-url"
  client_id = env_get("ADMIN_DOORKEEPER_APP_CLIENT_ID")
  abort "ADMIN_DOORKEEPER_APP_CLIENT_ID missing from #{ENV_FILE}" if client_id.to_s.empty?
  redirect = "https%3A%2F%2Fbikeindex.org%2Fdocumentation%2Fauthorize"
  puts "#{BASE}/oauth/authorize?client_id=#{client_id}&redirect_uri=#{redirect}&response_type=code&scope=public"

when "get" # get <endpoint> [param=value …] — auto-refreshes and retries once on a 401
  endpoint = ARGV[1] or abort("usage: get <#{PATHS.keys.join("|")}> [param=value …]")
  body = get_endpoint(endpoint, parse_params(ARGV.drop(2))) or exit(22)
  puts body

when "show-bug-report" # show-bug-report <id>
  id = ARGV[1] or abort("usage: show-bug-report <id>")
  body = with_token(:get, "#{BUG_REPORTS}/#{id}.json") or exit(22)
  puts body

when "update-bug-report" # update-bug-report <id> tags=a,b github_pull_request=4064
  id = ARGV[1] or abort("usage: update-bug-report <id> [tags=a,b] [github_pull_request=N]")
  attributes = parse_params(ARGV.drop(2))
  abort("nothing to update") if attributes.empty?
  body = with_token(:patch, "#{BUG_REPORTS}/#{id}.json",
    form: attributes.transform_keys { "bug_report[#{it}]" }) or exit(22)
  puts body

when "check" # full health check: sidekiq, then pghero — summary + OK/ABNORMAL verdict each
  puts "== SIDEKIQ =="
  body = get_endpoint("sidekiq") or exit(22)
  puts sidekiq_verdict(JSON.parse(body))
  puts "\n== PGHERO =="
  body = get_endpoint("pghero") or exit(22)
  puts pghero_verdict(JSON.parse(body))

when "set-tokens" # set-tokens <access_token> <refresh_token> — for the browser authorize flow
  access = ARGV[1] or abort("access_token required")
  refresh = ARGV[2] or abort("refresh_token required")
  env_set("ADMIN_DATA_TOKEN", access)
  env_set("ADMIN_DATA_REFRESH", refresh)
  puts "Updated ADMIN_DATA_TOKEN and ADMIN_DATA_REFRESH in #{ENV_FILE}"

when "refresh" # refresh the token pair now (needs ADMIN_DOORKEEPER_APP_CLIENT_SECRET)
  exit(refresh_token! ? 0 : 1)

else
  warn "usage: admin_data.rb {check | get <#{PATHS.keys.join("|")}> [param=value …] | " \
    "show-bug-report <id> | update-bug-report <id> [param=value …] | " \
    "authorize-url | set-tokens <access> <refresh> | refresh}"
  exit 64
end
