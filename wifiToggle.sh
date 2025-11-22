#!/bin/bash

# WiFi Toggle Script for Ubuntu 22.04.05 LTS
# Checks WiFi status and toggles it up/down
# Also manages USB power for the WiFi adapter if possible

INTERFACE="wlan0"

# Function to check if interface exists
check_interface() {
    if ! ip link show "$INTERFACE" >/dev/null 2>&1; then
        echo "Error: Interface $INTERFACE not found"
        exit 1
    fi
}

# Function to get current interface state
get_interface_state() {
    ip link show "$INTERFACE" | grep -q "state UP" && echo "UP" || echo "DOWN"
}

# Function to find USB device for WiFi adapter
find_usb_device() {
    # Try to find USB WiFi adapter
    lsusb | grep -i "wireless\|wifi\|802.11" | head -1 | awk '{print $6}' | cut -d: -f1
}

# Function to control USB power
control_usb_power() {
    local action=$1
    local vendor_id=$(find_usb_device)

    if [ -n "$vendor_id" ]; then
        echo "Found WiFi USB device with vendor ID: $vendor_id"

        # Find USB device path
        for dev in /sys/bus/usb/devices/*/; do
            if [ -f "$dev/idVendor" ] && [ "$(cat "$dev/idVendor")" = "$vendor_id" ]; then
                local power_control="$dev/power/control"
                if [ -f "$power_control" ]; then
                    if [ "$action" = "suspend" ]; then
                        echo "Suspending USB device for power saving..."
                        echo "auto" | sudo tee "$power_control" >/dev/null
                    else
                        echo "Resuming USB device..."
                        echo "on" | sudo tee "$power_control" >/dev/null
                        sleep 2  # Give device time to initialize
                    fi
                    return 0
                fi
            fi
        done
    fi

    echo "Note: USB power control not available or device not found"
    return 1
}

# Main logic
echo "WiFi Toggle Script"
echo "=================="

check_interface

current_state=$(get_interface_state)
echo "Current WiFi state: $current_state"

if [ "$current_state" = "UP" ]; then
    echo "Taking WiFi down..."
    sudo ip link set dev "$INTERFACE" down

    # Disable WiFi power management and suspend USB if possible
    sudo iw dev "$INTERFACE" set power_save off 2>/dev/null || true
    control_usb_power suspend

    echo "WiFi is now DOWN"
else
    echo "Bringing WiFi up..."

    # Resume USB power first
    control_usb_power resume

    sudo ip link set dev "$INTERFACE" up

    # Wait a moment for the interface to come up
    sleep 3

    # Try to restart NetworkManager or systemd-networkd
    if systemctl is-active --quiet NetworkManager; then
        sudo systemctl restart NetworkManager
        echo "Restarted NetworkManager"
    elif systemctl is-active --quiet systemd-networkd; then
        sudo systemctl restart systemd-networkd
        echo "Restarted systemd-networkd"
    fi

    echo "WiFi is now UP"
fi

echo "Done!"