custom_web: bundle exec puma -e $RACK_ENV -b unix:///tmp/web_server.sock --pidfile /tmp/web_server.pid
hard_worker: bundle exec sidekiq -q high_priority,200 -q notify,200 -q carrierwave,20 -q low_priority,10
blockable_worker: bundle exec sidekiq
