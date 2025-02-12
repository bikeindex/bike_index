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
workers ENV.fetch("WEB_CONCURRENCY", 4)

# Use the `preload_app!` method when specifying a `workers` number.
# This directive tells Puma to first boot the application and load code
# before forking the application. This takes advantage of Copy On Write
# process behavior so workers use less memory.
#
preload_app!

# Set the directory to Cloud 66 specific environment variable so that puma can follow symlinks to new code on redeployment
#
directory ENV.fetch("STACK_PATH", ".")
# Make sure to bind to Cloud 66 specific socket so that NGINX can direct traffic here
#
