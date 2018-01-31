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
  # Configure PostgreSQL because that's the only thing we can get working reliably
  config.vm.provision "recompose", type: "shell",
	  run: "always", privileged: false, inline: <<-SHELL
  sudo -u postgres -H bash << EOF
  psql -c "CREATE ROLE vagrant WITH PASSWORD 'vagrant' SUPERUSER CREATEDB LOGIN;"
  EOF
  createdb vagrant
  echo 'Vagrant provisioning appears to have been a success. You can now "vagrant ssh" and "cd /vagrant". Follow the prompts to install Ruby 2.2.5 and then "gem install bundler". Continue with the steps in the Bike Index README to finish initializing a local development environment.'
  SHELL
end
