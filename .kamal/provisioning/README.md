# Server provisioning

An [Ansible](https://www.ansible.com/) playbook that prepares a fresh Ubuntu server for [Kamal](https://kamal-deploy.org/) deploys. Run this once against a new droplet before booting kamal-proxy and the shared accessories (see `docs/review-apps.md` → "One-time host setup").

Vendored from [guillaumebriday/kamal-ansible-manager](https://github.com/guillaumebriday/kamal-ansible-manager) (MIT, see `LICENSE`). The Scaleway provisioning role has been removed — this template deploys to DigitalOcean.

## What it does

Installs and configures, for Ubuntu only:

- [Docker](https://docs.docker.com/engine/install/ubuntu/)
- [Fail2ban](https://github.com/fail2ban/fail2ban)
- [UFW](https://wiki.ubuntu.com/UncomplicatedFirewall) (allows SSH, HTTP, HTTPS)
- [NTP](https://ubuntu.com/server/docs/network-ntp)
- Swap, via [geerlingguy.swap](https://github.com/geerlingguy/ansible-role-swap)

It also removes [Snap](https://snapcraft.io/) and disables SSH password login.

## Usage

From the `.kamal/provisioning/` directory:

```bash
cp hosts.ini.example hosts.ini
# edit hosts.ini, replacing <host1> with your droplet IP

ansible-galaxy install -r requirements.yml

ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i hosts.ini playbook.yml
```

## Configuring vars

Override variables in `playbook.yml`. For example:

```yml
vars:
  security_autoupdate_reboot: "true"
  security_autoupdate_reboot_time: "03:00"
  swap_file_size_mb: "1024"
```

See [geerlingguy.swap defaults](https://github.com/geerlingguy/ansible-role-swap/blob/master/defaults/main.yml) for swap options.
