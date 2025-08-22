#!/bin/bash
# Debug wpa_supplicant configuration issues

INTERFACE="wlan0"
WPA_CONF="/etc/wpa_supplicant/wpa_supplicant.conf"

echo "=== WiFi Configuration Debug ==="
echo "Interface: $INTERFACE"
echo "Config file: $WPA_CONF"
echo ""

# Check if config file exists
if [ ! -f "$WPA_CONF" ]; then
    echo "❌ Config file does not exist: $WPA_CONF"
    exit 1
else
    echo "✅ Config file exists"
fi

# Check interface exists
if ! ip link show $INTERFACE >/dev/null 2>&1; then
    echo "❌ Interface $INTERFACE does not exist"
    echo "Available interfaces:"
    ip link show | grep -E "^[0-9]+:" | cut -d: -f2 | tr -d ' '
    exit 1
else
    echo "✅ Interface $INTERFACE exists"
fi

echo ""
echo "=== Testing wpa_supplicant drivers ==="

# Test nl80211 driver
echo "Testing nl80211 driver..."
if sudo timeout 5 wpa_supplicant -c $WPA_CONF -i $INTERFACE -D nl80211 -t 2>/dev/null; then
    echo "✅ nl80211 driver: Configuration VALID"
    NL80211_OK=true
else
    echo "❌ nl80211 driver: Configuration INVALID or driver not supported"
    NL80211_OK=false
fi

# Test wext driver
echo "Testing wext driver..."
if sudo timeout 5 wpa_supplicant -c $WPA_CONF -i $INTERFACE -D wext -t 2>/dev/null; then
    echo "✅ wext driver: Configuration VALID"
    WEXT_OK=true
else
    echo "❌ wext driver: Configuration INVALID or driver not supported"
    WEXT_OK=false
fi

# Test without specifying driver (auto-detect)
echo "Testing auto-detect driver..."
if sudo timeout 5 wpa_supplicant -c $WPA_CONF -i $INTERFACE -t 2>/dev/null; then
    echo "✅ auto-detect driver: Configuration VALID"
    AUTO_OK=true
else
    echo "❌ auto-detect driver: Configuration INVALID"
    AUTO_OK=false
fi

echo ""
echo "=== Configuration File Analysis ==="
echo "First 10 lines (passwords hidden):"
head -10 $WPA_CONF | sed 's/psk=.*/psk="***HIDDEN***"/'

echo ""
echo "=== Syntax Check ==="
# Check for common syntax errors
if grep -q 'driver_param=' $WPA_CONF; then
    echo "❌ Found driver_param - this should be removed"
else
    echo "✅ No invalid driver_param found"
fi

if grep -q '^[[:space:]]*ctrl_interface=' $WPA_CONF; then
    echo "✅ ctrl_interface is set"
else
    echo "❌ ctrl_interface is missing"
fi

if grep -q 'network={' $WPA_CONF; then
    echo "✅ Network block found"
else
    echo "❌ No network block found"
fi

echo ""
echo "=== Recommendations ==="
if [ "$NL80211_OK" = true ]; then
    echo "👍 Use nl80211 driver (modern, recommended)"
elif [ "$WEXT_OK" = true ]; then
    echo "👍 Use wext driver (legacy, but working)"
elif [ "$AUTO_OK" = true ]; then
    echo "👍 Use auto-detect driver"
else
    echo "❌ No working driver found - check your WiFi hardware and kernel modules"
    echo "Kernel modules loaded:"
    lsmod | grep -E "(cfg80211|mac80211|wext)"
fi

echo ""
echo "=== Manual Test Commands ==="
echo "Test config syntax:"
echo "  sudo wpa_supplicant -c $WPA_CONF -i $INTERFACE -t"
echo ""
echo "Test connection (foreground):"
if [ "$NL80211_OK" = true ]; then
    echo "  sudo wpa_supplicant -c $WPA_CONF -i $INTERFACE -D nl80211"
elif [ "$WEXT_OK" = true ]; then
    echo "  sudo wpa_supplicant -c $WPA_CONF -i $INTERFACE -D wext"
else
    echo "  sudo wpa_supplicant -c $WPA_CONF -i $INTERFACE"
fi