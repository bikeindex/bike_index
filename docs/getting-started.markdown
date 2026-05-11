# Getting Started Guide

These instructions will set up an Ubuntu instance to run and develop BikeIndex.

### Prerequisites

1. Install Ubuntu 23 or newer

#### Getting Started with a virtual machine in macOS

If you're working on a Mac and want to develop using an Ubuntu virtual machine follow these steps.

1. Download UTM from https://mac.getutm.app or the App Store
2. Follow UTM's [Ubuntu guide for a customized Ubuntu installation](https://docs.getutm.app/guides/ubuntu/)
    - You will need to download ubuntu-23.10-live-server-arm64.iso from https://ubuntu.com/download/server
    - After installing the OS and creating an account, you will need to run `sudo apt update && sudo apt install ubuntu-desktop && sudo reboot`
    - Alternatively you could try UTM's [pre-built Ubuntu 20.04 VM from their download/open links](https://mac.getutm.app/gallery/ubuntu-20-04)
3. Login with the account you made
4. Open a Terminal and paste the Installation commands in the next section

## Installation

```bash
# 1. System Dependencies
#   Postgresql 15 is the current version
sudo apt-get update
sudo apt-get install g++ make python3 python3-pip imagemagick redis-server postgresql postgresql-contrib libpq-dev

# 2.1 Set up Postgresql
#   create a password for your postgres user
sudo passwd postgres
# 2.2 sign in to postgres and create a superuser for Rails
#     see the postgres docs to create different permissions for production
#     you must replace ubuntu with your username
su - postgres
createuser -s -r ubuntu
# 2.3 return to the user shell
exit

# 3. Install asdf version manager
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.13.1
echo ". $HOME/.asdf/asdf.sh" >> ~/.bashrc
source ~/.bashrc

# 4. Download Project
git clone https://github.com/bikeindex/bike_index.git
cd bike_index

# 5.1 Install project dependencies
asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git
asdf plugin add ruby https://github.com/asdf-vm/asdf-ruby.git
asdf install

# 5.2 Install gems
gem install bundler
bundle install

# 5.3 Set up the app
bin/setup

# 6. Start the development server
bin/dev

# Open the app!
# You will have to use another Terminal or open Firefox directly
open 'http://localhost:3042'
```
