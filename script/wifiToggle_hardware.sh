#!/bin/bash
# Hardware WiFi Power Control Script - Uses TPS61023 boost converter
# Usage: ./wifiToggle_hardware.sh [on|off|toggle|force_on|force_off]

INTERFACE="wlan0"
GPIO_PIN=4
GPIO_PATH="/sys/class/gpio/gpio4"
WPA_CONF="/etc/wpa_supplicant/wpa_supplicant.conf"

# Function to setup GPIO if needed
setup_gpio() {
    echo "Setting up GPIO $GPIO_PIN..."
    
    if [ ! -d "$GPIO_PATH" ]; then
        echo "Exporting GPIO $GPIO_PIN..."
        echo "$GPIO_PIN" > /sys/class/gpio/export 2>/dev/null
        if [ $? -ne 0 ]; then
            echo "ERROR: Failed to export GPIO $GPIO_PIN"
            return 1
        fi
        sleep 0.5
    fi
    
    echo "Setting GPIO direction to output..."
    echo "out" | sudo tee ${GPIO_PATH}/direction > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to set GPIO direction"
        return 1
    fi
    
    echo "GPIO $GPIO_PIN setup complete"
    echo "GPIO permissions: $(ls -la ${GPIO_PATH}/value 2>/dev/null || echo 'PERMISSION CHECK FAILED')"
}

# Function to get current WiFi power state
get_wifi_power_state() {
    if [ -f "${GPIO_PATH}/value" ]; then
        state=$(cat ${GPIO_PATH}/value)
        if [ "$state" = "1" ]; then
            echo "ON"
        else
            echo "OFF"
        fi
    else
        echo "UNKNOWN"
    fi
}

# Function to get WiFi interface state
get_wifi_interface_state() {
    if ip link show $INTERFACE 2>/dev/null | grep -q "UP"; then
        echo "UP"
    else
        echo "DOWN"
    fi
}

# Function to enable WiFi with hardware power control
wifi_on() {
    echo "Enabling WiFi hardware power..."
    
    # Setup GPIO if needed
    setup_gpio
    
    # Power on TPS61023 boost converter
    echo "Attempting to set GPIO to HIGH..."
    echo "1" | sudo tee ${GPIO_PATH}/value > /dev/null 2>&1
    GPIO_RESULT=$?
    
    if [ $GPIO_RESULT -ne 0 ]; then
        echo "ERROR: Failed to write to GPIO (exit code: $GPIO_RESULT)"
        echo "Checking GPIO permissions..."
        ls -la ${GPIO_PATH}/value
        echo "Checking GPIO ownership..."
        ls -la ${GPIO_PATH}/
        return 1
    fi
    
    echo "WiFi power enabled via GPIO"
    
    # Verify GPIO was actually set
    sleep 0.5
    ACTUAL_VALUE=$(cat ${GPIO_PATH}/value 2>/dev/null)
    echo "GPIO verification - Expected: 1, Actual: $ACTUAL_VALUE"
    
    if [ "$ACTUAL_VALUE" != "1" ]; then
        echo "ERROR: GPIO value verification failed!"
        echo "GPIO may not be controlling the boost converter properly"
        return 1
    fi
    
    # Wait for USB enumeration
    echo "Waiting for USB enumeration..."
    sleep 5  # Increased from 3 to 5 seconds
    
    # Check if GPIO is actually set
    echo "GPIO status: $(cat ${GPIO_PATH}/value 2>/dev/null || echo 'ERROR')"
    
    # Wait for interface to appear
    for i in {1..15}; do  # Increased from 10 to 15 attempts
        if ip link show $INTERFACE >/dev/null 2>&1; then
            echo "Interface $INTERFACE detected"
            break
        fi
        echo "Waiting for interface... ($i/15)"
        sleep 2  # Increased from 1 to 2 seconds between checks
    done
    
    # Check if we found the interface
    if ! ip link show $INTERFACE >/dev/null 2>&1; then
        echo "ERROR: Interface $INTERFACE never appeared!"
        echo "Available interfaces:"
        ip link show | grep -E "^[0-9]+:" | cut -d: -f2 | tr -d ' '
        echo "USB devices:"
        lsusb 2>/dev/null || echo "lsusb command failed"
        return 1
    fi
    
    # Bring interface up
    echo "Bringing interface up..."
    sudo ip link set $INTERFACE up
    sleep 2
    
    # Kill any existing wpa_supplicant for clean start
    sudo pkill -f "wpa_supplicant.*$INTERFACE" 2>/dev/null || true
    sleep 1
    
    # Start wpa_supplicant
    if [ -f "$WPA_CONF" ]; then
        echo "Starting wpa_supplicant..."
        sudo wpa_supplicant -B -i $INTERFACE -c $WPA_CONF 2>/dev/null
        
        # Wait for association
        echo "Waiting for WiFi association..."
        for i in {1..15}; do
            if iw dev $INTERFACE link 2>/dev/null | grep -q "Connected"; then
                echo "WiFi associated successfully"
                break
            fi
            sleep 1
        done
        
        # Get IP via DHCP
        echo "Requesting DHCP lease..."
        sudo dhclient $INTERFACE 2>/dev/null || echo "DHCP request failed"
        sleep 2
        
    else
        echo "Warning: $WPA_CONF not found"
    fi
    
    # Verify connection
    local ip_addr=$(ip addr show $INTERFACE 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
    if [ -n "$ip_addr" ]; then
        echo "WiFi connected successfully with IP: $ip_addr"
    else
        echo "Warning: WiFi powered on but no IP address assigned"
    fi
    
    echo "WiFi hardware power: $(get_wifi_power_state)"
    echo "WiFi interface state: $(get_wifi_interface_state)"
}

# Function to disable WiFi with hardware power control
wifi_off() {
    echo "Disabling WiFi hardware power..."
    
    # Setup GPIO if needed
    setup_gpio
    
    # Power off TPS61023 boost converter (hardware power cut)
    # No software cleanup needed - hardware cut handles everything
    echo "0" | sudo tee ${GPIO_PATH}/value > /dev/null
    echo "WiFi power disabled via GPIO - hardware power cut"
    
    sleep 1
    echo "WiFi hardware power: $(get_wifi_power_state)"
}

# Function to check WiFi connection status
wifi_status() {
    local power_state=$(get_wifi_power_state)
    local interface_state=$(get_wifi_interface_state)
    
    echo "WiFi Hardware Power: $power_state"
    echo "WiFi Interface State: $interface_state"
    
    if [ "$power_state" = "ON" ] && ip link show $INTERFACE >/dev/null 2>&1; then
        local ip_addr=$(ip addr show $INTERFACE 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
        if [ -n "$ip_addr" ]; then
            echo "IP Address: $ip_addr"
            if command -v iw >/dev/null 2>&1; then
                echo "Connection Status:"
                iw dev $INTERFACE link 2>/dev/null || echo "No connection info available"
            fi
        else
            echo "No IP address assigned"
        fi
    fi
}

# Main logic
CURRENT_POWER_STATE=$(get_wifi_power_state)
echo "Current WiFi hardware power: $CURRENT_POWER_STATE"

case "$1" in
    "on"|"force_on")
        if [ "$CURRENT_POWER_STATE" = "OFF" ]; then
            wifi_on
        else
            echo "WiFi hardware power already ON"
            wifi_status
        fi
        ;;
    "off"|"force_off")
        if [ "$CURRENT_POWER_STATE" = "ON" ]; then
            wifi_off
        else
            echo "WiFi hardware power already OFF"
        fi
        ;;
    "toggle"|"")
        if [ "$CURRENT_POWER_STATE" = "ON" ]; then
            wifi_off
        else
            wifi_on
        fi
        ;;
    "status")
        wifi_status
        ;;
    *)
        echo "Usage: $0 [on|off|toggle|force_on|force_off|status]"
        wifi_status
        exit 1
        ;;
esac

echo "Final WiFi hardware power: $(get_wifi_power_state)"