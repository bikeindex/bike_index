# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"

required_plugins = %w(vagrant-vbguest vagrant-librarian-chef-nochef)

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
  # Use David Warkentin's Ubuntu 16.04 Xenial Xerus 64-bit as our operating system (https://bugs.launchpad.net/cloud-images/+bug/1569237/comments/33)
  config.vm.box = "v0rtex/xenial64"

  # Configurate the virtual machine to use 1.5GB of RAM
  config.vm.provider :virtualbox do |vb|
	  vb.customize ["modifyvm", :id, "--memory", "1536"]
  end

  # Forward the Rails server default port to the host
  config.vm.network :forwarded_port, guest: 3001, host: 3001

  # Use Chef Solo to provision our virtual machine
  config.vm.provision :chef_solo do |chef|
	  chef.cookbooks_path = ["cookbooks", "site-cookbooks"]

	chef.add_recipe "apt"
	chef.add_recipe "build-essential"
	chef.add_recipe "system::install_packages"
	chef.add_recipe "ruby_build"
	chef.add_recipe "ruby_rbenv::user"
	chef.add_recipe "ruby_rbenv::user_install"
	chef.add_recipe "vim"
   	chef.add_recipe "postgresql::server"
   	chef.add_recipe "postgresql::client"
   	chef.add_recipe "postgresql::setup_users"

    # Install Ruby 2.2.5 and Bundler
    chef.json = {
		rbenv: {
			user_installs: [{
				user: 'vagrant',
				rubies: ["2.2.5"],
				global: "2.2.5",
				gems: {
					"2.2.5" => [
					 { name:	"bundler" }
					]
				}
			}]
		},
		system: {
			:packages	=>	{
				:install	=>	["pkg-config libmagickcore-dev libmagickwand-dev redis-server"]
			}
		},
		postgresql: {
			:version	=>	"9.4",
			:apt_distribution	=>	"xenial",
			:pg_hba	=>	[{
				:comment => "# Add vagrant role",
				:type => 'local', :db => 'all', :user => 'vagrant', :addr => nil, :method => 'trust'
			}],
			:users	=> [{
				"username": "vagrant",
				"password": "vagrant",
				"superuser": true,
				"replication": false,
				"createdb": true,
				"createrole": false,
				"inherit": false,
				"login": true
			}]
		},
		"build-essential"	=>	{
			"compiletime"	=>	true
		}
	}
  end
end
