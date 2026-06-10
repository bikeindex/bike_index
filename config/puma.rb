# Raise from the systemd default of 1024; insufficient for our DB pool + Redis clients + Excon sockets under load
soft, hard = Process.getrlimit(:NOFILE)
Process.setrlimit(:NOFILE, [65536, hard].min, hard) if soft < 65536

# Puma can serve each request in a thread from an internal thread pool.
# The `threads` method setting takes two numbers: a minimum and maximum.
# Any libraries that use thread pools should be configured to match
# the maximum value specified for Puma. Default is set to 5 threads for minimum
# and maximum; this matches the default thread size of Active Record.
#
max_threads_count = ENV.fetch("RAILS_MAX_THREADS", 5)
min_threads_count = ENV.fetch("RAILS_MIN_THREADS", max_threads_count)
threads min_threads_count, max_threads_count

# Specifies the number of `workers` to boot in clustered mode.
# Jobs are forked web server processes. If using threads and workers together
# the concurrency of the application would be max `threads` * `workers`.
# Jobs do not work on JRuby or Windows (both of which do not support
# processes).
#
# Clustered + preload_app! gives copy-on-write memory savings when deployed. Set
# WEB_CONCURRENCY=0 for single mode (no fork) — required locally so Mata's live-reload
# file-watcher thread and SSE registry share the request-serving process. bin/env
# defaults WEB_CONCURRENCY to 0 in local development.
worker_count = ENV.fetch("WEB_CONCURRENCY", 3).to_i
if worker_count.positive?
  workers worker_count
  preload_app!
else
  workers 0
end

# Set the directory to Cloud 66 specific environment variable so that puma can follow symlinks to new code on redeployment
#
directory ENV.fetch("STACK_PATH", ".")
# Make sure to bind to Cloud 66 specific socket so that NGINX can direct traffic here
#
