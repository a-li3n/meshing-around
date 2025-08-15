#!/bin/bash
# WiFi Diagnostic Script
# Run this to diagnose WiFi connectivity issues after turning WiFi on

echo "WiFi Diagnostic Report"
echo "====================="
date

echo -e "\n1. Interface Status:"
ip link show wlan0

echo -e "\n2. IP Address Assignment:"
ip addr show wlan0

echo -e "\n3. Routing Table:"
ip route show

echo -e "\n4. DNS Configuration:"
cat /etc/resolv.conf

echo -e "\n5. WiFi Connection Details:"
if command -v iw >/dev/null 2>&1; then
    iw dev wlan0 link
else
    echo "iw not installed"
fi

echo -e "\n6. DHCP Process Status:"
ps aux | grep dhclient | grep -v grep

echo -e "\n7. WPA Supplicant Status:"
ps aux | grep wpa_supplicant | grep -v grep

echo -e "\n8. Network Connectivity Tests:"
echo "Ping gateway:"
gateway=$(ip route | grep default | awk '{print $3}' | head -1)
if [ -n "$gateway" ]; then
    ping -c 3 "$gateway" 2>&1 || echo "Gateway ping failed"
else
    echo "No default gateway found"
fi

echo -e "\nPing Google DNS:"
ping -c 3 8.8.8.8 2>&1 || echo "Internet ping failed"

echo -e "\n9. Firewall Status:"
if command -v ufw >/dev/null 2>&1; then
    ufw status
else
    echo "UFW not installed"
fi

echo -e "\n10. Network Manager Status:"
if systemctl is-active --quiet NetworkManager 2>/dev/null; then
    echo "NetworkManager: Active"
elif systemctl is-active --quiet systemd-networkd 2>/dev/null; then 
    echo "systemd-networkd: Active"
elif systemctl is-active --quiet networking 2>/dev/null; then
    echo "networking: Active"  
else
    echo "No network manager found active"
fi

echo -e "\nDiagnostic complete."