#!/bin/bash
# Simplified Hardware WiFi Power Control - GPIO Only
# Usage: ./wifiToggle_hardware.sh [on|off|toggle|force_on|force_off|status]

GPIO_PIN=4
GPIO_PATH="/sys/class/gpio/gpio4"

# Minimal GPIO setup - only if GPIO not already exported
setup_gpio_if_needed() {
    if [ ! -d "$GPIO_PATH" ]; then
        echo "Exporting GPIO $GPIO_PIN..."
        echo "$GPIO_PIN" > /sys/class/gpio/export 2>/dev/null
        sleep 0.1
        
        # Set direction only if newly exported
        echo "Setting GPIO direction to output..."
        echo "out" > ${GPIO_PATH}/direction 2>/dev/null
        
        if [ $? -ne 0 ]; then
            echo "ERROR: Failed to setup GPIO $GPIO_PIN"
            return 1
        fi
    fi
    
    # Check if direction is already set (may be persistent)
    if [ -f "${GPIO_PATH}/direction" ]; then
        current_direction=$(cat ${GPIO_PATH}/direction 2>/dev/null)
        if [ "$current_direction" != "out" ]; then
            echo "Setting GPIO direction to output..."
            echo "out" > ${GPIO_PATH}/direction 2>/dev/null
        fi
    fi
}

# Get current power state
get_power_state() {
    if [ -f "${GPIO_PATH}/value" ]; then
        local state=$(cat ${GPIO_PATH}/value 2>/dev/null)
        [ "$state" = "1" ] && echo "ON" || echo "OFF"
    else
        echo "UNKNOWN"
    fi
}

# Main logic
case "$1" in
    "on"|"force_on")
        echo "Enabling WiFi hardware power..."
        setup_gpio_if_needed
        
        # Power on TPS61023 boost converter
        echo "1" | sudo tee ${GPIO_PATH}/value > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo "ERROR: Failed to set GPIO HIGH"
            exit 1
        fi
        
        # Create intent file for watchdog service
        echo "$(date +%s)" > /tmp/wifi_intent
        
        # Verify GPIO was set
        sleep 0.1
        actual_value=$(cat ${GPIO_PATH}/value 2>/dev/null)
        echo "WiFi hardware power: ON (GPIO: $actual_value)"
        ;;
        
    "off"|"force_off")
        echo "Disabling WiFi hardware power..."
        setup_gpio_if_needed
        
        # Power off TPS61023 boost converter (hardware power cut)
        echo "0" | sudo tee ${GPIO_PATH}/value > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo "ERROR: Failed to set GPIO LOW" 
            exit 1
        fi
        
        # Remove intent file to signal watchdog WiFi should be off
        rm -f /tmp/wifi_intent
        
        echo "WiFi hardware power: OFF"
        ;;
        
    "toggle"|"")
        setup_gpio_if_needed
        current_state=$(get_power_state)
        
        if [ "$current_state" = "ON" ]; then
            echo "0" | sudo tee ${GPIO_PATH}/value > /dev/null 2>&1
            rm -f /tmp/wifi_intent
            echo "WiFi hardware power: OFF"
        else
            echo "1" | sudo tee ${GPIO_PATH}/value > /dev/null 2>&1
            echo "$(date +%s)" > /tmp/wifi_intent
            actual_value=$(cat ${GPIO_PATH}/value 2>/dev/null)
            echo "WiFi hardware power: ON (GPIO: $actual_value)"
        fi
        ;;
        
    "status")
        setup_gpio_if_needed
        power_state=$(get_power_state)
        echo "WiFi Hardware Power: $power_state"
        
        if [ "$power_state" = "ON" ]; then
            # Check if WiFi interface exists (non-intrusive check)
            if ip link show wlan0 >/dev/null 2>&1; then
                echo "WiFi Interface: Present"
                local ip_addr=$(ip addr show wlan0 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
                if [ -n "$ip_addr" ]; then
                    echo "IP Address: $ip_addr"
                else
                    echo "IP Address: Not assigned"
                fi
            else
                echo "WiFi Interface: Not detected (may still be initializing)"
            fi
        else
            echo "WiFi Interface: Powered off"
        fi
        
        # Show intent file status
        if [ -f "/tmp/wifi_intent" ]; then
            local intent_time=$(cat /tmp/wifi_intent 2>/dev/null)
            local current_time=$(date +%s)
            local time_diff=$((current_time - intent_time))
            echo "WiFi Intent: Active (${time_diff}s ago)"
        else
            echo "WiFi Intent: None"
        fi
        ;;
        
    *)
        echo "Usage: $0 [on|off|toggle|force_on|force_off|status]"
        echo ""
        echo "Current status:"
        $0 status
        exit 1
        ;;
esac