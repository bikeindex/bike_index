#!/bin/bash

# If doing manually, make sure you run:
# sudo cp .cloud66/log_files.yml /etc/log_files.yml
# make sure /etc/log_files.yml # and replace <%= ENV['STACK_BASE'] %> with the values

# Download and install the remote_syslog2 binary from papertrail
wget https://github.com/papertrail/remote_syslog2/releases/download/v0.21/remote_syslog_linux_amd64.tar.gz

tar xzf ./remote_syslog*.tar.gz
cd remote_syslog
sudo cp ./remote_syslog /usr/local/bin

# Set it up as a service (assumes init script has already been cp'd)
sudo remote_syslog
sudo update-rc.d remote_syslog defaults
