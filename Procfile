# Running puma with 8,32 threads and 3 workers
custom_web: bundle exec puma -e $RACK_ENV -b unix:///tmp/web_server.sock --pidfile /tmp/web_server.pid -d -t 8:32 -w 3
hard_worker: bundle exec sidekiq
