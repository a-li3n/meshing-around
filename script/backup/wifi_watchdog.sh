#!/bin/bash
# WiFi Connection Watchdog
# Monitors WiFi connection and attempts reconnection ONLY when hardware is intentionally powered on
# Usage: Run this as a background service or cron job

INTERFACE="wlan0"
PING_TARGET="8.8.8.8"  # Google DNS
WPA_CONF="/etc/wpa_supplicant/wpa_supplicant.conf"
INTENT_FILE="/tmp/wifi_intent"  # File that indicates WiFi should be on
GPIO_PATH="/sys/class/gpio/gpio4/value"
MAX_RECONNECT_ATTEMPTS=3
RECONNECT_ATTEMPT_FILE="/tmp/wifi_reconnect_attempts"

# Check if hardware GPIO control is available
check_hardware_available() {
    [ -f "$GPIO_PATH" ] && [ -r "$GPIO_PATH" ]
}

# Check if interface is powered via GPIO
check_gpio_power() {
    if check_hardware_available; then
        local gpio_state=$(cat "$GPIO_PATH" 2>/dev/null)
        [ "$gpio_state" = "1" ]
    else
        false
    fi
}

# Check if WiFi is intentionally supposed to be on
check_wifi_intent() {
    # WiFi should be on if:
    # 1. GPIO is HIGH (hardware powered on)
    # 2. Intent file exists (recent intentional power-on)
    
    if check_gpio_power; then
        # GPIO is on - create/update intent file with timestamp
        echo "$(date +%s)" > "$INTENT_FILE"
        return 0
    elif [ -f "$INTENT_FILE" ]; then
        # GPIO is off but check if intent file is recent (within 30 seconds)
        # This handles brief GPIO state changes during reconnection
        local intent_time=$(cat "$INTENT_FILE" 2>/dev/null || echo "0")
        local current_time=$(date +%s)
        local time_diff=$((current_time - intent_time))
        
        if [ "$time_diff" -lt 30 ]; then
            echo "$(date): GPIO off but recent intent detected ($time_diff seconds ago)"
            return 0
        else
            # Intent file is old - remove it
            rm -f "$INTENT_FILE"
            return 1
        fi
    else
        # No GPIO power and no intent file
        return 1
    fi
}

# Check if we have network connectivity
check_connectivity() {
    ping -c 1 -W 5 "$PING_TARGET" >/dev/null 2>&1
}

# Check if interface has IP
check_ip() {
    ip addr show $INTERFACE 2>/dev/null | grep -q 'inet '
}

# Check if interface exists and is up
check_interface_exists() {
    ip link show $INTERFACE >/dev/null 2>&1
}

# Get current reconnection attempt count
get_attempt_count() {
    if [ -f "$RECONNECT_ATTEMPT_FILE" ]; then
        cat "$RECONNECT_ATTEMPT_FILE" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Set reconnection attempt count
set_attempt_count() {
    echo "$1" > "$RECONNECT_ATTEMPT_FILE"
}

# Reset reconnection attempt count
reset_attempt_count() {
    rm -f "$RECONNECT_ATTEMPT_FILE"
}

# Attempt reconnection
reconnect_wifi() {
    local attempts=$(get_attempt_count)
    attempts=$((attempts + 1))
    
    if [ "$attempts" -gt "$MAX_RECONNECT_ATTEMPTS" ]; then
        echo "$(date): Max reconnection attempts ($MAX_RECONNECT_ATTEMPTS) reached. Giving up."
        echo "$(date): Will retry after 30 minutes or next power cycle."
        set_attempt_count 0
        sleep 1800  # Wait 30 minutes before trying again
        return 1
    fi
    
    echo "$(date): Attempting WiFi reconnection (attempt $attempts/$MAX_RECONNECT_ATTEMPTS)..."
    set_attempt_count "$attempts"
    
    # Kill existing processes
    sudo pkill -f "wpa_supplicant.*$INTERFACE" 2>/dev/null || true
    sudo pkill -f "dhclient.*$INTERFACE" 2>/dev/null || true
    sleep 2
    
    # Verify interface still exists
    if ! check_interface_exists; then
        echo "$(date): Interface $INTERFACE not found. Hardware may need power cycle."
        return 1
    fi
    
    # Bring interface up
    sudo ip link set $INTERFACE up 2>/dev/null
    sleep 2
    
    # Restart wpa_supplicant
    if [ -f "$WPA_CONF" ]; then
        sudo wpa_supplicant -B -i $INTERFACE -c $WPA_CONF 2>/dev/null
        if [ $? -ne 0 ]; then
            echo "$(date): Failed to start wpa_supplicant"
            return 1
        fi
    else
        echo "$(date): WPA configuration file not found: $WPA_CONF"
        return 1
    fi
    
    # Wait for association
    sleep 8
    
    # Request new DHCP lease
    sudo dhclient $INTERFACE 2>/dev/null
    sleep 5
    
    # Verify connection
    if check_connectivity; then
        echo "$(date): WiFi reconnection successful"
        reset_attempt_count  # Reset counter on success
        return 0
    else
        echo "$(date): WiFi reconnection attempt $attempts failed"
        return 1
    fi
}

# Main watchdog loop
main() {
    echo "$(date): WiFi watchdog started (PID: $$)"
    echo "$(date): Monitoring interface: $INTERFACE"
    echo "$(date): GPIO control path: $GPIO_PATH"
    
    # Verify hardware is available
    if ! check_hardware_available; then
        echo "$(date): ERROR: GPIO hardware control not available at $GPIO_PATH"
        echo "$(date): Watchdog cannot function without hardware control. Exiting."
        exit 1
    fi
    
    while true; do
        if check_wifi_intent; then
            # WiFi should be on - check if it's working
            if check_interface_exists; then
                if check_connectivity; then
                    # Everything working - reset attempt counter
                    reset_attempt_count
                elif check_ip; then
                    echo "$(date): Interface has IP but no internet connectivity"
                    # Try a simple reconnection without full restart
                    sudo dhclient -r $INTERFACE 2>/dev/null || true
                    sleep 2
                    sudo dhclient $INTERFACE 2>/dev/null
                else
                    echo "$(date): Interface exists but no IP. Attempting reconnection..."
                    reconnect_wifi
                fi
            else
                echo "$(date): WiFi interface missing despite GPIO power. Attempting reconnection..."
                reconnect_wifi
            fi
        else
            # WiFi should be off - reset counters and clean up
            reset_attempt_count
            rm -f "$INTENT_FILE"
            # Don't spam logs when WiFi is intentionally off
        fi
        
        # Check every 2 minutes when WiFi should be on, every 5 minutes when off
        if check_wifi_intent; then
            sleep 120  # 2 minutes
        else
            sleep 300  # 5 minutes
        fi
    done
}

# Handle signals gracefully
cleanup() {
    echo "$(date): WiFi watchdog shutting down..."
    rm -f "$INTENT_FILE" "$RECONNECT_ATTEMPT_FILE"
    exit 0
}

trap cleanup SIGTERM SIGINT

# Run if called directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi