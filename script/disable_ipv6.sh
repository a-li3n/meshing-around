#!/bin/bash
# Disable IPv6 System-wide Script
# Provides multiple methods to disable IPv6 permanently

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run with sudo privileges"
        exit 1
    fi
}

# Method 1: Kernel parameters via sysctl
disable_ipv6_sysctl() {
    print_status "Method 1: Disabling IPv6 via sysctl..."
    
    # Create sysctl configuration file
    cat > /etc/sysctl.d/99-disable-ipv6.conf << EOF
# Disable IPv6 globally
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
    
    # Apply immediately
    sysctl -p /etc/sysctl.d/99-disable-ipv6.conf
    
    print_status "IPv6 disabled via sysctl"
}

# Method 2: GRUB kernel parameters
disable_ipv6_grub() {
    print_status "Method 2: Disabling IPv6 via GRUB kernel parameters..."
    
    # Backup GRUB config
    if [ -f /etc/default/grub ]; then
        cp /etc/default/grub /etc/default/grub.backup.$(date +%Y%m%d)
        
        # Add IPv6 disable parameter
        if ! grep -q "ipv6.disable=1" /etc/default/grub; then
            sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/&ipv6.disable=1 /' /etc/default/grub
            sed -i 's/GRUB_CMDLINE_LINUX="/&ipv6.disable=1 /' /etc/default/grub
            
            # Update GRUB
            if command -v update-grub >/dev/null 2>&1; then
                update-grub
            elif command -v grub2-mkconfig >/dev/null 2>&1; then
                grub2-mkconfig -o /boot/grub2/grub.cfg
            else
                print_warning "Could not update GRUB automatically"
                print_warning "Please run 'sudo update-grub' or equivalent manually"
            fi
            
            print_status "IPv6 disabled via GRUB (requires reboot)"
        else
            print_status "IPv6 already disabled in GRUB"
        fi
    else
        print_warning "GRUB config not found at /etc/default/grub"
    fi
}

# Method 3: Blacklist IPv6 module
disable_ipv6_blacklist() {
    print_status "Method 3: Blacklisting IPv6 kernel module..."
    
    # Create blacklist file
    cat > /etc/modprobe.d/blacklist-ipv6.conf << EOF
# Blacklist IPv6
blacklist ipv6
EOF
    
    # Update initramfs
    if command -v update-initramfs >/dev/null 2>&1; then
        update-initramfs -u
    elif command -v dracut >/dev/null 2>&1; then
        dracut -f
    fi
    
    print_status "IPv6 module blacklisted (requires reboot)"
}

# Verify IPv6 is disabled
verify_ipv6_status() {
    print_status "Verifying IPv6 status..."
    
    echo "Current IPv6 settings:"
    echo "  all.disable_ipv6: $(cat /proc/sys/net/ipv6/conf/all/disable_ipv6 2>/dev/null || echo 'N/A')"
    echo "  default.disable_ipv6: $(cat /proc/sys/net/ipv6/conf/default/disable_ipv6 2>/dev/null || echo 'N/A')"
    
    echo ""
    echo "IPv6 addresses:"
    if ip -6 addr show 2>/dev/null | grep -q inet6; then
        print_warning "IPv6 addresses still present:"
        ip -6 addr show | grep inet6
    else
        print_status "No IPv6 addresses found"
    fi
    
    echo ""
    echo "IPv6 module status:"
    if lsmod | grep -q ipv6; then
        print_warning "IPv6 module still loaded"
    else
        print_status "IPv6 module not loaded"
    fi
}

# Remove IPv6 configurations
remove_ipv6_config() {
    print_status "Removing IPv6 configurations..."
    
    # Remove DHCP IPv6 configs
    if [ -f /etc/dhcp/dhclient.conf ]; then
        sed -i '/dhcp6\./d' /etc/dhcp/dhclient.conf
        sed -i '/request.*dhcp6/d' /etc/dhcp/dhclient.conf
    fi
    
    # Disable IPv6 in NetworkManager if present
    if [ -f /etc/NetworkManager/NetworkManager.conf ]; then
        if ! grep -q "\[ipv6\]" /etc/NetworkManager/NetworkManager.conf; then
            echo "" >> /etc/NetworkManager/NetworkManager.conf
            echo "[ipv6]" >> /etc/NetworkManager/NetworkManager.conf
            echo "method=ignore" >> /etc/NetworkManager/NetworkManager.conf
            
            # Restart NetworkManager if running
            if systemctl is-active --quiet NetworkManager; then
                systemctl restart NetworkManager
            fi
        fi
    fi
}

# Main function
main() {
    echo "IPv6 Disable Script"
    echo "=================="
    
    check_root
    
    case "$1" in
        "sysctl"|"1")
            disable_ipv6_sysctl
            verify_ipv6_status
            ;;
        "grub"|"2")
            disable_ipv6_grub
            print_warning "Reboot required for GRUB changes to take effect"
            ;;
        "blacklist"|"3")
            disable_ipv6_blacklist
            print_warning "Reboot required for module blacklist to take effect"
            ;;
        "all")
            disable_ipv6_sysctl
            disable_ipv6_grub
            disable_ipv6_blacklist
            remove_ipv6_config
            verify_ipv6_status
            print_warning "Reboot required for all changes to take effect"
            ;;
        "verify")
            verify_ipv6_status
            ;;
        "remove")
            print_status "Removing IPv6 disable configurations..."
            rm -f /etc/sysctl.d/99-disable-ipv6.conf
            rm -f /etc/modprobe.d/blacklist-ipv6.conf
            
            # Restore GRUB if backup exists
            if [ -f /etc/default/grub.backup.* ]; then
                BACKUP=$(ls -t /etc/default/grub.backup.* | head -1)
                cp "$BACKUP" /etc/default/grub
                update-grub 2>/dev/null || true
            fi
            
            print_status "IPv6 disable configurations removed"
            print_warning "Reboot required to re-enable IPv6"
            ;;
        *)
            echo "Usage: sudo $0 [method]"
            echo ""
            echo "Methods:"
            echo "  sysctl    - Disable via sysctl (immediate + persistent)"
            echo "  grub      - Disable via kernel parameters (requires reboot)"
            echo "  blacklist - Blacklist IPv6 module (requires reboot)"
            echo "  all       - Apply all methods (most thorough)"
            echo "  verify    - Check current IPv6 status"
            echo "  remove    - Remove all IPv6 disable configurations"
            echo ""
            echo "Recommended: sudo $0 sysctl"
            exit 1
            ;;
    esac
}

main "$@"