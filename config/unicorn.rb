if ENV["RAILS_ENV"] == "development"
  worker_processes 2
  working_directory Rails.root
  stderr_path File.join(Rails.root, 'tmp', 'stder.log')
  stdout_path File.join(Rails.root, 'tmp', 'stdout.log')
else  
  worker_processes 3
  working_directory "#{ENV['STACK_PATH']}"
  stderr_path "#{ENV['STACK_PATH']}/log/unicorn.stderr.log"
  stdout_path "#{ENV['STACK_PATH']}/log/unicorn.stdout.log"
end

listen "/tmp/web_server.sock", backlog: 64

timeout 30

pid '/tmp/web_server.pid'

preload_app true
GC.respond_to?(:copy_on_write_friendly=) and
  GC.copy_on_write_friendly = true

check_client_connection false

before_fork do |server, worker|
  if defined? ActiveRecord::Base
    ActiveRecord::Base.connection.disconnect!
  end
  old_pid = '/tmp/web_server.pid.oldbin'
  if File.exists?(old_pid) && server.pid != old_pid
    begin
      Process.kill("QUIT", File.read(old_pid).to_i)
    rescue Errno::ENOENT, Errno::ESRCH
      # someone else did our job for us
    end
  end
  # defined?(ActiveRecord::Base) and
  #   ActiveRecord::Base.connection.disconnect!
end