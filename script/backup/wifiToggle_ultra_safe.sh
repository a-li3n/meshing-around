#!/bin/bash
# Ultra-Safe WiFi Toggle Script - Minimal network disruption
# Usage: ./wifiToggle_ultra_safe.sh [on|off|toggle|force_on|force_off]

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

# Function to enable WiFi with minimal network disruption
wifi_on() {
    echo "Enabling WiFi interface $INTERFACE..."
    
    # Enable USB device
    if [ -f "$USB_DEVICE" ]; then
        echo "on" | sudo tee "$USB_DEVICE" > /dev/null
        sleep 2
    fi
    
    # Bring interface up
    sudo ip link set dev $INTERFACE up
    sleep 2
    
    # Only start wpa_supplicant if not already running
    if ! pgrep -f "wpa_supplicant.*$INTERFACE" > /dev/null; then
        echo "Starting wpa_supplicant..."
        sudo wpa_supplicant -B -i $INTERFACE -c /etc/wpa_supplicant/wpa_supplicant.conf 2>/dev/null
        sleep 4
        
        # Only request DHCP if we don't have an IP
        local current_ip=$(ip addr show $INTERFACE 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
        if [ -z "$current_ip" ]; then
            echo "Requesting DHCP lease..."
            # Use timeout to prevent hanging
            timeout 10 sudo dhclient $INTERFACE 2>/dev/null || echo "DHCP request timed out"
            sleep 2
        else
            echo "Interface already has IP: $current_ip"
        fi
    else
        echo "wpa_supplicant already running, WiFi should connect automatically"
        sleep 2
    fi
    
    echo "WiFi is now $(get_wifi_state)"
}

# Function to disable WiFi cleanly
wifi_off() {
    echo "Disabling WiFi interface $INTERFACE..."
    
    # First release DHCP lease to be clean
    sudo dhclient -r $INTERFACE 2>/dev/null || true
    sleep 1
    
    # Kill processes cleanly
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