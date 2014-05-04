task :start do
  system 'bundle exec foreman start -f Procfile_development'
end
