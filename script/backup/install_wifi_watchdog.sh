#!/bin/bash
# WiFi Watchdog Service Installer
# Installs and manages the WiFi watchdog as a systemd service

SERVICE_NAME="wifi-watchdog"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WATCHDOG_SCRIPT="${SCRIPT_DIR}/wifi_watchdog.sh"
USER=$(whoami)

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

check_requirements() {
    print_status "Checking requirements..."
    
    # Check if running as root or with sudo
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run with sudo privileges"
        print_error "Usage: sudo $0 [install|uninstall|status|start|stop|restart|logs]"
        exit 1
    fi
    
    # Check if watchdog script exists
    if [ ! -f "$WATCHDOG_SCRIPT" ]; then
        print_error "Watchdog script not found: $WATCHDOG_SCRIPT"
        exit 1
    fi
    
    # Check if GPIO hardware is available
    if [ ! -f "/sys/class/gpio/gpio4/value" ]; then
        print_warning "GPIO4 not found. Attempting to export..."
        echo "4" > /sys/class/gpio/export 2>/dev/null
        sleep 1
        if [ ! -f "/sys/class/gpio/gpio4/value" ]; then
            print_error "GPIO4 hardware not available. Cannot install service."
            exit 1
        fi
    fi
    
    print_status "Requirements check passed"
}

install_service() {
    print_status "Installing WiFi watchdog service..."
    
    # Make script executable
    chmod +x "$WATCHDOG_SCRIPT"
    
    # Create systemd service file
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=WiFi Connection Watchdog
After=network.target multi-user.target
Wants=network.target

[Service]
Type=simple
User=root
Group=root
ExecStart=$WATCHDOG_SCRIPT
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=wifi-watchdog

# Security settings
NoNewPrivileges=yes
ProtectHome=yes
ProtectSystem=strict
ReadWritePaths=/tmp /var/log /sys/class/gpio
PrivateTmp=no

# Resource limits
MemoryLimit=50M
CPUQuota=10%

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd and enable service
    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME"
    
    print_status "Service installed successfully"
    print_status "Service file: $SERVICE_FILE"
    print_status "Script location: $WATCHDOG_SCRIPT"
    print_warning "Service is installed but not started. Use 'sudo $0 start' to start it."
}

uninstall_service() {
    print_status "Uninstalling WiFi watchdog service..."
    
    # Stop and disable service
    systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    systemctl disable "$SERVICE_NAME" 2>/dev/null || true
    
    # Remove service file
    if [ -f "$SERVICE_FILE" ]; then
        rm -f "$SERVICE_FILE"
        systemctl daemon-reload
        print_status "Service uninstalled successfully"
    else
        print_warning "Service file not found"
    fi
    
    # Clean up temporary files
    rm -f /tmp/wifi_intent /tmp/wifi_reconnect_attempts
}

service_status() {
    print_status "WiFi Watchdog Service Status:"
    echo "======================================"
    
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        print_status "Service is RUNNING"
    elif systemctl is-enabled --quiet "$SERVICE_NAME"; then
        print_warning "Service is ENABLED but not running"
    else
        print_error "Service is NOT INSTALLED or DISABLED"
    fi
    
    echo ""
    systemctl status "$SERVICE_NAME" --no-pager -l || true
    
    echo ""
    print_status "Hardware Status:"
    if [ -f "/sys/class/gpio/gpio4/value" ]; then
        local gpio_state=$(cat /sys/class/gpio/gpio4/value 2>/dev/null)
        if [ "$gpio_state" = "1" ]; then
            print_status "GPIO4: HIGH (WiFi powered ON)"
        else
            print_status "GPIO4: LOW (WiFi powered OFF)"
        fi
    else
        print_error "GPIO4: Not available"
    fi
    
    if [ -f "/tmp/wifi_intent" ]; then
        local intent_time=$(cat /tmp/wifi_intent 2>/dev/null)
        local current_time=$(date +%s)
        local time_diff=$((current_time - intent_time))
        print_status "WiFi Intent: Active (${time_diff}s ago)"
    else
        print_status "WiFi Intent: None"
    fi
}

show_logs() {
    print_status "WiFi Watchdog Service Logs (last 50 lines):"
    echo "=============================================="
    journalctl -u "$SERVICE_NAME" -n 50 --no-pager
}

case "$1" in
    "install")
        check_requirements
        install_service
        ;;
    "uninstall"|"remove")
        uninstall_service
        ;;
    "start")
        check_requirements
        systemctl start "$SERVICE_NAME"
        print_status "Service started"
        ;;
    "stop")
        systemctl stop "$SERVICE_NAME"
        print_status "Service stopped"
        ;;
    "restart")
        systemctl restart "$SERVICE_NAME"
        print_status "Service restarted"
        ;;
    "status")
        service_status
        ;;
    "logs")
        show_logs
        ;;
    "enable")
        systemctl enable "$SERVICE_NAME"
        print_status "Service enabled for startup"
        ;;
    "disable")
        systemctl disable "$SERVICE_NAME"
        print_status "Service disabled from startup"
        ;;
    *)
        echo "WiFi Watchdog Service Manager"
        echo "============================="
        echo "Usage: sudo $0 [command]"
        echo ""
        echo "Commands:"
        echo "  install   - Install the service"
        echo "  uninstall - Remove the service"
        echo "  start     - Start the service"
        echo "  stop      - Stop the service"
        echo "  restart   - Restart the service"
        echo "  status    - Show service status"
        echo "  logs      - Show service logs"
        echo "  enable    - Enable service at boot"
        echo "  disable   - Disable service at boot"
        echo ""
        echo "Examples:"
        echo "  sudo $0 install   # Install and configure service"
        echo "  sudo $0 start     # Start monitoring"
        echo "  sudo $0 status    # Check status"
        echo "  sudo $0 logs      # View logs"
        echo ""
        exit 1
        ;;
esac