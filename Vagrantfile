# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"

required_plugins = %w(vagrant-vbguest)

plugins_to_install = required_plugins.select { |plugin| not Vagrant.has_plugin? plugin }
if not plugins_to_install.empty?
  puts "Installing required plugins: #{plugins_to_install.join(' ')}"
  if system "vagrant plugin install #{plugins_to_install.join(' ')}"
    exec "vagrant #{ARGV.join(' ')}"
  else
    abort "Installation of one or more plugins has failed. Aborting. Please read the Bike Index README."
  end
end

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  # https://bugs.launchpad.net/cloud-images/+bug/1569237 has been fixed, use official Ubuntu box
  config.vm.box = "ubuntu/xenial64"

  # Configurate the virtual machine to use 1.5GB of RAM
  config.vm.provider :virtualbox do |vb|
	  vb.customize ["modifyvm", :id, "--memory", "1536"]
  end

  # Forward the Rails server default port to the host
  config.vm.network :forwarded_port, guest: 3001, host: 3001

  # This provisioner runs on every `vagrant provision` and the initial `vagrant up`.
  # Install dependencies and add 'vagrant' user to 'rvm' group
  config.vm.provision "install", type: "shell", inline: <<-SHELL
  apt-get install -y --reinstall pkg-config libmagickcore-dev libmagickwand-dev libpq-dev redis-server rubygems-integration
  apt-add-repository -y ppa:rael-gc/rvm
  add-apt-repository "deb http://apt.postgresql.org/pub/repos/apt/ xenial-pgdg main"
  wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
  apt-get update
  apt-get install -y --reinstall rvm postgresql-9.6
  usermod -a -G rvm vagrant
  SHELL

  # This provisioner runs on every `vagrant provision`, `vagrant reload`, and the initial `vagrant up`.
  # Use echo to create a provisioning script, chmod +x it, and execute it.
  config.vm.provision "recompose", type: "shell",
	  run: "reload", privileged: false, inline: <<-SHELL
  echo -e '#!/bin/bash -l\nsudo -u postgres -H bash << EOL\npsql -c "CREATE ROLE vagrant WITH PASSWORD '"'vagrant'"' SUPERUSER CREATEDB LOGIN;"\nEOL\ncreatedb vagrant\nnewgrp rvm\nrvm install 2.2.5\ngem install bundler\ncd /vagrant\nbundle install\nrake db:setup\nrake seed_test_users_and_bikes' > ~/rubydevprovision.sh && chmod +x rubydevprovision.sh
  sg rvm -c './rubydevprovision.sh'
  echo -e 'Vagrant provisioning has completed. You can now "vagrant ssh" and start using it. If any\nerrors were thrown during provisioning, try running "./rubydevprovision.sh" inside the\nvagrant environment or run all of the provisioning scripts a second time\nwith "vagrant provision". You can find your local git repo in /vagrant.'
  SHELL
end
