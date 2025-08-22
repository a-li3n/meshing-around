#!/bin/bash
# Minimal GPIO-Only WiFi Power Control Script
# Usage: ./wifiToggle_simple.sh [on|off|toggle|status]
# Only controls GPIO4 value - nothing else

GPIO_PATH="/sys/class/gpio/gpio4/value"

# Function to get current WiFi power state
get_wifi_power_state() {
    if [ -f "$GPIO_PATH" ]; then
        state=$(cat $GPIO_PATH)
        if [ "$state" = "1" ]; then
            echo "ON"
        else
            echo "OFF"
        fi
    else
        echo "UNKNOWN"
    fi
}

# Function to enable WiFi power
wifi_on() {
    echo "Setting GPIO4 to HIGH (WiFi power ON)..."
    echo "1" | sudo tee $GPIO_PATH > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo "WiFi hardware power: ON"
        return 0
    else
        echo "ERROR: Failed to set GPIO4 to HIGH"
        return 1
    fi
}

# Function to disable WiFi power
wifi_off() {
    echo "Setting GPIO4 to LOW (WiFi power OFF)..."
    echo "0" | sudo tee $GPIO_PATH > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo "WiFi hardware power: OFF"
        return 0
    else
        echo "ERROR: Failed to set GPIO4 to LOW"
        return 1
    fi
}

# Function to show status
wifi_status() {
    local power_state=$(get_wifi_power_state)
    echo "WiFi Hardware Power: $power_state"
    echo "GPIO4 Path: $GPIO_PATH"
    if [ -f "$GPIO_PATH" ]; then
        echo "GPIO4 Value: $(cat $GPIO_PATH)"
    else
        echo "ERROR: GPIO4 not accessible"
    fi
}

# Main logic
CURRENT_POWER_STATE=$(get_wifi_power_state)

case "$1" in
    "on"|"force_on")
        wifi_on
        ;;
    "off"|"force_off")
        wifi_off
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
        echo "Usage: $0 [on|off|toggle|status]"
        echo ""
        echo "Minimal GPIO4 control:"
        echo "  on     - Set GPIO4=1 (HIGH)"
        echo "  off    - Set GPIO4=0 (LOW)"  
        echo "  toggle - Toggle GPIO4 value"
        echo "  status - Show current GPIO4 value"
        wifi_status
        exit 1
        ;;
esac