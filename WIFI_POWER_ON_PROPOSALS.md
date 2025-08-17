# WiFi Hardware Control - Proposed Changes for Power-On Sequence

## Current Behavior (After Update)

### WiFi OFF (`wifi_off()`)
**ONLY performs hardware power cut:**
- Sets GPIO 4 to LOW (0)
- Powers off TPS61023 boost converter
- **NO network service manipulation**
- **NO interface shutdown commands**
- Clean, instant power cut

### WiFi ON (`wifi_on()`) - Current Implementation
**Full sequence with network setup:**
1. Set GPIO 4 to HIGH (1) - Power on TPS61023
2. Wait for USB enumeration (3 seconds)
3. Wait for interface detection (up to 10 seconds)
4. Bring interface UP with `ip link set wlan0 up`
5. Kill any existing wpa_supplicant processes
6. Start wpa_supplicant with config file
7. Wait for WiFi association (up to 15 seconds)
8. Request DHCP lease with `dhclient`
9. Verify connection and report status

## Proposed Optimizations for WiFi ON

### Option 1: Minimal Intervention (Recommended)
```bash
wifi_on() {
    echo "Enabling WiFi hardware power..."
    setup_gpio
    
    # Power on TPS61023 boost converter
    echo "1" > ${GPIO_PATH}/value
    echo "WiFi power enabled via GPIO"
    
    # Wait for USB enumeration only
    echo "Waiting for USB enumeration..."
    sleep 3
    
    # Wait for interface to appear (essential for hardware detection)
    for i in {1..10}; do
        if ip link show $INTERFACE >/dev/null 2>&1; then
            echo "Interface $INTERFACE detected"
            break
        fi
        echo "Waiting for interface... ($i/10)"
        sleep 1
    done
    
    # Optional: Basic interface up (no network services)
    if ip link show $INTERFACE >/dev/null 2>&1; then
        sudo ip link set $INTERFACE up
        echo "Interface brought up - network services will handle connection"
    fi
    
    echo "WiFi hardware power: $(get_wifi_power_state)"
    echo "WiFi interface state: $(get_wifi_interface_state)"
}
```

### Option 2: Hardware-Only Control
```bash
wifi_on() {
    echo "Enabling WiFi hardware power..."
    setup_gpio
    
    # Power on TPS61023 boost converter
    echo "1" > ${GPIO_PATH}/value
    echo "WiFi power enabled via GPIO"
    
    # Brief wait for hardware stabilization
    sleep 2
    
    echo "WiFi hardware power: $(get_wifi_power_state)"
    echo "Note: Network services will automatically detect and configure interface"
}
```

### Option 3: Hybrid Approach (Current + Optimizations)
```bash
wifi_on() {
    echo "Enabling WiFi hardware power..."
    setup_gpio
    
    # Power on TPS61023 boost converter
    echo "1" > ${GPIO_PATH}/value
    echo "WiFi power enabled via GPIO"
    
    # Wait for USB enumeration
    echo "Waiting for USB enumeration..."
    sleep 3
    
    # Wait for interface detection
    for i in {1..8}; do  # Reduced from 10 to 8 attempts
        if ip link show $INTERFACE >/dev/null 2>&1; then
            echo "Interface $INTERFACE detected"
            break
        fi
        sleep 1
    done
    
    # Only if interface detected, proceed with network setup
    if ip link show $INTERFACE >/dev/null 2>&1; then
        echo "Bringing interface up..."
        sudo ip link set $INTERFACE up
        sleep 1  # Reduced from 2 seconds
        
        # Check for existing network management
        if systemctl is-active --quiet NetworkManager 2>/dev/null; then
            echo "NetworkManager detected - letting it handle connection"
        elif systemctl is-active --quiet systemd-networkd 2>/dev/null; then
            echo "systemd-networkd detected - letting it handle connection"  
        else
            # Manual setup only if no network manager
            echo "Manual network setup..."
            # Existing wpa_supplicant + dhclient logic here
        fi
    else
        echo "Interface not detected - hardware may need more time"
    fi
    
    echo "WiFi hardware power: $(get_wifi_power_state)"
}
```

## Recommended Approach: Option 1 (Minimal Intervention)

### Benefits:
1. **Faster Operation**: No waiting for network association
2. **Less System Impact**: Minimal process manipulation
3. **System Integration**: Lets existing network services handle configuration
4. **Reliability**: Reduces potential conflicts with system network management

### Rationale:
- Hardware power control is the primary goal
- Network services (NetworkManager, systemd-networkd, etc.) are designed to automatically detect interface changes
- Reduces complexity and potential failure points
- Maintains clean separation between hardware control and network management

## Implementation Questions:

1. **Should we detect existing network management?**
   - Check for NetworkManager/systemd-networkd and let them handle reconnection
   - Only do manual setup if no network manager is present

2. **Timeout values?**
   - Current: 3s USB enumeration, 10s interface detection, 15s association
   - Proposed: 3s USB enumeration, 8s interface detection, no association wait

3. **Error handling?**
   - Should we retry if interface doesn't appear?
   - How long should we wait before declaring failure?

4. **Status reporting?**
   - Report just hardware status, or attempt to verify network connectivity?
   - Should we check for IP assignment before declaring success?

## Current vs Proposed Comparison:

| Aspect | Current | Proposed (Option 1) |
|--------|---------|-------------------|
| Power OFF | Clean service shutdown + GPIO | GPIO only |
| Power ON | Full network setup | Hardware + basic interface |
| Complexity | High | Low |
| Speed | ~25-30 seconds | ~5-8 seconds |
| Reliability | Moderate (many steps) | High (fewer failure points) |
| System Integration | Manual control | Leverages system services |