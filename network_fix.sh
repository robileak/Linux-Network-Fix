#!/bin/bash

# Kali Linux Network Fix Script
# Save this as network_fix.sh and run: sudo bash network_fix.sh

echo "=========================================="
echo "    Kali Linux Network Fix Script"
echo "=========================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run as root: sudo bash $0"
    exit 1
fi

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to check success
check_success() {
    if [ $? -eq 0 ]; then
        echo "✅ $1"
    else
        echo "❌ $1"
    fi
}

log "Starting network troubleshooting..."

# Step 1: Stop potentially conflicting services
log "Stopping conflicting services..."
systemctl stop wicd 2>/dev/null
systemctl stop network-manager 2>/dev/null
systemctl stop networking 2>/dev/null
check_success "Stopped conflicting services"

# Step 2: Reset network interfaces
log "Resetting network interfaces..."
interfaces=$(ip link show | grep -E "^[0-9]+:" | grep -v "lo:" | cut -d: -f2 | tr -d ' ')

for interface in $interfaces; do
    log "Resetting interface: $interface"
    ip link set $interface down 2>/dev/null
    sleep 2
    ip link set $interface up 2>/dev/null
    sleep 2
done
check_success "Network interfaces reset"

# Step 3: Restart NetworkManager
log "Restarting NetworkManager..."
systemctl start NetworkManager
sleep 5
systemctl restart NetworkManager
sleep 5
check_success "NetworkManager restarted"

# Step 4: Fix DNS configuration
log "Configuring DNS servers..."
cat > /etc/resolv.conf << EOF
nameserver 8.8.8.8
nameserver 1.1.1.1
nameserver 8.8.4.4
nameserver 1.0.0.1
search localdomain
options edns0 trust-ad
EOF

chattr +i /etc/resolv.conf 2>/dev/null
check_success "DNS configured"

# Step 5: Flush all network caches
log "Flushing network caches..."
ip route flush cache 2>/dev/null
nscd -i hosts 2>/dev/null
systemctl restart systemd-resolved 2>/dev/null
check_success "Network caches flushed"

# Step 6: Request new DHCP lease
log "Requesting new DHCP leases..."
for interface in $interfaces; do
    if [ "$interface" != "lo" ]; then
        dhclient -r $interface 2>/dev/null
        dhclient $interface 2>/dev/null &
        log "  - Renewed DHCP for $interface"
    fi
done
sleep 3
check_success "DHCP leases renewed"

# Step 7: Reset firewall rules
log "Resetting firewall..."
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
check_success "Firewall reset"

# Step 8: Start essential services
log "Starting essential network services..."
systemctl enable NetworkManager 2>/dev/null
systemctl start NetworkManager 2>/dev/null
systemctl restart networking 2>/dev/null
check_success "Network services started"

# Wait for network to stabilize
log "Waiting for network stabilization..."
sleep 10

# Step 9: Diagnostic tests
echo ""
echo "=========================================="
echo "        Network Diagnostic Results"
echo "=========================================="

# Test 1: Check interfaces
log "Network Interfaces:"
ip addr show | grep -E "^([0-9]+:|inet )"

# Test 2: Check gateway
log "Default Gateway:"
ip route show default 2>/dev/null || echo "No default route found"

# Test 3: Test basic connectivity
log "Testing connectivity to Google DNS..."
if ping -c 3 -W 2 8.8.8.8 &>/dev/null; then
    echo "✅ Internet connectivity: OK"
else
    echo "❌ Internet connectivity: FAILED"
fi

# Test 4: Test DNS resolution
log "Testing DNS resolution..."
if nslookup google.com 8.8.8.8 &>/dev/null; then
    echo "✅ DNS resolution: OK"
else
    echo "❌ DNS resolution: FAILED"
fi

# Test 5: Test HTTP connectivity
log "Testing HTTP connectivity..."
if curl -I --connect-timeout 10 https://www.google.com &>/dev/null; then
    echo "✅ HTTP/HTTPS connectivity: OK"
else
    echo "❌ HTTP/HTTPS connectivity: FAILED"
fi

# Final status
echo ""
echo "=========================================="
echo "              Final Status"
echo "=========================================="

if ping -c 1 -W 2 google.com &>/dev/null; then
    echo "🎉 NETWORK FIXED! You should now be able to browse."
    echo "🔧 If still having issues, try rebooting: sudo reboot"
else
    echo "⚠️  Some issues remain. Try these additional steps:"
    echo "   1. Check physical connection/WiFi"
    echo "   2. Reboot your system: sudo reboot"
    echo "   3. Check router/modem settings"
fi

echo ""
echo "Script completed at: $(date)"