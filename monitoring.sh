#	/usr/local/sbin/monitoring.sh is reasonable location for this.
#!/usr/bin/env bash
set -euo pipefail

cpuload=$(LC_ALL=C top -bn2 -d1 | grep -F 'Cpu(s)' | tail -1 | awk -F, '{printf "%.1f%%\n", 100-$4}')
ramtotal=$(free -m | grep -i mem | awk '{print $2}')
ramavail=$(free -m | grep -i mem | awk '{print $7}')
ramused=$(free -m | grep -i mem | awk '{print $3}')
ramperc=$(awk -v t="$ramtotal" -v a="$ramavail" 'BEGIN {printf "%.1f", (t - a) * 100 / t}')
ipaddr=$(ip route get 1 | grep -oP 'src \K\S+')
macaddr=$(cat /sys/class/net/$(ip route get 1 | grep -oP 'dev \K\S+')/address)

TMPFILE="$(mktemp /tmp/wallmsg.XXXXXX)"
trap 'rm -f "$TMPFILE"' EXIT

cat > "$TMPFILE" <<EOF
	#Architecture: $(uname -a)
	#CPU physical: $(grep '^physical id' /proc/cpuinfo | sort -u | wc -l)
	#vCPU: $(nproc)
	#Memory Usage: $(echo "${ramused}/${ramtotal}MB (${ramperc}%)")
	#Disk Usage: $(df -h / | tail -1 | awk '{print $3"/"$2" ("$5")"}')
	#CPU load: $cpuload
	#Last boot: $(uptime -s | cut -c1-16)
	#LVM use: $(/usr/sbin/lvdisplay | grep -E 'LV Status\s+available' >/dev/null && echo yes || echo no)
	#Connection TCP: $(ss -Htn state established | wc -l) ESTABLISHED
	#User log: $(loginctl list-users --no-legend | wc -l)
	#Network: $(echo "IP ${ipaddr} (${macaddr})")
	#Sudo: $(grep -c "COMMAND" /var/log/sudo/sudo.log) cmd
EOF

wall < "$TMPFILE"
