#!/bin/bash
# Make this script executable: chmod +x script/wifiToggle.sh

# WiFi Toggle Script for Ubuntu 22.04.05 LTS
# Checks WiFi status and toggles it up/down
# Also manages USB power for the WiFi adapter if possible

INTERFACE="wlan0"

# Function to find and set the correct WiFi interface
find_wifi_interface() {
    # Try common WiFi interface names
    for iface in wlan0 wlp0s20f3 wlan1; do
        if ip link show "$iface" >/dev/null 2>&1; then
            INTERFACE="$iface"
            return 0
        fi
    done
    
    # Check for USB WiFi adapters (wlx* pattern)
    for iface in /sys/class/net/wlx*; do
        if [ -e "$iface" ]; then
            local iface_name=$(basename "$iface")
            if ip link show "$iface_name" >/dev/null 2>&1; then
                INTERFACE="$iface_name"
                return 0
            fi
        fi
    done
    
    # Try to find any wireless interface
    local wifi_iface=$(iw dev 2>/dev/null | awk '/Interface/ {print $2}' | head -1)
    if [ -n "$wifi_iface" ] && ip link show "$wifi_iface" >/dev/null 2>&1; then
        INTERFACE="$wifi_iface"
        return 0
    fi
    
    return 1
}

# Function to check if interface exists
check_interface() {
    if ! find_wifi_interface; then
        echo "Error: No WiFi interface found"
        echo "Checked: wlan0, wlp0s20f3, wlx*, wlan1, and iw dev output"
        exit 1
    fi
    echo "Using WiFi interface: $INTERFACE"
}

# Function to get current interface state
get_interface_state() {
    ip link show "$INTERFACE" | grep -q "state UP" && echo "UP" || echo "DOWN"
}

# Function to find USB device for WiFi adapter
find_usb_device() {
    # Try to find USB WiFi adapter - return full vendor:product ID
    lsusb | grep -i "wireless\|wifi\|802.11" | head -1 | awk '{print $6}'
}

# Function to control USB power
control_usb_power() {
    local action=$1
    local device_id=$(find_usb_device)

    if [ -n "$device_id" ]; then
        local vendor_id=$(echo "$device_id" | cut -d: -f1)
        local product_id=$(echo "$device_id" | cut -d: -f2)
        echo "Found WiFi USB device: $device_id"

        # Find USB device path
        for dev in /sys/bus/usb/devices/*/; do
            if [ -f "$dev/idVendor" ] && [ -f "$dev/idProduct" ] && \
               [ "$(cat "$dev/idVendor")" = "$vendor_id" ] && \
               [ "$(cat "$dev/idProduct")" = "$product_id" ]; then
                local power_control="$dev/power/control"
                if [ -f "$power_control" ]; then
                    if [ "$action" = "suspend" ]; then
                        echo "Suspending USB device for power saving..."
                        echo "auto" | sudo tee "$power_control" >/dev/null
                    else
                        echo "Resuming USB device..."
                        echo "on" | sudo tee "$power_control" >/dev/null
                        
                        # Wait and verify device is ready
                        local retry_count=0
                        while [ $retry_count -lt 10 ]; do
                            if [ -f "$power_control" ] && [ "$(cat "$power_control")" = "on" ]; then
                                echo "USB device power restored"
                                sleep 2  # Additional time for device initialization
                                return 0
                            fi
                            sleep 1
                            retry_count=$((retry_count + 1))
                        done
                        echo "Warning: USB device may not be fully ready"
                    fi
                    return 0
                fi
            fi
        done
    fi

    echo "Note: USB power control not available or device not found"
    return 1
}

# Handle command line arguments
if [ "$1" = "on" ]; then
    echo "WiFi Force ON Command"
    echo "===================="
    check_interface
    
    echo "Bringing WiFi up..."
    control_usb_power resume
    sudo ip link set dev "$INTERFACE" up
    sleep 3
    
    if systemctl is-active --quiet NetworkManager 2>/dev/null; then
        sudo systemctl restart NetworkManager
        echo "Restarted NetworkManager"
    elif systemctl is-active --quiet systemd-networkd 2>/dev/null; then
        sudo systemctl restart systemd-networkd
        echo "Restarted systemd-networkd"
    elif systemctl is-active --quiet networking 2>/dev/null; then
        sudo systemctl restart networking
        echo "Restarted networking service"
    else
        echo "No network management service found - manual WiFi configuration may be needed"
        if command -v dhclient >/dev/null 2>&1; then
            echo "Attempting DHCP renewal..."
            sudo dhclient -r "$INTERFACE" 2>/dev/null || true
            sudo dhclient "$INTERFACE" 2>/dev/null || true
        fi
    fi
    
    echo "WiFi is now UP"
    exit 0
elif [ "$1" = "off" ]; then
    echo "WiFi Force OFF Command"
    echo "======================"
    check_interface
    
    echo "Taking WiFi down..."
    sudo ip link set dev "$INTERFACE" down
    sudo iw dev "$INTERFACE" set power_save off 2>/dev/null || true
    control_usb_power suspend
    
    echo "WiFi is now DOWN"
    exit 0
fi

# Main logic for toggle
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

    # Wait and verify interface comes up
    retry_count=0
    while [ $retry_count -lt 15 ]; do
        if [ "$(get_interface_state)" = "UP" ]; then
            echo "Interface is UP"
            break
        fi
        sleep 1
        retry_count=$((retry_count + 1))
    done

    if [ "$(get_interface_state)" != "UP" ]; then
        echo "Warning: Interface failed to come up reliably"
    fi

    # Try to restart network services if available
    if systemctl is-active --quiet NetworkManager 2>/dev/null; then
        sudo systemctl restart NetworkManager
        echo "Restarted NetworkManager"
    elif systemctl is-active --quiet systemd-networkd 2>/dev/null; then
        sudo systemctl restart systemd-networkd
        echo "Restarted systemd-networkd"
    elif systemctl is-active --quiet networking 2>/dev/null; then
        sudo systemctl restart networking
        echo "Restarted networking service"
    else
        echo "No network management service found - manual WiFi configuration may be needed"
        # Try basic network restart methods
        if command -v dhclient >/dev/null 2>&1; then
            echo "Attempting DHCP renewal..."
            sudo dhclient -r "$INTERFACE" 2>/dev/null || true
            sudo dhclient "$INTERFACE" 2>/dev/null || true
        fi
    fi

    echo "WiFi is now UP"
fi

echo "Done!"