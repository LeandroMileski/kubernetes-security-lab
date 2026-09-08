#!/bin/bash
set -e

VM_IP="$1"
if [ -z "$VM_IP" ]; then
  echo "Usage: $0 <vm-private-ip>"
  exit 1
fi

ANCHOR_FILE="/etc/pf-anchors/cks-lab.conf"
PFCONF="/etc/pf.conf"
BACKUP="/etc/pf.conf.backup-ckslab"

sudo mkdir -p /etc/pf-anchors

sudo tee "$ANCHOR_FILE" > /dev/null << RULES
rdr pass on en0 proto tcp from any to any port 6443 -> ${VM_IP} port 6443
rdr pass on en0 proto udp from any to any port 4789 -> ${VM_IP} port 4789
rdr pass on en0 proto tcp from any to any port 10250 -> ${VM_IP} port 10250
RULES

if [ ! -f "$BACKUP" ]; then
  sudo cp "$PFCONF" "$BACKUP"
  echo "Backed up original pf.conf to $BACKUP"
fi

if ! grep -q 'rdr-anchor "cks-lab"' "$PFCONF"; then
  sudo cp "$BACKUP" "$PFCONF"
  sudo sed -i '' '/rdr-anchor "com.apple\/\*"/a\
rdr-anchor "cks-lab"
' "$PFCONF"
  sudo sed -i '' '/load anchor "com.apple" from/a\
load anchor "cks-lab" from "/etc/pf-anchors/cks-labcl' "$PFCONF"
fi

sudo sysctl -w net.inet.ip.forwarding=1
sudo pfctl -ef "$PFCONF" 2>&1 | grep -v "^No ALTQ" | grep -v "^ALTQ related" || true

echo "Forwarding active: Mac's en0 -> ${VM_IP} (ports 6443, 4789/udp, 10250)"
