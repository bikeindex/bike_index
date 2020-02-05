# Running puma with 4,16 threads and 3 workers
custom_web: bundle exec puma -e $RACK_ENV -b unix:///tmp/web_server.sock --pidfile /tmp/web_server.pid -d
hard_worker: bundle exec sidekiq
