# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  # Use David Warkentin's Ubuntu 16.04 Xenial Xerus 64-bit as our operating system (https://bugs.launchpad.net/cloud-images/+bug/1569237/comments/33)
  config.vm.box = "v0rtex/xenial64"

  # Configurate the virtual machine to use 1.5GB of RAM
  config.vm.provider :virtualbox do |vb|
	  vb.customize ["modifyvm", :id, "--memory", "1536"]
  end

  # Forward the Rails server default port to the host
  config.vm.network :forwarded_port, guest: 3001, host: 3001

  # This provisioner runs on the first `vagrant up` and every `vagrant reload`.
  config.vm.provision "recompose", type: "shell",
  run: "always", inline: <<-SHELL
  apt-get install pkg-config libmagickcore-dev libmagickwand-dev libpq-dev redis-server
  TODO: add rbenv, ruby 2.2.5, bundler, postgres 9.4, configure postgres 
  SHELL
end
