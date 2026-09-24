![42](https://img.shields.io/badge/42-000000?style=for-the-badge&logo=42&logoColor=white)
![Debian](https://img.shields.io/badge/Debian-A81D33?style=for-the-badge&logo=debian&logoColor=white)
![VirtualBox](https://img.shields.io/badge/VirtualBox-183A61?style=for-the-badge&logo=virtualbox&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white)
![MariaDB](https://img.shields.io/badge/MariaDB-003545?style=for-the-badge&logo=mariadb&logoColor=white)
![WordPress](https://img.shields.io/badge/WordPress-21759B?style=for-the-badge&logo=wordpress&logoColor=white)
![PHP](https://img.shields.io/badge/PHP-777BB4?style=for-the-badge&logo=php&logoColor=white)

## Navigation

- [Description](#description)
  - [Operating system choice](#operating-system-choice)
  - [Main design choices](#main-design-choices)
  - [Comparisons](#comparisons)
- [Instructions](#instructions)
  - [Requirements](#requirements)
  - [Verify the disk image](#verify-the-disk-image)
  - [Run the VM](#run-the-vm)
  - [Connect over SSH](#connect-over-ssh)
  - [Monitoring](#monitoring)
  - [`wall` fix](#wall-fix)
  - [Bonus (WordPress)](#bonus-wordpress)
  - [Bonus (fail2ban)](#bonus-fail2ban)
- [Resources](#resources)
  - [Main Links](#main-links)
  - [Usage of AI](#usage-of-ai)

# Description

For this project i had to create a virtual machine inside VirtualBox, with the latest stable Debian or Rocky release. i chose Debian since the subject was obviously more biased in its favor, and also because its easier to set up for someone who never really administrated a server before. There is way more documentation and forum posts about Debian, so when something broke i could usually find someone who had the same problem.

### Operating system choice

**Debian**
Pros: very stable, huge community, lots of documentation, apt is simple to use, AppArmor and UFW are easy to work with.
Cons: packages are often older versions because they prioritize stability, and its less common in big enterprise environments than RHEL based systems.

**Rocky Linux**
Pros: binary compatible with Red Hat Enterprise Linux, so its closer to what companies actually use in production, long support cycle, SELinux enabled by default.
Cons: harder to set up, SELinux and firewalld have a steeper learning curve, and there is less beginner friendly documentation.

### Main design choices

**Partitioning:** i used encrypted LVM so the disk cant be read without the passphrase. The partitions are split into /boot, and inside the encrypted volume: root, swap, home, var, srv, tmp and var-log. Separating them means if one fills up (for example logs in /var/log) it doesnt take down the whole system.

**Security policies:**
- Password policy: passwords expire every 30 days, you have to wait 2 days before changing it again, and you get a warning 7 days before it expires. They need at least 10 characters, an uppercase letter, a lowercase letter and a number, no more than 3 identical characters in a row, and cant contain the username. Also at least 7 characters must be different from the old password (this rule doesnt apply to root).
- sudo: 3 tries max for the password, a custom error message on wrong password, every sudo command is logged in /var/log/sudo/, TTY mode is enabled, and the paths sudo can use are restricted.
- SSH runs on port 4242 only and root cant log in through SSH.

**User management:** besides root there is my user which is in the sudo and user42 groups. 

**Services installed:** OpenSSH for remote access, UFW as the firewall with only port 4242 open, AppArmor running at startup, and cron to run monitoring.sh every 10 minutes, which broadcasts system info (architecture, CPU, RAM, disk usage, connections, etc.) to all terminals with wall. Bonus: lighttpd, MariaDB, PHP and WordPress were set up and are ready to be used, and fail2ban as extra service since the subject was assuming secure and hardened server.

### Comparisons

**Debian vs Rocky Linux**
Debian is a community project and is more general purpose, Rocky is a free rebuild of RHEL made for enterprise servers. Debian uses apt/.deb packages, Rocky uses dnf/.rpm. Debian is easier to start with, Rocky is closer to real company infrastructure.

**AppArmor vs SELinux**
Both are mandatory access control systems, meaning they limit what programs can do even if they run as root. AppArmor works with profiles based on file paths, so its easier to read and write rules. SELinux puts security labels on every file and process, which is more precise and more secure but also much more complicated to configure. AppArmor is the default on Debian, SELinux on Rocky.

**UFW vs firewalld**
UFW (Uncomplicated Firewall) is a simple frontend for iptables/nftables, you just allow or deny ports with one command. firewalld is more advanced, it works with zones (different trust levels for different networks) and can change rules while running without reloading everything. UFW is easier for a single machine, firewalld is better for more complex setups.

**VirtualBox vs UTM**
VirtualBox is free, made by Oracle and works on Windows, Linux and macOS, its the one the school computers have. UTM is a macOS/iOS app based on QEMU, its mostly useful on Apple Silicon Macs because it can run ARM VMs natively and emulate other architectures. i used VirtualBox because im not on a Mac.

# Instructions

### Requirements
- VirtualBox (or UTM on Apple Silicon)
- The `.vdi` disk image, which is not included in this repository

### Verify the disk image
The `signature.txt` in this repo contains the SHA1 hash of the VM disk:
```sh
sha1sum born2beroot.vdi      # Linux
shasum born2beroot.vdi       # macOS
```
The output must match `signature.txt`. Booting the VM changes the hash, so check it before the first boot.

### Run the VM
1. Create a new VM (Debian 64-bit) and attach the existing `.vdi` as its hard disk.
2. Boot it and enter the LUKS passphrase to unlock the encrypted disk.
3. Log in

### Connect over SSH
SSH listens on port 4242, and root login is disabled. With VirtualBox NAT, first add a port-forwarding rule (host 4242 → guest 4242):
```sh
ssh <login>@localhost -p 4242
```

### Monitoring
`monitoring.sh` runs from cron every 10 minutes and broadcasts system info to all terminals via `wall`. To run it manually:
```sh
sudo /usr/local/bin/monitoring.sh
```
### `wall` fix

**Why it broke:** Before, `sshd` recorded each session's terminal (e.g. `pts/0`) in `/run/utmp`, and `wall` wrote to every terminal listed there. Debian 13 no longer creates `/run/utmp` (the glibc utmp format isn't Y2038-safe). The replacement, systemd-logind, doesn't know the TTY of SSH sessions (Debian bug #1087644; `loginctl list-sessions` shows it empty), so `wall` has no way to reach them.

**The fix:** add this rule to `/etc/tmpfiles.d/utmp.conf`:

```sh
echo 'f /run/utmp 0664 root utmp -' | sudo tee /etc/tmpfiles.d/utmp.conf
sudo systemd-tmpfiles --create /etc/tmpfiles.d/utmp.conf
sudo systemctl restart ssh
```

It recreates `/run/utmp` at every boot. `sshd` writes its `pts/N` entry into it again, and `wall` reads the file directly and reaches SSH sessions. logind still shows no TTY; the fix bypasses it rather than repairing it.

**Side effect:** with I/O logging enabled, sudo adds a utmp entry for its own pty, so `sudo wall` prints twice. `Defaults !set_utmp` stops that (sudoers).

### Bonus (WordPress)
Forward host port 8080 to guest port 80, then open `http://localhost:8080`.

### Bonus (fail2ban)
Invalid password for 3 times over SSH -> IP ban for 10 minutes.
```sh
sudo fail2ban-client unban <ip> # for unban
```

# Resources

### Main Links

- [Debian installation guide (amd64)](https://www.debian.org/releases/stable/amd64/) - official guide i used for installing Debian and setting up encrypted LVM
- [pam_pwquality man page](https://linux.die.net/man/8/pam_pwquality) - options for the password strength rules (minlen, ucredit, dcredit, maxrepeat, difok, etc.)
- [login.defs man page](https://man7.org/linux/man-pages/man5/login.defs.5.html) - for password expiration settings (PASS_MAX_DAYS, PASS_MIN_DAYS, PASS_WARN_AGE)
- [MariaDB server installation guide](https://mariadb.com/docs/server/mariadb-quickstart-guides/installing-mariadb-server-guide) - installing and securing MariaDB for the WordPress bonus
- [crontab.guru examples](https://crontab.guru/examples.html) - to get the cron syntax right for running monitoring.sh every 10 minutes
- [lighttpd configuration tutorial](https://redmine.lighttpd.net/projects/lighttpd/wiki/TutorialConfiguration) - setting up lighttpd for the WordPress bonus
- [Logical vs primary partitions](https://www.experts-exchange.com/questions/27497126/What-is-the-difference-between-logical-partition-and-primary-partition.html) - to understand the difference between primary and logical partitions during partitioning
### Usage of AI
Claude Code was used as a webscraper to find a fix for `wall` because it stopped working back in 2024 and subject was never updated.
