#!/bin/bash
touch log/development.log
> log/development.log # Clear out development log, otherwise it balloons
> log/test.log # Clear out test log too
redis-server &
# If there is a development specific environment file
if test -f .env.development; then
  bundle exec foreman start -f Procfile_development --env .env.development
else
  bundle exec foreman start -f Procfile_development
fi
