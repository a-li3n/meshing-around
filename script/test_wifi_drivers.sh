#!/bin/bash
# WiFi Driver Compatibility Test
# Tests different wpa_supplicant driver configurations

INTERFACE="wlan0"
WPA_CONF="/etc/wpa_supplicant/wpa_supplicant.conf"

echo "WiFi Driver Compatibility Test"
echo "=============================="

# Check if interface exists
if ! ip link show $INTERFACE >/dev/null 2>&1; then
    echo "ERROR: Interface $INTERFACE not found"
    echo "Available interfaces:"
    ip link show | grep -E "^[0-9]+:" | cut -d: -f2 | tr -d ' '
    exit 1
fi

# Test nl80211 support
echo ""
echo "Testing nl80211 driver support..."
if iw dev $INTERFACE info >/dev/null 2>&1; then
    echo "✅ nl80211 driver: SUPPORTED"
    NL80211_SUPPORTED=true
    
    # Show interface capabilities
    echo "Interface capabilities:"
    iw dev $INTERFACE info | grep -E "wiphy|type|addr"
else
    echo "❌ nl80211 driver: NOT SUPPORTED"
    NL80211_SUPPORTED=false
fi

# Test wext support
echo ""
echo "Testing WEXT driver support..."
if iwconfig $INTERFACE >/dev/null 2>&1; then
    echo "✅ WEXT driver: SUPPORTED"
    WEXT_SUPPORTED=true
    
    # Show basic info
    echo "WEXT info:"
    iwconfig $INTERFACE | grep -E "IEEE|ESSID|Access Point"
else
    echo "❌ WEXT driver: NOT SUPPORTED"
    WEXT_SUPPORTED=false
fi

# Test wpa_supplicant config
echo ""
echo "Testing wpa_supplicant configuration..."
if [ -f "$WPA_CONF" ]; then
    echo "Config file found: $WPA_CONF"
    
    # Test with nl80211 if supported
    if [ "$NL80211_SUPPORTED" = true ]; then
        echo "Testing config with nl80211 driver..."
        if sudo wpa_supplicant -c $WPA_CONF -i $INTERFACE -D nl80211 -N >/dev/null 2>&1; then
            echo "✅ Configuration valid with nl80211"
            RECOMMENDED_DRIVER="nl80211"
        else
            echo "❌ Configuration invalid with nl80211"
        fi
    fi
    
    # Test with wext if supported  
    if [ "$WEXT_SUPPORTED" = true ]; then
        echo "Testing config with wext driver..."
        if sudo wpa_supplicant -c $WPA_CONF -i $INTERFACE -D wext -N >/dev/null 2>&1; then
            echo "✅ Configuration valid with wext"
            if [ -z "$RECOMMENDED_DRIVER" ]; then
                RECOMMENDED_DRIVER="wext"
            fi
        else
            echo "❌ Configuration invalid with wext"
        fi
    fi
else
    echo "❌ Configuration file not found: $WPA_CONF"
fi

# Recommendations
echo ""
echo "Recommendations:"
echo "================"

if [ -n "$RECOMMENDED_DRIVER" ]; then
    echo "✅ Recommended driver: $RECOMMENDED_DRIVER"
    
    if [ "$RECOMMENDED_DRIVER" = "nl80211" ]; then
        echo "   - Modern driver with better performance"
        echo "   - Fewer compatibility issues"
        echo "   - Better error handling"
    else
        echo "   - Legacy driver (may have some ioctl warnings)"
        echo "   - Should still work for basic connectivity"
    fi
else
    echo "❌ No compatible driver found!"
    echo "   - Check if WiFi adapter is properly connected"
    echo "   - Verify kernel modules are loaded"
    echo "   - Try different USB WiFi adapter"
fi

# Show current kernel modules
echo ""
echo "Current wireless kernel modules:"
lsmod | grep -E "(cfg80211|mac80211|wext|wireless)"

# Show USB WiFi devices
echo ""
echo "USB WiFi devices:"
lsusb | grep -i -E "(wireless|wifi|802\.11|atheros|realtek|ralink|broadcom)"

echo ""
echo "Test complete."