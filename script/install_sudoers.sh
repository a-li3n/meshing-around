#!/bin/bash
# Install sudoers configuration for Meshtastic Bot

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
    echo "Usage: sudo $0 [install|remove|test]"
    exit 1
fi

# Get the actual user (not root when using sudo)
ACTUAL_USER="${SUDO_USER:-$(whoami)}"
SUDOERS_FILE="/etc/sudoers.d/meshtastic-bot"

case "$1" in
    "install")
        print_status "Installing sudoers configuration for user: $ACTUAL_USER"
        
        # Create customized sudoers file
        cat > "$SUDOERS_FILE" << EOF
# Sudoers configuration for Meshtastic Bot
# Auto-generated for user: $ACTUAL_USER

# Allow WiFi GPIO control without password
$ACTUAL_USER ALL=(ALL) NOPASSWD: /usr/bin/tee /sys/class/gpio/gpio4/value

# Allow system shutdown and reboot without password
$ACTUAL_USER ALL=(ALL) NOPASSWD: /sbin/halt
$ACTUAL_USER ALL=(ALL) NOPASSWD: /sbin/reboot
$ACTUAL_USER ALL=(ALL) NOPASSWD: /usr/sbin/halt
$ACTUAL_USER ALL=(ALL) NOPASSWD: /usr/sbin/reboot
$ACTUAL_USER ALL=(ALL) NOPASSWD: /bin/systemctl halt
$ACTUAL_USER ALL=(ALL) NOPASSWD: /bin/systemctl reboot
$ACTUAL_USER ALL=(ALL) NOPASSWD: /usr/bin/systemctl halt
$ACTUAL_USER ALL=(ALL) NOPASSWD: /usr/bin/systemctl reboot
$ACTUAL_USER ALL=(ALL) NOPASSWD: /sbin/shutdown
$ACTUAL_USER ALL=(ALL) NOPASSWD: /usr/sbin/shutdown
EOF

        # Verify sudoers syntax
        if visudo -c -f "$SUDOERS_FILE"; then
            print_status "Sudoers configuration installed successfully"
            print_status "User $ACTUAL_USER can now run bot commands without password"
        else
            print_error "Sudoers syntax error - removing invalid file"
            rm -f "$SUDOERS_FILE"
            exit 1
        fi
        ;;
        
    "remove")
        print_status "Removing sudoers configuration..."
        rm -f "$SUDOERS_FILE"
        print_status "Sudoers configuration removed"
        ;;
        
    "test")
        print_status "Testing sudoers configuration for user: $ACTUAL_USER"
        
        if [ -f "$SUDOERS_FILE" ]; then
            print_status "Sudoers file exists: $SUDOERS_FILE"
            
            # Test syntax
            if visudo -c -f "$SUDOERS_FILE"; then
                print_status "Sudoers syntax: VALID"
            else
                print_error "Sudoers syntax: INVALID"
            fi
            
            # Show current rules
            echo ""
            echo "Current sudoers rules for $ACTUAL_USER:"
            grep "$ACTUAL_USER" "$SUDOERS_FILE" | head -5
            
        else
            print_warning "Sudoers file not found: $SUDOERS_FILE"
            print_warning "Run: sudo $0 install"
        fi
        
        # Test GPIO access
        if [ -f "/sys/class/gpio/gpio4/value" ]; then
            print_status "GPIO4 is available for testing"
            
            # Test as the actual user
            if sudo -u "$ACTUAL_USER" sudo tee /sys/class/gpio/gpio4/value <<< "$(cat /sys/class/gpio/gpio4/value)" >/dev/null 2>&1; then
                print_status "GPIO control: WORKING (no password required)"
            else
                print_error "GPIO control: FAILED (password required or permission denied)"
            fi
        else
            print_warning "GPIO4 not available - run GPIO persistence setup first"
        fi
        ;;
        
    *)
        echo "Sudoers Configuration Manager for Meshtastic Bot"
        echo "==============================================="
        echo "Usage: sudo $0 [command]"
        echo ""
        echo "Commands:"
        echo "  install - Install sudoers rules for current user"
        echo "  remove  - Remove sudoers rules"  
        echo "  test    - Test current sudoers configuration"
        echo ""
        echo "This allows the meshbot to run system commands without password prompts:"
        echo "  • WiFi GPIO control (tee /sys/class/gpio/gpio4/value)"
        echo "  • System shutdown/reboot commands"
        echo ""
        echo "Current user: $ACTUAL_USER"
        ;;
esac