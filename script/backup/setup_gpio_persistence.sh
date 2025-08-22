#!/bin/bash
# Setup GPIO Persistence for Meshtastic WiFi Control

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run with sudo privileges"
    exit 1
fi

case "$1" in
    "install")
        print_status "Installing GPIO4 persistence..."
        
        # Copy udev rule
        cp config/99-gpio-meshtastic.rules /etc/udev/rules.d/
        
        # Reload udev rules
        udevadm control --reload-rules
        udevadm trigger
        
        # Export GPIO4 now if not already exported
        if [ ! -d "/sys/class/gpio/gpio4" ]; then
            echo "4" > /sys/class/gpio/export 2>/dev/null || true
            sleep 0.5
        fi
        
        # Set direction and initial value
        if [ -d "/sys/class/gpio/gpio4" ]; then
            echo "out" > /sys/class/gpio/gpio4/direction 2>/dev/null || true
            echo "0" > /sys/class/gpio/gpio4/value 2>/dev/null || true
            chmod 666 /sys/class/gpio/gpio4/value 2>/dev/null || true
            chmod 666 /sys/class/gpio/gpio4/direction 2>/dev/null || true
        fi
        
        print_status "GPIO4 persistence installed"
        print_status "GPIO4 will be exported as output on every boot"
        ;;
        
    "remove")
        print_status "Removing GPIO4 persistence..."
        
        # Remove udev rule
        rm -f /etc/udev/rules.d/99-gpio-meshtastic.rules
        
        # Reload udev rules
        udevadm control --reload-rules
        
        print_status "GPIO4 persistence removed"
        ;;
        
    "test")
        print_status "Testing GPIO4 setup..."
        
        if [ -d "/sys/class/gpio/gpio4" ]; then
            print_status "GPIO4 is exported"
            
            direction=$(cat /sys/class/gpio/gpio4/direction 2>/dev/null || echo "unknown")
            value=$(cat /sys/class/gpio/gpio4/value 2>/dev/null || echo "unknown")
            
            echo "  Direction: $direction"
            echo "  Value: $value"
            
            # Test write permissions
            if echo "$value" > /sys/class/gpio/gpio4/value 2>/dev/null; then
                print_status "Write permissions: OK"
            else
                print_error "Write permissions: FAILED"
            fi
            
        else
            print_error "GPIO4 is not exported"
            print_warning "Run: sudo $0 install"
        fi
        ;;
        
    "status")
        echo "GPIO4 Status:"
        echo "============="
        
        if [ -f "/etc/udev/rules.d/99-gpio-meshtastic.rules" ]; then
            print_status "udev rule: INSTALLED"
        else
            print_warning "udev rule: NOT INSTALLED"
        fi
        
        if [ -d "/sys/class/gpio/gpio4" ]; then
            print_status "GPIO4: EXPORTED"
            echo "  Direction: $(cat /sys/class/gpio/gpio4/direction 2>/dev/null || echo 'unknown')"
            echo "  Value: $(cat /sys/class/gpio/gpio4/value 2>/dev/null || echo 'unknown')"
            ls -la /sys/class/gpio/gpio4/value 2>/dev/null || echo "  Permissions: unknown"
        else
            print_error "GPIO4: NOT EXPORTED"
        fi
        ;;
        
    *)
        echo "GPIO Persistence Manager"
        echo "======================="
        echo "Usage: sudo $0 [command]"
        echo ""
        echo "Commands:"
        echo "  install - Install GPIO4 persistence (udev rule)"
        echo "  remove  - Remove GPIO4 persistence"
        echo "  test    - Test current GPIO4 setup"
        echo "  status  - Show current status"
        echo ""
        echo "This ensures GPIO4 is exported and configured"
        echo "as output on every system boot."
        ;;
esac