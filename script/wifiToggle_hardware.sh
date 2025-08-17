#!/bin/bash
# Hardware WiFi Power Control Script - Uses TPS61023 boost converter
# Usage: ./wifiToggle_hardware.sh [on|off|toggle|force_on|force_off]

INTERFACE="wlan0"
GPIO_PIN=4
GPIO_PATH="/sys/class/gpio/gpio4"
WPA_CONF="/etc/wpa_supplicant/wpa_supplicant.conf"

# Function to setup GPIO if needed
setup_gpio() {
    if [ ! -d "$GPIO_PATH" ]; then
        echo "$GPIO_PIN" > /sys/class/gpio/export 2>/dev/null
        sleep 0.2
    fi
    echo "out" > ${GPIO_PATH}/direction 2>/dev/null
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
    echo "1" > ${GPIO_PATH}/value
    echo "WiFi power enabled via GPIO"
    
    # Wait for USB enumeration
    echo "Waiting for USB enumeration..."
    sleep 3
    
    # Wait for interface to appear
    for i in {1..10}; do
        if ip link show $INTERFACE >/dev/null 2>&1; then
            echo "Interface $INTERFACE detected"
            break
        fi
        echo "Waiting for interface... ($i/10)"
        sleep 1
    done
    
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
    echo "0" > ${GPIO_PATH}/value
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