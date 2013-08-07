require 'capistrano/ext/multistage'
require 'bundler/capistrano'
require "dotenv/capistrano"


set :stages, %w(vagrant production)
set :default_stage, "production"

set :user, "deploy"
set :scm, :git
set :branch, :master

set :application, "bikeindex"
set :repository,  "git@github.com:bikeindex/webapp.git"

set :rails_env, 'production'

set :deploy_to, "/home/deploy/#{application}"
set :deploy_via, :remote_cache
set :use_sudo, false

set :ssh_options, { :forward_agent => true }

set :workers, {"email" => 2, "user_tasks" => 1}

after "deploy:restart", "deploy:cleanup"

namespace :deploy do
  task :start do ; end
  task :stop do ; end
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "#{try_sudo} touch #{File.join(current_path,'tmp','restart.txt')}"
    run "#{try_sudo} /etc/init.d/bikeindex_resque restart"
  end
end

after "deploy:setup", "deploy:dbyml_upload"
before "deploy:assets:precompile","deploy:dbyml_symlink"

namespace :deploy do
  task :dbyml_symlink do
    run "ln -nfs #{shared_path}/config/database.yml #{release_path}/config/database.yml"
  end
end

namespace :db do
  task :create do
    run "cd #{current_path}; rake db:create RAILS_ENV=#{rails_env}"
  end
end

require './config/boot'
require 'airbrake/capistrano'
