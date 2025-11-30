#!/bin/bash

# --- Professional Linux Server Management Script - Enhanced Version ---
# Version: 2.0
# Description: A comprehensive script to manage SSH, hostname, IP, firewall, and system monitoring
# Author: Enhanced by AI Assistant
# License: MIT

# --- Configuration ---
SCRIPT_NAME="Server Pro Manager"
SCRIPT_VERSION="2.0"
LOG_FILE="/var/log/server_manager.log"
BACKUP_DIR="/etc/server_manager_backups"
CONFIG_FILE="/etc/server_manager.conf"

# --- Colors for better UI ---
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color
readonly BOLD='\033[1m'

# --- Logging Function ---
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    case "$level" in
        "ERROR")   echo -e "${RED}[ERROR]${NC} $message" ;;
        "WARNING") echo -e "${YELLOW}[WARNING]${NC} $message" ;;
        "INFO")    echo -e "${GREEN}[INFO]${NC} $message" ;;
        "DEBUG")   echo -e "${CYAN}[DEBUG]${NC} $message" ;;
    esac
}

# --- Progress Bar Function ---
show_progress() {
    local duration="$1"
    local message="$2"
    local progress=0
    
    echo -ne "${BLUE}$message${NC} ["
    
    while [ $progress -le 100 ]; do
        printf "\r${BLUE}$message${NC} ["
        local filled=$((progress / 2))
        local empty=$((50 - filled))
        
        printf "%*s" $filled | tr ' ' '='
        printf "%*s" $empty | tr ' ' '-'
        printf "] %d%%" $progress
        
        progress=$((progress + 2))
        sleep $(echo "scale=2; $duration/50" | bc -l 2>/dev/null || echo "0.1")
    done
    echo -e "\n${GREEN}✓ Completed!${NC}"
}

# --- Initialize Script ---
initialize_script() {
    # Create necessary directories
    mkdir -p "$BACKUP_DIR" 2>/dev/null
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null
    
    # Initialize log file
    if [ ! -f "$LOG_FILE" ]; then
        touch "$LOG_FILE"
        chmod 640 "$LOG_FILE"
    fi
    
    log_message "INFO" "Script initialized - Version $SCRIPT_VERSION"
}

# --- Check for Root Privileges ---
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_message "ERROR" "Script requires root privileges"
        echo -e "${RED}❌ Error: This script must be run with root privileges.${NC}"
        echo -e "${YELLOW}💡 Please run with 'sudo su -' or 'sudo $0'.${NC}"
        exit 1
    fi
    log_message "INFO" "Root privileges confirmed"
}

# --- Enhanced OS Detection ---
detect_os() {
    log_message "INFO" "Detecting operating system..."
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME="$NAME"
        OS_VERSION="$VERSION"
        OS_ID="$ID"
        OS_FAMILY="$ID_LIKE"
    elif [ -f /etc/debian_version ]; then
        OS_ID="debian"
        OS_FAMILY="debian"
    elif [ -f /etc/redhat-release ]; then
        OS_ID="rhel"
        OS_FAMILY="rhel fedora"
    else
        log_message "ERROR" "Unsupported operating system detected"
        echo -e "${RED}❌ Unsupported operating system. This script supports Debian/Ubuntu and CentOS/RHEL families.${NC}"
        exit 1
    fi

    # Set package manager and service manager
    case "$OS_FAMILY" in
        *debian*|*ubuntu*)
            PKG_MANAGER="apt"
            PKG_UPDATE="apt update"
            PKG_INSTALL="apt install -y"
            SERVICE_MANAGER="systemctl"
            FIREWALL_TOOL="ufw"
            ;;
        *rhel*|*fedora*|*centos*)
            if command -v dnf &> /dev/null; then
                PKG_MANAGER="dnf"
                PKG_UPDATE="dnf update"
                PKG_INSTALL="dnf install -y"
            else
                PKG_MANAGER="yum"
                PKG_UPDATE="yum update"
                PKG_INSTALL="yum install -y"
            fi
            SERVICE_MANAGER="systemctl"
            FIREWALL_TOOL="firewalld"
            ;;
        *)
            log_message "ERROR" "Unknown OS family: $OS_FAMILY"
            echo -e "${RED}❌ Unknown OS family. Please check compatibility.${NC}"
            exit 1
            ;;
    esac
    
    log_message "INFO" "OS detected: $OS_ID ($OS_FAMILY)"
    echo -e "${GREEN}✓ Detected OS: ${BOLD}$OS_NAME${NC} ${GREEN}($OS_VERSION)${NC}"
}

# --- Backup Configuration Files ---
backup_config() {
    local config_file="$1"
    local backup_name="$2"
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_file="$BACKUP_DIR/${backup_name}_${timestamp}.bak"
    
    if [ -f "$config_file" ]; then
        cp "$config_file" "$backup_file"
        log_message "INFO" "Backup created: $backup_file"
        echo -e "${GREEN}✓ Backup created: $backup_file${NC}"
        return 0
    else
        log_message "WARNING" "Config file not found: $config_file"
        return 1
    fi
}

# --- Enhanced Network Interface Detection ---
get_primary_interface() {
    # Try multiple methods to get the primary interface
    local interface=""
    
    # Method 1: Default route
    interface=$(ip route | grep default | awk '{print $5}' | head -n 1)
    
    # Method 2: First active interface
    if [ -z "$interface" ]; then
        interface=$(ip link show | grep -E "^[0-9]+:" | grep "state UP" | head -n 1 | awk '{print $2}' | sed 's/://')
    fi
    
    # Method 3: Fallback to eth0 or ens3
    if [ -z "$interface" ]; then
        for iface in eth0 ens3 ens33 enp0s3; do
            if ip link show "$iface" &>/dev/null; then
                interface="$iface"
                break
            fi
        done
    fi
    
    echo "$interface"
}

# --- Enhanced IP Detection ---
get_primary_ip() {
    local public_ip=""
    local private_ip=""
    
    # Try to get public IP from multiple services
    for service in "ifconfig.me" "ipinfo.io/ip" "icanhazip.com" "ipecho.net/plain"; do
        public_ip=$(timeout 5 curl -s "$service" 2>/dev/null | grep -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$')
        if [ -n "$public_ip" ]; then
            break
        fi
    done
    
    # Get private IP from primary interface
    local interface=$(get_primary_interface)
    if [ -n "$interface" ]; then
        private_ip=$(ip addr show "$interface" | grep -E 'inet [0-9]' | awk '{print $2}' | cut -d'/' -f1 | head -n 1)
    fi
    
    # Fallback to hostname -I
    if [ -z "$private_ip" ]; then
        private_ip=$(hostname -I | awk '{print $1}')
    fi
    
    # Return public IP if available, otherwise private IP
    if [ -n "$public_ip" ]; then
        echo "$public_ip (Public) / $private_ip (Private)"
    else
        echo "$private_ip (Private)"
    fi
}

# --- Enhanced SSH Port Detection ---
get_current_ssh_port() {
    local ssh_config="/etc/ssh/sshd_config"
    local port=""
    
    if [ -f "$ssh_config" ]; then
        # Look for uncommented Port line
        port=$(grep -E "^[[:space:]]*Port[[:space:]]+" "$ssh_config" | awk '{print $2}' | head -n 1)
    fi
    
    # Default to 22 if not found
    if [ -z "$port" ]; then
        port="22"
    fi
    
    echo "$port"
}

# --- Check if Port is in Use ---
check_port_in_use() {
    local port="$1"
    local protocol="${2:-tcp}"
    
    if netstat -tuln 2>/dev/null | grep -q ":$port " || ss -tuln 2>/dev/null | grep -q ":$port "; then
        return 0  # Port is in use
    else
        return 1  # Port is free
    fi
}

# --- System Information Dashboard ---
display_server_info() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                    ${WHITE}${BOLD}SERVER INFORMATION DASHBOARD${NC}${BLUE}                    ║${NC}"
    echo -e "${BLUE}╠════════════════════════════════════════════════════════════════╣${NC}"
    
    # Basic Information
    echo -e "${BLUE}║ ${YELLOW}${BOLD}Basic Information:${NC}                                          ${BLUE}║${NC}"
    echo -e "${BLUE}║ ${GREEN}Hostname:${NC}         $(printf "%-43s" "$(hostname)")${BLUE}║${NC}"
    echo -e "${BLUE}║ ${GREEN}Primary IP:${NC}       $(printf "%-43s" "$(get_primary_ip)")${BLUE}║${NC}"
    echo -e "${BLUE}║ ${GREEN}SSH Port:${NC}         $(printf "%-43s" "$(get_current_ssh_port)")${BLUE}║${NC}"
    echo -e "${BLUE}║ ${GREEN}Primary Interface:${NC} $(printf "%-43s" "$(get_primary_interface)")${BLUE}║${NC}"
    echo -e "${BLUE}╠════════════════════════════════════════════════════════════════╣${NC}"
    
    # System Information
    echo -e "${BLUE}║ ${YELLOW}${BOLD}System Information:${NC}                                        ${BLUE}║${NC}"
    echo -e "${BLUE}║ ${GREEN}OS:${NC}               $(printf "%-43s" "$OS_NAME")${BLUE}║${NC}"
    echo -e "${BLUE}║ ${GREEN}Version:${NC}          $(printf "%-43s" "$OS_VERSION")${BLUE}║${NC}"
    echo -e "${BLUE}║ ${GREEN}Kernel:${NC}           $(printf "%-43s" "$(uname -r)")${BLUE}║${NC}"
    echo -e "${BLUE}║ ${GREEN}Architecture:${NC}     $(printf "%-43s" "$(uname -m)")${BLUE}║${NC}"
    echo -e "${BLUE}╠════════════════════════════════════════════════════════════════╣${NC}"
    
    # Resource Usage
    echo -e "${BLUE}║ ${YELLOW}${BOLD}Resource Usage:${NC}                                            ${BLUE}║${NC}"
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    local memory_info=$(free | grep Mem)
    local memory_used=$(echo $memory_info | awk '{printf "%.1f", ($3/$2) * 100.0}')
    local disk_usage=$(df -h / | awk 'NR==2{print $5}')
    local uptime_info=$(uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}')
    
    echo -e "${BLUE}║ ${GREEN}CPU Usage:${NC}        $(printf "%-43s" "${cpu_usage}%")${BLUE}║${NC}"
    echo -e "${BLUE}║ ${GREEN}Memory Usage:${NC}     $(printf "%-43s" "${memory_used}%")${BLUE}║${NC}"
    echo -e "${BLUE}║ ${GREEN}Disk Usage (/):${NC}   $(printf "%-43s" "$disk_usage")${BLUE}║${NC}"
    echo -e "${BLUE}║ ${GREEN}Uptime:${NC}           $(printf "%-43s" "$uptime_info")${BLUE}║${NC}"
    echo -e "${BLUE}╠════════════════════════════════════════════════════════════════╣${NC}"
    
    # Service Status
    echo -e "${BLUE}║ ${YELLOW}${BOLD}Service Status:${NC}                                            ${BLUE}║${NC}"
    local ssh_status="❌ Stopped"
    local firewall_status="❌ Inactive"
    
    if systemctl is-active --quiet sshd || systemctl is-active --quiet ssh; then
        ssh_status="✅ Running"
    fi
    
    if [ "$FIREWALL_TOOL" = "ufw" ]; then
        if ufw status 2>/dev/null | grep -q "Status: active"; then
            firewall_status="✅ Active (UFW)"
        fi
    elif [ "$FIREWALL_TOOL" = "firewalld" ]; then
        if firewall-cmd --state 2>/dev/null | grep -q "running"; then
            firewall_status="✅ Active (Firewalld)"
        fi
    fi
    
    echo -e "${BLUE}║ ${GREEN}SSH Service:${NC}      $(printf "%-43s" "$ssh_status")${BLUE}║${NC}"
    echo -e "${BLUE}║ ${GREEN}Firewall:${NC}         $(printf "%-43s" "$firewall_status")${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    
    log_message "INFO" "Server information displayed"
}

# --- Enhanced SSH Port Change ---
change_ssh_port() {
    echo -e "\n${YELLOW}${BOLD}🔧 SSH Port Configuration${NC}"
    echo -e "${BLUE}────────────────────────────────────────${NC}"
    
    local current_port=$(get_current_ssh_port)
    echo -e "${GREEN}Current SSH Port: ${BOLD}$current_port${NC}"
    
    # Show current connections
    echo -e "\n${CYAN}Current SSH connections:${NC}"
    ss -tuln | grep ":$current_port " || echo "No active connections on port $current_port"
    
    echo ""
    read -p "Enter new SSH port (1024-65535): " new_port
    
    # Enhanced validation
    if [[ -z "$new_port" ]]; then
        log_message "WARNING" "SSH port change cancelled - empty input"
        echo -e "${RED}❌ New port cannot be empty${NC}"
        return 1
    fi
    
    if ! [[ "$new_port" =~ ^[0-9]+$ ]] || (( new_port < 1024 )) || (( new_port > 65535 )); then
        log_message "WARNING" "Invalid SSH port attempted: $new_port"
        echo -e "${RED}❌ Invalid port. Must be between 1024-65535${NC}"
        return 1
    fi
    
    if [[ "$new_port" -eq "$current_port" ]]; then
        echo -e "${YELLOW}⚠️  Port is already set to $new_port${NC}"
        return 0
    fi
    
    # Check if port is already in use
    if check_port_in_use "$new_port"; then
        log_message "WARNING" "Port $new_port is already in use"
        echo -e "${RED}❌ Port $new_port is already in use by another service${NC}"
        netstat -tuln | grep ":$new_port " || ss -tuln | grep ":$new_port "
        return 1
    fi
    
    # Confirm change
    echo -e "\n${YELLOW}⚠️  WARNING: Changing SSH port will affect all current connections!${NC}"
    echo -e "${YELLOW}Current port: $current_port → New port: $new_port${NC}"
    read -p "Are you sure you want to continue? (y/N): " confirm
    
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Operation cancelled${NC}"
        return 0
    fi
    
    # Create backup
    local ssh_config="/etc/ssh/sshd_config"
    if ! backup_config "$ssh_config" "sshd_config"; then
        echo -e "${RED}❌ Failed to create backup${NC}"
        return 1
    fi
    
    # Modify SSH configuration
    local temp_config=$(mktemp)
    
    if grep -q "^[[:space:]]*Port" "$ssh_config"; then
        sed "s/^[[:space:]]*Port.*/Port $new_port/" "$ssh_config" > "$temp_config"
    else
        cp "$ssh_config" "$temp_config"
        echo "Port $new_port" >> "$temp_config"
    fi
    
    # Validate configuration syntax
    if ! sshd -t -f "$temp_config"; then
        log_message "ERROR" "SSH configuration validation failed"
        echo -e "${RED}❌ SSH configuration validation failed${NC}"
        rm -f "$temp_config"
        return 1
    fi
    
    # Apply configuration
    mv "$temp_config" "$ssh_config"
    chmod 644 "$ssh_config"
    
    # Update SELinux (CentOS/RHEL)
    if [[ "$OS_FAMILY" == *rhel* ]] || [[ "$OS_FAMILY" == *fedora* ]] || [[ "$OS_FAMILY" == *centos* ]]; then
        if command -v semanage &>/dev/null; then
            echo -e "${BLUE}🔒 Updating SELinux policy...${NC}"
            semanage port -a -t ssh_port_t -p tcp "$new_port" 2>/dev/null || \
            semanage port -m -t ssh_port_t -p tcp "$new_port" 2>/dev/null
            log_message "INFO" "SELinux updated for port $new_port"
        fi
    fi
    
    # Test SSH configuration before restart
    echo -e "${BLUE}🧪 Testing SSH configuration...${NC}"
    if sshd -t; then
        echo -e "${GREEN}✅ SSH configuration is valid${NC}"
    else
        echo -e "${RED}❌ SSH configuration has errors${NC}"
        return 1
    fi
    
    # Restart SSH service
    echo -e "${BLUE}🔄 Restarting SSH service...${NC}"
    if systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null; then
        echo -e "${GREEN}✅ SSH service restarted successfully${NC}"
        log_message "INFO" "SSH port changed from $current_port to $new_port"
        
        # Update firewall rules
        update_firewall_for_ssh "$new_port" "$current_port"
        
        # Test new port
        sleep 2
        if ss -tuln | grep -q ":$new_port "; then
            echo -e "${GREEN}✅ SSH is now listening on port $new_port${NC}"
            echo -e "${YELLOW}💡 Remember to use port $new_port for future connections:${NC}"
            echo -e "${CYAN}   ssh -p $new_port user@$(get_primary_ip | cut -d' ' -f1)${NC}"
        else
            echo -e "${RED}❌ Warning: SSH may not be listening on the new port${NC}"
        fi
    else
        echo -e "${RED}❌ Failed to restart SSH service${NC}"
        log_message "ERROR" "Failed to restart SSH service after port change"
        return 1
    fi
}

# --- Update Firewall for SSH ---
update_firewall_for_ssh() {
    local new_port="$1"
    local old_port="$2"
    
    echo -e "\n${BLUE}🛡️  Updating firewall rules...${NC}"
    
    if [ "$FIREWALL_TOOL" = "ufw" ]; then
        if command -v ufw &>/dev/null && ufw status | grep -q "Status: active"; then
            # Add new port
            ufw allow "$new_port"/tcp comment "SSH Port - Server Manager"
            # Remove old port if it's not default
            if [ "$old_port" != "22" ] && [ "$old_port" != "$new_port" ]; then
                ufw delete allow "$old_port"/tcp 2>/dev/null || true
            fi
            ufw reload
            echo -e "${GREEN}✅ UFW rules updated${NC}"
        fi
    elif [ "$FIREWALL_TOOL" = "firewalld" ]; then
        if command -v firewall-cmd &>/dev/null && firewall-cmd --state &>/dev/null; then
            # Add new port
            firewall-cmd --permanent --add-port="$new_port"/tcp
            # Remove old port if it's not default
            if [ "$old_port" != "22" ] && [ "$old_port" != "$new_port" ]; then
                firewall-cmd --permanent --remove-port="$old_port"/tcp 2>/dev/null || true
            fi
            firewall-cmd --reload
            echo -e "${GREEN}✅ Firewalld rules updated${NC}"
        fi
    fi
}

# --- Enhanced Hostname Change ---
change_hostname() {
    echo -e "\n${YELLOW}${BOLD}🏷️  Hostname Configuration${NC}"
    echo -e "${BLUE}────────────────────────────────────────${NC}"
    
    local current_hostname=$(hostname)
    echo -e "${GREEN}Current Hostname: ${BOLD}$current_hostname${NC}"
    echo ""
    read -p "Enter new hostname: " new_hostname
    
    # Enhanced validation
    if [[ -z "$new_hostname" ]]; then
        echo -e "${RED}❌ Hostname cannot be empty${NC}"
        return 1
    fi
    
    # Validate hostname format
    if [[ ! "$new_hostname" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]]; then
        echo -e "${RED}❌ Invalid hostname format${NC}"
        echo -e "${YELLOW}Valid format: letters, numbers, hyphens (no spaces, max 63 chars)${NC}"
        return 1
    fi
    
    if [[ "$current_hostname" == "$new_hostname" ]]; then
        echo -e "${YELLOW}⚠️  Hostname is already set to $new_hostname${NC}"
        return 0
    fi
    
    # Confirm change
    echo -e "\n${YELLOW}Current: $current_hostname → New: $new_hostname${NC}"
    read -p "Confirm hostname change? (y/N): " confirm
    
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Operation cancelled${NC}"
        return 0
    fi
    
    # Backup /etc/hosts
    backup_config "/etc/hosts" "hosts"
    
    # Set hostname
    echo -e "${BLUE}🔄 Setting hostname...${NC}"
    if hostnamectl set-hostname "$new_hostname"; then
        # Update /etc/hosts
        sed -i "s/127.0.1.1.*/127.0.1.1\t$new_hostname/" /etc/hosts 2>/dev/null || \
        echo -e "127.0.1.1\t$new_hostname" >> /etc/hosts
        
        echo -e "${GREEN}✅ Hostname changed to $new_hostname${NC}"
        echo -e "${YELLOW}💡 Changes will be fully effective after reboot${NC}"
        log_message "INFO" "Hostname changed from $current_hostname to $new_hostname"
    else
        echo -e "${RED}❌ Failed to change hostname${NC}"
        log_message "ERROR" "Failed to change hostname to $new_hostname"
        return 1
    fi
}

# --- Network Configuration Guide ---
configure_network() {
    echo -e "\n${YELLOW}${BOLD}🌐 Network Configuration${NC}"
    echo -e "${BLUE}────────────────────────────────────────${NC}"
    
    local current_ip=$(get_primary_ip)
    local interface=$(get_primary_interface)
    
    echo -e "${GREEN}Current IP: ${BOLD}$current_ip${NC}"
    echo -e "${GREEN}Primary Interface: ${BOLD}$interface${NC}"
    
    echo -e "\n${RED}⚠️  WARNING: Network configuration changes can cause disconnection!${NC}"
    echo -e "${YELLOW}This is a guided process. Automatic changes are not recommended.${NC}"
    
    echo -e "\n${CYAN}Choose an option:${NC}"
    echo "1. View current network configuration"
    echo "2. Edit network configuration file (manual)"
    echo "3. Configure static IP (guided)"
    echo "4. Back to main menu"
    
    read -p "Enter choice: " net_choice
    
    case "$net_choice" in
        1)
            view_network_config
            ;;
        2)
            edit_network_config_file "$interface"
            ;;
        3)
            configure_static_ip "$interface"
            ;;
        4)
            return 0
            ;;
        *)
            echo -e "${RED}❌ Invalid option${NC}"
            ;;
    esac
}

# --- View Network Configuration ---
view_network_config() {
    echo -e "\n${CYAN}${BOLD}Network Configuration Details:${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    
    echo -e "\n${YELLOW}IP Addresses:${NC}"
    ip addr show
    
    echo -e "\n${YELLOW}Routing Table:${NC}"
    ip route show
    
    echo -e "\n${YELLOW}DNS Configuration:${NC}"
    cat /etc/resolv.conf 2>/dev/null || echo "No DNS configuration found"
    
    if [ "$OS_FAMILY" = "debian" ] || [ "$OS_FAMILY" = "*ubuntu*" ]; then
        echo -e "\n${YELLOW}Network Configuration File (/etc/network/interfaces):${NC}"
        cat /etc/network/interfaces 2>/dev/null || echo "Using systemd-networkd or NetworkManager"
    fi
}

# --- Edit Network Configuration File ---
edit_network_config_file() {
    local interface="$1"
    
    echo -e "\n${YELLOW}Manual Network Configuration${NC}"
    
    if [[ "$OS_FAMILY" == *debian* ]] || [[ "$OS_FAMILY" == *ubuntu* ]]; then
        local config_file="/etc/network/interfaces"
        echo -e "${BLUE}Debian/Ubuntu detected${NC}"
        echo -e "${GREEN}Config file: $config_file${NC}"
        
        if [ -f "$config_file" ]; then
            backup_config "$config_file" "network_interfaces"
            echo -e "${BLUE}Opening $config_file with nano...${NC}"
            nano "$config_file"
        else
            echo -e "${YELLOW}Using NetworkManager or systemd-networkd${NC}"
            echo -e "${CYAN}Try: nmtui or systemctl edit systemd-networkd${NC}"
        fi
    elif [[ "$OS_FAMILY" == *rhel* ]] || [[ "$OS_FAMILY" == *fedora* ]]; then
        local config_file="/etc/sysconfig/network-scripts/ifcfg-$interface"
        echo -e "${BLUE}RHEL/CentOS detected${NC}"
        echo -e "${GREEN}Config file: $config_file${NC}"
        
        if [ -f "$config_file" ]; then
            backup_config "$config_file" "ifcfg_$interface"
            echo -e "${BLUE}Opening $config_file with nano...${NC}"
            nano "$config_file"
        else
            echo -e "${YELLOW}Interface config not found${NC}"
            echo -e "${CYAN}Try: nmtui or create the file manually${NC}"
        fi
    fi
    
    echo -e "\n${YELLOW}After editing, restart networking:${NC}"
    echo -e "${CYAN}systemctl restart networking${NC} (Debian/Ubuntu)"
    echo -e "${CYAN}systemctl restart NetworkManager${NC} (RHEL/CentOS)"
}

# --- Advanced Firewall Management ---
manage_firewall() {
    while true; do
        clear
        echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║                     ${WHITE}${BOLD}FIREWALL MANAGEMENT${NC}${BLUE}                        ║${NC}"
        echo -e "${BLUE}╠════════════════════════════════════════════════════════════════╣${NC}"
        
        # Show current firewall status
        local firewall_status="❌ Inactive"
        local firewall_type="Unknown"
        
        if [ "$FIREWALL_TOOL" = "ufw" ]; then
            firewall_type="UFW (Uncomplicated Firewall)"
            if command -v ufw &>/dev/null && ufw status 2>/dev/null | grep -q "Status: active"; then
                firewall_status="✅ Active"
            fi
        elif [ "$FIREWALL_TOOL" = "firewalld" ]; then
            firewall_type="Firewalld"
            if command -v firewall-cmd &>/dev/null && firewall-cmd --state 2>/dev/null | grep -q "running"; then
                firewall_status="✅ Active"
            fi
        fi
        
        echo -e "${BLUE}║ ${GREEN}Firewall Type:${NC}    $(printf "%-43s" "$firewall_type")${BLUE}║${NC}"
        echo -e "${BLUE}║ ${GREEN}Status:${NC}           $(printf "%-43s" "$firewall_status")${BLUE}║${NC}"
        echo -e "${BLUE}╠════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${BLUE}║                        ${WHITE}${BOLD}OPTIONS${NC}${BLUE}                               ║${NC}"
        echo -e "${BLUE}╠════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${BLUE}║ ${GREEN}1.${NC} View Firewall Status                                  ${BLUE}║${NC}"
        echo -e "${BLUE}║ ${GREEN}2.${NC} Enable/Disable Firewall                              ${BLUE}║${NC}"
        echo -e "${BLUE}║ ${GREEN}3.${NC} Manage Ports                                         ${BLUE}║${NC}"
        echo -e "${BLUE}║ ${GREEN}4.${NC} Manage Services                                      ${BLUE}║${NC}"
        echo -e "${BLUE}║ ${GREEN}5.${NC} Quick Security Setup                                 ${BLUE}║${NC}"
        echo -e "${BLUE}║ ${GREEN}6.${NC} Reset Firewall Rules                                 ${BLUE}║${NC}"
        echo -e "${BLUE}║ ${GREEN}7.${NC} Back to Main Menu                                    ${BLUE}║${NC}"
        echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
        
        read -p "Enter choice: " fw_choice
        
        case "$fw_choice" in
            1) view_firewall_status ;;
            2) toggle_firewall ;;
            3) manage_ports ;;
            4) manage_services ;;
            5) quick_security_setup ;;
            6) reset_firewall ;;
            7) break ;;
            *) echo -e "${RED}❌ Invalid option${NC}"; sleep 1 ;;
        esac
        
        if [ "$fw_choice" != "7" ]; then
            read -p "Press Enter to continue..."
        fi
    done
}

# --- Quick Security Setup ---
quick_security_setup() {
    echo -e "\n${YELLOW}${BOLD}🛡️  Quick Security Setup${NC}"
    echo -e "${BLUE}────────────────────────────────────────${NC}"
    
    echo -e "${CYAN}This will configure basic security rules:${NC}"
    echo "• Enable firewall"
    echo "• Allow SSH on current port"
    echo "• Allow HTTP (80) and HTTPS (443)"
    echo "• Deny all other incoming connections"
    echo "• Allow all outgoing connections"
    
    read -p "Continue with quick setup? (y/N): " confirm
    
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Quick setup cancelled${NC}"
        return 0
    fi
    
    local ssh_port=$(get_current_ssh_port)
    
    if [ "$FIREWALL_TOOL" = "ufw" ]; then
        echo -e "${BLUE}🔧 Configuring UFW...${NC}"
        
        # Reset and set defaults
        ufw --force reset
        ufw default deny incoming
        ufw default allow outgoing
        
        # Allow essential services
        ufw allow "$ssh_port"/tcp comment "SSH"
        ufw allow 80/tcp comment "HTTP"
        ufw allow 443/tcp comment "HTTPS"
        
        # Enable firewall
        ufw --force enable
        
        echo -e "${GREEN}✅ UFW configured successfully${NC}"
        
    elif [ "$FIREWALL_TOOL" = "firewalld" ]; then
        echo -e "${BLUE}🔧 Configuring Firewalld...${NC}"
        
        # Start and enable firewalld
        systemctl start firewalld
        systemctl enable firewalld
        
        # Remove all services first
        firewall-cmd --permanent --remove-service=dhcpv6-client 2>/dev/null || true
        
        # Add essential services
        firewall-cmd --permanent --add-port="$ssh_port"/tcp
        firewall-cmd --permanent --add-service=http
        firewall-cmd --permanent --add-service=https
        
        # Reload rules
        firewall-cmd --reload
        
        echo -e "${GREEN}✅ Firewalld configured successfully${NC}"
    fi
    
    log_message "INFO" "Quick security setup completed"
}

# --- System Monitoring ---
system_monitoring() {
    while true; do
        clear
        echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║                    ${WHITE}${BOLD}SYSTEM MONITORING${NC}${BLUE}                          ║${NC}"
        echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
        
        # Real-time system stats
        local load_avg=$(uptime | awk -F'load average:' '{print $2}')
        local disk_usage=$(df -h / | awk 'NR==2{print $5}')
        local memory_usage=$(free | grep Mem | awk '{printf "%.1f%%", ($3/$2) * 100.0}')
        local active_connections=$(ss -tuln | wc -l)
        
        echo -e "\n${YELLOW}${BOLD}Current System Status:${NC}"
        echo -e "${GREEN}Load Average:${NC}     $load_avg"
        echo -e "${GREEN}Disk Usage:${NC}       $disk_usage"
        echo -e "${GREEN}Memory Usage:${NC}     $memory_usage"
        echo -e "${GREEN}Connections:${NC}      $active_connections"
        
        echo -e "\n${CYAN}${BOLD}Monitoring Options:${NC}"
        echo "1. Process Monitor (top)"
        echo "2. Disk Usage Analysis"
        echo "3. Network Connections"
        echo "4. System Logs"
        echo "5. Service Status"
        echo "6. Real-time Monitoring"
        echo "7. Back to Main Menu"
        
        read -p "Enter choice: " mon_choice
        
        case "$mon_choice" in
            1) 
                echo -e "${BLUE}Starting process monitor... (Press 'q' to quit)${NC}"
                top
                ;;
            2)
                echo -e "\n${CYAN}Disk Usage Analysis:${NC}"
                df -h
                echo -e "\n${CYAN}Largest directories:${NC}"
                du -sh /* 2>/dev/null | sort -hr | head -10
                ;;
            3)
                echo -e "\n${CYAN}Network Connections:${NC}"
                ss -tuln
                echo -e "\n${CYAN}Active connections by IP:${NC}"
                ss -tuln | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -nr | head -10
                ;;
            4)
                echo -e "\n${CYAN}Recent System Logs:${NC}"
                journalctl -n 50 --no-pager
                ;;
            5)
                echo -e "\n${CYAN}Service Status:${NC}"
                systemctl list-units --failed --no-pager
                ;;
            6)
                real_time_monitoring
                ;;
            7)
                break
                ;;
            *)
                echo -e "${RED}❌ Invalid option${NC}"
                sleep 1
                ;;
        esac
        
        if [ "$mon_choice" != "7" ] && [ "$mon_choice" != "6" ]; then
            read -p "Press Enter to continue..."
        fi
    done
}

# --- Real-time Monitoring ---
real_time_monitoring() {
    echo -e "${BLUE}Starting real-time monitoring... (Press Ctrl+C to stop)${NC}"
    echo -e "${YELLOW}Updating every 2 seconds${NC}"
    
    while true; do
        clear
        echo -e "${CYAN}${BOLD}Real-time System Monitor${NC}"
        echo -e "${BLUE}════════════════════════════════════════${NC}"
        echo -e "${GREEN}Time: $(date)${NC}"
        
        # CPU Usage
        local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
        echo -e "${GREEN}CPU Usage: ${cpu_usage}%${NC}"
        
        # Memory Usage
        local mem_info=$(free | grep Mem)
        local mem_total=$(echo $mem_info | awk '{print $2}')
        local mem_used=$(echo $mem_info | awk '{print $3}')
        local mem_percent=$(echo $mem_info | awk '{printf "%.1f", ($3/$2) * 100.0}')
        echo -e "${GREEN}Memory: ${mem_used}/${mem_total} (${mem_percent}%)${NC}"
        
        # Network
        echo -e "${GREEN}Active connections: $(ss -tuln | wc -l)${NC}"
        
        # Disk I/O
        echo -e "\n${CYAN}Top Processes by CPU:${NC}"
        ps aux --sort=-%cpu | head -6
        
        sleep 2
    done
}

# --- System Maintenance ---
system_maintenance() {
    while true; do
        clear
        echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║                   ${WHITE}${BOLD}SYSTEM MAINTENANCE${NC}${BLUE}                         ║${NC}"
        echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
        
        echo -e "\n${CYAN}${BOLD}Maintenance Options:${NC}"
        echo "1. Update System Packages"
        echo "2. Clean Package Cache"
        echo "3. Remove Unused Packages"
        echo "4. Check System Health"
        echo "5. Manage System Services"
        echo "6. Configure Automatic Updates"
        echo "7. Back to Main Menu"
        
        read -p "Enter choice: " maint_choice
        
        case "$maint_choice" in
            1) update_system_packages ;;
            2) clean_package_cache ;;
            3) remove_unused_packages ;;
            4) check_system_health ;;
            5) manage_system_services ;;
            6) configure_auto_updates ;;
            7) break ;;
            *) echo -e "${RED}❌ Invalid option${NC}"; sleep 1 ;;
        esac
        
        if [ "$maint_choice" != "7" ]; then
            read -p "Press Enter to continue..."
        fi
    done
}

# --- Update System Packages ---
update_system_packages() {
    echo -e "\n${YELLOW}${BOLD}📦 System Package Update${NC}"
    echo -e "${BLUE}────────────────────────────────────────${NC}"
    
    echo -e "${CYAN}This will update all system packages${NC}"
    read -p "Continue with system update? (y/N): " confirm
    
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Update cancelled${NC}"
        return 0
    fi
    
    echo -e "${BLUE}🔄 Updating package lists...${NC}"
    if [[ "$PKG_MANAGER" == "apt" ]]; then
        apt update
        echo -e "\n${BLUE}📋 Available upgrades:${NC}"
        apt list --upgradable 2>/dev/null | head -20
        
        echo -e "\n${BLUE}🚀 Installing updates...${NC}"
        apt upgrade -y
        
    elif [[ "$PKG_MANAGER" == "dnf" ]]; then
        dnf check-update
        echo -e "\n${BLUE}🚀 Installing updates...${NC}"
        dnf upgrade -y
        
    elif [[ "$PKG_MANAGER" == "yum" ]]; then
        yum check-update
        echo -e "\n${BLUE}🚀 Installing updates...${NC}"
        yum update -y
    fi
    
    echo -e "${GREEN}✅ System update completed${NC}"
    log_message "INFO" "System packages updated"
}

# --- Enhanced Main Menu ---
main_menu() {
    while true; do
        clear
        echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║                                                                ║${NC}"
        echo -e "${BLUE}║            ${WHITE}${BOLD}PROFESSIONAL LINUX SERVER MANAGER${NC}${BLUE}               ║${NC}"
        echo -e "${BLUE}║                        ${CYAN}Version $SCRIPT_VERSION${NC}${BLUE}                        ║${NC}"
        echo -e "${BLUE}║                                                                ║${NC}"
        echo -e "${BLUE}╠════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${BLUE}║                          ${WHITE}${BOLD}MAIN MENU${NC}${BLUE}                            ║${NC}"
        echo -e "${BLUE}╠════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${BLUE}║ ${GREEN}1.${NC} 📊 Server Information Dashboard                        ${BLUE}║${NC}"
        echo -e "${BLUE}║ ${GREEN}2.${NC} 🔧 SSH Configuration                                   ${BLUE}║${NC}"
        echo -e "${BLUE}║ ${GREEN}3.${NC} 🏷️  Hostname Configuration                            ${BLUE}║${NC}"
        echo -e "${BLUE}║ ${GREEN}4.${NC} 🌐 Network Configuration                              ${BLUE}║${NC}"
        echo -e "${BLUE}║ ${GREEN}5.${NC} 🛡️  Firewall Management                               ${BLUE}║${NC}"
        echo -e "${BLUE}║ ${GREEN}6.${NC} 📈 System Monitoring                                  ${BLUE}║${NC}"
        echo -e "${BLUE}║ ${GREEN}7.${NC} 🔧 System Maintenance                                 ${BLUE}║${NC}"
        echo -e "${BLUE}║ ${GREEN}8.${NC} 📁 View Backups                                       ${BLUE}║${NC}"
        echo -e "${BLUE}║ ${GREEN}9.${NC} 📜 View Logs                                          ${BLUE}║${NC}"
        echo -e "${BLUE}║ ${RED}0.${NC} 🚪 Exit                                                ${BLUE}║${NC}"
        echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
        
        echo -e "\n${CYAN}Server: ${BOLD}$(hostname)${NC} ${CYAN}| IP: ${BOLD}$(get_primary_ip | cut -d' ' -f1)${NC} ${CYAN}| SSH: ${BOLD}$(get_current_ssh_port)${NC}"
        
        read -p "Enter your choice: " choice
        
        case "$choice" in
            1) display_server_info; read -p "Press Enter to continue..." ;;
            2) change_ssh_port; read -p "Press Enter to continue..." ;;
            3) change_hostname; read -p "Press Enter to continue..." ;;
            4) configure_network; read -p "Press Enter to continue..." ;;
            5) manage_firewall ;;
            6) system_monitoring ;;
            7) system_maintenance ;;
            8) view_backups; read -p "Press Enter to continue..." ;;
            9) view_logs; read -p "Press Enter to continue..." ;;
            0)
                echo -e "\n${GREEN}Thank you for using ${SCRIPT_NAME}!${NC}"
                echo -e "${CYAN}Goodbye! 👋${NC}"
                log_message "INFO" "Script session ended"
                exit 0
                ;;
            *)
                echo -e "${RED}❌ Invalid option. Please select 0-9.${NC}"
                sleep 1
                ;;
        esac
    done
}

# --- View Backups ---
view_backups() {
    echo -e "\n${YELLOW}${BOLD}📁 Configuration Backups${NC}"
    echo -e "${BLUE}────────────────────────────────────────${NC}"
    
    if [ -d "$BACKUP_DIR" ] && [ "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
        echo -e "${GREEN}Backup directory: $BACKUP_DIR${NC}"
        echo -e "\n${CYAN}Available backups:${NC}"
        ls -la "$BACKUP_DIR" | grep -E '\.(bak|backup)$' | while read line; do
            echo "  $line"
        done
        
        echo -e "\n${CYAN}Disk usage: $(du -sh "$BACKUP_DIR" | cut -f1)${NC}"
    else
        echo -e "${YELLOW}No backups found in $BACKUP_DIR${NC}"
    fi
}

# --- View Logs ---
view_logs() {
    echo -e "\n${YELLOW}${BOLD}📜 System Logs${NC}"
    echo -e "${BLUE}────────────────────────────────────────${NC}"
    
    echo -e "\n${CYAN}Script logs (last 50 lines):${NC}"
    if [ -f "$LOG_FILE" ]; then
        tail -50 "$LOG_FILE"
    else
        echo -e "${YELLOW}No script logs found${NC}"
    fi
    
    echo -e "\n${CYAN}Recent system messages:${NC}"
    journalctl -n 20 --no-pager 2>/dev/null || tail -20 /var/log/messages 2>/dev/null || echo "No system logs accessible"
}

# --- Missing Functions Implementation ---
view_firewall_status() {
    echo -e "\n${CYAN}${BOLD}🛡️  Firewall Status${NC}"
    echo -e "${BLUE}────────────────────────────────────────${NC}"
    
    if [ "$FIREWALL_TOOL" = "ufw" ]; then
        if command -v ufw &>/dev/null; then
            ufw status verbose
        else
            echo -e "${RED}UFW not installed${NC}"
        fi
    elif [ "$FIREWALL_TOOL" = "firewalld" ]; then
        if command -v firewall-cmd &>/dev/null; then
            firewall-cmd --state
            echo -e "\n${CYAN}Active zones:${NC}"
            firewall-cmd --get-active-zones
            echo -e "\n${CYAN}Default zone rules:${NC}"
            firewall-cmd --list-all
        else
            echo -e "${RED}Firewalld not installed${NC}"
        fi
    fi
}

toggle_firewall() {
    echo -e "\n${YELLOW}${BOLD}🔄 Toggle Firewall${NC}"
    echo -e "${BLUE}────────────────────────────────────────${NC}"
    
    read -p "Enable (e) or Disable (d) firewall? (e/d): " toggle_choice
    
    if [ "$FIREWALL_TOOL" = "ufw" ]; then
        case "$toggle_choice" in
            e|E)
                ufw --force enable
                echo -e "${GREEN}✅ UFW enabled${NC}"
                ;;
            d|D)
                echo -e "${RED}⚠️  Warning: Disabling firewall reduces security!${NC}"
                read -p "Are you sure? (y/N): " confirm
                if [[ $confirm =~ ^[Yy]$ ]]; then
                    ufw disable
                    echo -e "${YELLOW}UFW disabled${NC}"
                fi
                ;;
        esac
    elif [ "$FIREWALL_TOOL" = "firewalld" ]; then
        case "$toggle_choice" in
            e|E)
                systemctl start firewalld
                systemctl enable firewalld
                echo -e "${GREEN}✅ Firewalld enabled${NC}"
                ;;
            d|D)
                echo -e "${RED}⚠️  Warning: Disabling firewall reduces security!${NC}"
                read -p "Are you sure? (y/N): " confirm
                if [[ $confirm =~ ^[Yy]$ ]]; then
                    systemctl stop firewalld
                    systemctl disable firewalld
                    echo -e "${YELLOW}Firewalld disabled${NC}"
                fi
                ;;
        esac
    fi
}

manage_ports() {
    echo -e "\n${YELLOW}${BOLD}🔌 Port Management${NC}"
    echo -e "${BLUE}────────────────────────────────────────${NC}"
    
    read -p "Add (a) or Remove (r) port? (a/r): " port_action
    read -p "Enter port number: " port_num
    read -p "Enter protocol (tcp/udp): " protocol
    
    if [ "$FIREWALL_TOOL" = "ufw" ]; then
        case "$port_action" in
            a|A)
                ufw allow "$port_num"/"$protocol"
                echo -e "${GREEN}✅ Port $port_num/$protocol added${NC}"
                ;;
            r|R)
                ufw delete allow "$port_num"/"$protocol"
                echo -e "${YELLOW}Port $port_num/$protocol removed${NC}"
                ;;
        esac
    elif [ "$FIREWALL_TOOL" = "firewalld" ]; then
        case "$port_action" in
            a|A)
                firewall-cmd --permanent --add-port="$port_num"/"$protocol"
                firewall-cmd --reload
                echo -e "${GREEN}✅ Port $port_num/$protocol added${NC}"
                ;;
            r|R)
                firewall-cmd --permanent --remove-port="$port_num"/"$protocol"
                firewall-cmd --reload
                echo -e "${YELLOW}Port $port_num/$protocol removed${NC}"
                ;;
        esac
    fi
}

manage_services() {
    echo -e "\n${YELLOW}${BOLD}🔧 Service Management${NC}"
    echo -e "${BLUE}──
