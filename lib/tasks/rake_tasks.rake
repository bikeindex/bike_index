task :start do
  system 'redis-server &'
  system 'bundle exec foreman start -f Procfile_development'
end
