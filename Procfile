custom_web: bundle exec puma -e $RACK_ENV -b unix:///tmp/web_server.sock --pidfile /tmp/web_server.pid
hard_worker: bundle exec sidekiq -q high_priority -q notify
blockable_worker: bundle exec sidekiq
