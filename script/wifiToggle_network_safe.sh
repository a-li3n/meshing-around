#!/bin/bash
# Network-Preserving WiFi Toggle Script - Protects localhost connections
# Usage: ./wifiToggle_network_safe.sh [on|off|toggle|force_on|force_off]

INTERFACE="wlan0"
USB_DEVICE="/sys/bus/usb/devices/1-1.3/power/control"

# Function to get current WiFi state
get_wifi_state() {
    if ip link show $INTERFACE 2>/dev/null | grep -q "UP"; then
        echo "UP"
    else
        echo "DOWN"
    fi
}

# Function to preserve localhost routing
preserve_localhost_route() {
    # Ensure localhost route is always present
    if ! ip route show | grep -q "127.0.0.0/8"; then
        echo "Restoring localhost route..."
        sudo ip route add 127.0.0.0/8 dev lo 2>/dev/null || true
    fi
}

# Function to enable WiFi with network preservation
wifi_on() {
    echo "Enabling WiFi interface $INTERFACE..."
    
    # Save current default route before making changes
    local default_route=$(ip route show default 2>/dev/null | head -1)
    
    # Enable USB device
    if [ -f "$USB_DEVICE" ]; then
        echo "on" | sudo tee "$USB_DEVICE" > /dev/null
        sleep 2
    fi
    
    # Bring interface up
    sudo ip link set dev $INTERFACE up
    sleep 2
    
    # Preserve localhost routing
    preserve_localhost_route
    
    # Only start wpa_supplicant if not already running
    if ! pgrep -f "wpa_supplicant.*$INTERFACE" > /dev/null; then
        echo "Starting wpa_supplicant..."
        sudo wpa_supplicant -B -i $INTERFACE -c /etc/wpa_supplicant/wpa_supplicant.conf 2>/dev/null
        sleep 4
        
        # Preserve localhost routing after wpa_supplicant
        preserve_localhost_route
        
        # Check if we need DHCP
        local current_ip=$(ip addr show $INTERFACE 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
        if [ -z "$current_ip" ]; then
            echo "Requesting DHCP lease (preserving existing routes)..."
            
            # Use dhclient with options to minimize routing disruption
            sudo dhclient -1 -q $INTERFACE 2>/dev/null || echo "DHCP request failed"
            sleep 2
            
            # Restore localhost and default routes if needed
            preserve_localhost_route
            if [ -n "$default_route" ] && ! ip route show default | grep -q "$(echo "$default_route" | awk '{print $3}')"; then
                echo "Restoring default route..."
                sudo ip route add $default_route 2>/dev/null || true
            fi
        else
            echo "Interface already has IP: $current_ip"
        fi
    else
        echo "wpa_supplicant already running"
        preserve_localhost_route
        sleep 2
    fi
    
    # Final localhost route check
    preserve_localhost_route
    
    echo "WiFi is now $(get_wifi_state)"
}

# Function to disable WiFi cleanly
wifi_off() {
    echo "Disabling WiFi interface $INTERFACE..."
    
    # Preserve localhost routing before making changes
    preserve_localhost_route
    
    # Kill processes cleanly without affecting other interfaces
    sudo pkill -f "dhclient.*$INTERFACE" 2>/dev/null || true
    sudo pkill -f "wpa_supplicant.*$INTERFACE" 2>/dev/null || true
    sleep 1
    
    # Bring interface down
    sudo ip link set dev $INTERFACE down
    
    # Disable power save and USB device
    if command -v iw >/dev/null 2>&1; then
        sudo iw dev $INTERFACE set power_save off 2>/dev/null || true
    fi
    
    if [ -f "$USB_DEVICE" ]; then
        echo "auto" | sudo tee "$USB_DEVICE" > /dev/null
    fi
    
    # Ensure localhost routing is still intact
    preserve_localhost_route
    
    sleep 1
    echo "WiFi is now $(get_wifi_state)"
}

# Main logic
CURRENT_STATE=$(get_wifi_state)
echo "Current WiFi state: $CURRENT_STATE"

case "$1" in
    "on"|"force_on")
        if [ "$CURRENT_STATE" = "DOWN" ]; then
            wifi_on
        else
            echo "WiFi already UP"
        fi
        ;;
    "off"|"force_off")
        if [ "$CURRENT_STATE" = "UP" ]; then
            wifi_off
        else
            echo "WiFi already DOWN"
        fi
        ;;
    "toggle"|"")
        if [ "$CURRENT_STATE" = "UP" ]; then
            wifi_off
        else
            wifi_on
        fi
        ;;
    *)
        echo "Usage: $0 [on|off|toggle|force_on|force_off]"
        echo "Current WiFi state: $CURRENT_STATE"
        exit 1
        ;;
esac

echo "Final WiFi state: $(get_wifi_state)"
echo "Localhost connectivity check:"
ping -c 1 -W 1 127.0.0.1 >/dev/null 2>&1 && echo "Localhost OK" || echo "Localhost connectivity issue"