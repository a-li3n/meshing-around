#!/bin/bash
# Safe WiFi Toggle Script - Avoids full networking restart
# Usage: ./wifiToggle_safe.sh [on|off|toggle|force_on|force_off]

INTERFACE="wlan0"
USB_DEVICE="/sys/bus/usb/devices/1-1.3/power/control"

# Function to get current WiFi state
get_wifi_state() {
    if ip link show $INTERFACE | grep -q "UP"; then
        echo "UP"
    else
        echo "DOWN"
    fi
}

# Function to enable WiFi without full networking restart
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
    
    # Check if wpa_supplicant is already running for this interface
    if ! pgrep -f "wpa_supplicant.*$INTERFACE" > /dev/null; then
        sudo wpa_supplicant -B -i $INTERFACE -c /etc/wpa_supplicant/wpa_supplicant.conf 2>/dev/null
        sleep 3
    else
        echo "wpa_supplicant already running for $INTERFACE"
        sleep 1
    fi
    
    # Check if we already have an IP address
    local current_ip=$(ip addr show $INTERFACE | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
    if [ -z "$current_ip" ]; then
        echo "Requesting DHCP lease..."
        sudo dhclient $INTERFACE 2>/dev/null
        sleep 3
    else
        echo "Interface already has IP: $current_ip"
    fi
    
    sleep 1
    echo "WiFi is now $(get_wifi_state)"
}

# Function to disable WiFi
wifi_off() {
    echo "Disabling WiFi interface $INTERFACE..."
    
    # Kill any running dhclient for this interface
    sudo pkill -f "dhclient.*$INTERFACE" 2>/dev/null || true
    
    # Kill any wpa_supplicant for this interface
    sudo pkill -f "wpa_supplicant.*$INTERFACE" 2>/dev/null || true
    
    # Bring interface down
    sudo ip link set dev $INTERFACE down
    
    # Disable power save (if interface supports it) - try different paths
    sudo /usr/sbin/iw dev $INTERFACE set power_save off 2>/dev/null || \
    sudo /usr/bin/iw dev $INTERFACE set power_save off 2>/dev/null || \
    sudo iw dev $INTERFACE set power_save off 2>/dev/null || true
    
    # Disable USB device
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