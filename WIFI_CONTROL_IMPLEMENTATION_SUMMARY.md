# Mesh Bot WiFi Control Implementation Summary

## Project Overview
This document summarizes the implementation of WiFi control functionality for a mesh bot system, including both software-based and hardware-based approaches developed during the conversation.

## Initial Problem
The user wanted to implement WiFi toggle functionality in their mesh bot system to:
- Control WiFi power consumption for remote deployments
- Toggle WiFi on/off via LoRa commands
- Maintain stable connections to meshtasticd during WiFi operations

## Solution Evolution

### Phase 1: Software-Only Approach
**Initial Script**: `wifiToggle.sh`
- Used `systemctl restart networking` to toggle WiFi
- **Problems encountered**:
  - Caused TCP connection drops to meshtasticd
  - Broke internet connectivity due to routing disruption
  - Required manual DHCP lease renewal to restore connectivity

### Phase 2: Network-Safe Software Approach
**Scripts developed**:
1. `wifiToggle_safe.sh` - Avoided full networking restart
2. `wifiToggle_ultra_safe.sh` - Added timeout protection
3. `wifiToggle_network_safe.sh` - Added localhost route preservation

**Key improvements**:
- Used targeted interface management instead of system-wide restart
- Preserved localhost routing for meshtasticd connectivity
- Added error handling and timeouts
- Still had some residual connection issues

### Phase 3: Hardware Power Control Solution
**Final Implementation**: `wifiToggle_hardware.sh`

Based on user's separate conversation about hardware power control using:
- **Hardware**: TPS61023 Adafruit boost converter
- **Control**: GPIO 4 on Luckfox Pico Mini 
- **Power**: 3.3V input → 5V output to WiFi module
- **Benefits**: True power isolation, <1µA quiescent current when off

## Files Created/Modified

### Scripts Created
1. **`wifiToggle_safe.sh`** - Initial safer approach
2. **`wifiToggle_ultra_safe.sh`** - Timeout-protected version
3. **`wifiToggle_network_safe.sh`** - Route-preserving version
4. **`wifiToggle_hardware.sh`** - Final hardware control solution
5. **`wifi_diagnostic.sh`** - WiFi diagnostic utility
6. **`sudoers_meshbot`** - Sudoers configuration template

### Core Features Modified
1. **`mesh_bot.py`** - Updated to use hardware control script
2. **Added new bot commands**:
   - `wifi` - Toggle WiFi power
   - `wifion` - Force WiFi on
   - `wifioff` - Force WiFi off
   - `shutdown` - System halt (5-second delay)
   - `reboot` - System restart (5-second delay)

## System Requirements & Setup

### Hardware Requirements (Final Solution)
- Luckfox Pico Mini with GPIO access
- TPS61023 boost converter breakout board
- GPIO 4 connected to boost converter EN pin
- WiFi module powered through boost converter

### Software Dependencies
```bash
# Required packages
sudo apt update
sudo apt install iw wireless-tools wpasupplicant dhclient

# GPIO control (sysfs method used)
# No additional packages needed
```

### Permissions Configuration
**Sudoers file** (`/etc/sudoers.d/meshbot`):
```bash
# Allow meshbot user to run WiFi management commands without password
meshbot ALL=(ALL) NOPASSWD: /usr/sbin/ip
meshbot ALL=(ALL) NOPASSWD: /usr/bin/tee
meshbot ALL=(ALL) NOPASSWD: /usr/bin/pkill
meshbot ALL=(ALL) NOPASSWD: /usr/sbin/wpa_supplicant
meshbot ALL=(ALL) NOPASSWD: /usr/sbin/dhclient
meshbot ALL=(ALL) NOPASSWD: /usr/sbin/iw
meshbot ALL=(ALL) NOPASSWD: /usr/bin/iw
meshbot ALL=(ALL) NOPASSWD: /sbin/iw
meshbot ALL=(ALL) NOPASSWD: /bin/systemctl restart networking
meshbot ALL=(ALL) NOPASSWD: /bin/systemctl restart systemd-resolved
meshbot ALL=(ALL) NOPASSWD: /usr/sbin/halt
meshbot ALL=(ALL) NOPASSWD: /usr/sbin/reboot
```

**Installation**:
```bash
sudo cp sudoers_meshbot /etc/sudoers.d/meshbot
sudo chmod 440 /etc/sudoers.d/meshbot
sudo chown root:root /etc/sudoers.d/meshbot
sudo visudo -c  # Test syntax
```

### Script Permissions
```bash
# Make all scripts executable
chmod +x script/wifiToggle_hardware.sh
chmod +x script/wifiToggle_network_safe.sh
chmod +x script/wifiToggle_safe.sh
chmod +x script/wifi_diagnostic.sh
```

## Hardware Implementation Details

### GPIO Setup (Luckfox Pico Mini)
- **Physical Pin**: 18 (0A_4D)
- **GPIO Number**: 4 in Linux sysfs
- **Voltage**: 3.3V logic (compatible with TPS61023 EN pin)

### GPIO Control Commands
```bash
# Export GPIO (done automatically by script)
echo 4 > /sys/class/gpio/export
echo out > /sys/class/gpio/gpio4/direction

# Control WiFi power
echo 1 > /sys/class/gpio/gpio4/value  # WiFi ON
echo 0 > /sys/class/gpio/gpio4/value  # WiFi OFF

# Check status
cat /sys/class/gpio/gpio4/value
```

## Bot Integration

### Command Restrictions
All WiFi and system commands are restricted to Direct Message (DM) only and require admin privileges:
- `wifi`, `wifion`, `wifioff` - WiFi control
- `shutdown`, `reboot` - System control

### Message Flow
1. User sends DM with WiFi command
2. Bot validates admin permissions
3. Bot calls external script via `call_external_script()`
4. Script controls hardware via GPIO
5. Bot returns status message

### Response Messages
- `📶➡️📵WiFi turned OFF` - Successfully powered off
- `📵➡️📶WiFi turned ON` - Successfully powered on  
- `🚫Access denied - admin only` - Permission denied
- `⚠️Failed to turn WiFi ON/OFF` - Hardware/script error

## Troubleshooting

### Common Issues & Solutions

1. **GPIO Permission Denied**
   ```bash
   # Solution: Check sudoers file includes /usr/bin/tee
   sudo visudo /etc/sudoers.d/meshbot
   ```

2. **Interface Not Appearing**
   ```bash
   # Check USB enumeration
   lsusb
   dmesg | tail
   ```

3. **WiFi Association Failure**
   ```bash
   # Check wpa_supplicant config
   sudo wpa_supplicant -i wlan0 -c /etc/wpa_supplicant/wpa_supplicant.conf -D
   ```

4. **DHCP Issues**
   ```bash
   # Manual DHCP debugging
   sudo dhclient -v wlan0
   ```

### Diagnostic Commands
```bash
# Run diagnostic script
./script/wifi_diagnostic.sh

# Check hardware power state
cat /sys/class/gpio/gpio4/value

# Check GPIO debug info
sudo cat /sys/kernel/debug/gpio

# Check WiFi interface status
ip link show wlan0
```

## Performance Benefits

### Power Consumption
- **Software-only approach**: WiFi module always powered (~500mA+)
- **Hardware approach**: True power-off, <1µA quiescent current
- **Estimated savings**: 90%+ reduction when WiFi disabled

### Connection Stability  
- **Old approach**: TCP connection drops during WiFi operations
- **Hardware approach**: No impact on LoRa/meshtasticd connectivity
- **Reconnection**: Clean, automated WiFi re-association

### Response Time
- **WiFi OFF**: Immediate (hardware power cut)
- **WiFi ON**: ~10-15 seconds (USB enumeration + association)

## Future Enhancements

### Potential Improvements
1. **Status monitoring**: Periodic WiFi health checks
2. **Scheduled operation**: Automated WiFi on/off based on time
3. **Power monitoring**: Current measurement integration
4. **Failsafe**: Automatic WiFi enable after timeout

### Configuration Options
- Adjustable timeouts for USB enumeration
- Configurable DHCP retry attempts  
- Custom wpa_supplicant configuration paths
- GPIO pin mapping for different hardware

## Summary
The final hardware-based solution provides robust, power-efficient WiFi control with minimal impact on the core mesh networking functionality. The implementation successfully addresses all original requirements while providing true power savings through complete hardware isolation.