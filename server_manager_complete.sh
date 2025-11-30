#!/bin/bash

# --- Professional Linux Server Management Script - Complete Edition ---
# Version: 3.0
# Description: A comprehensive script to manage SSH, hostname, IP, firewall, DNS, SSL, users, and advanced system operations
# Author: Memarzade Development Team
# License: MIT
# GitHub: https://github.com/memarzade-dev/linux-server-manager

# --- Configuration ---
SCRIPT_NAME="Professional Linux Server Manager"
SCRIPT_VERSION="3.0"
LOG_FILE="/var/log/server_manager.log"
BACKUP_DIR="/etc/server_manager_backups"
CONFIG_FILE="/etc/server_manager.conf"
TEMP_DIR="/tmp/server_manager"

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
    mkdir -p "$TEMP_DIR" 2>/dev/null
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
            WEB_USER="www-data"
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
            WEB_USER="apache"
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
    local docker_status="❌ Not Installed"
    local nginx_status="❌ Not Installed"
    
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
    
    if command -v docker &>/dev/null; then
        if systemctl is-active --quiet docker; then
            docker_status="✅ Running"
        else
            docker_status="⚠️ Installed, Stopped"
        fi
    fi
    
    if command -v nginx &>/dev/null; then
        if systemctl is-active --quiet nginx; then
            nginx_status="✅ Running"
        else
            nginx_status="⚠️ Installed, Stopped"
        fi
    fi
    
    echo -e "${BLUE}║ ${GREEN}SSH Service:${NC}      $(printf "%-43s" "$ssh_status")${BLUE}║${NC}"
    echo -e "${BLUE}║ ${GREEN}Firewall:${NC}         $(printf "%-43s" "$firewall_status")${BLUE}║${NC}"
    echo -e "${BLUE}║ ${GREEN}Docker:${NC}           $(printf "%-43s" "$docker_status")${BLUE}║${NC}"
    echo -e "${BLUE}║ ${GREEN}Nginx:${NC}            $(printf "%-43s" "$nginx_status")${BLUE}║${NC}"
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

# --- DNS Management ---
manage_dns() {
    while true; do
        clear
        echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║                       ${WHITE}${BOLD}DNS MANAGEMENT${NC}${BLUE}                           ║${NC}"
        echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
        
        # Show current DNS servers
        echo -e "\n${CYAN}Current DNS Configuration:${NC}"
        if [ -f /etc/resolv.conf ]; then
            grep nameserver /etc/resolv.conf | while read line; do
                echo "  $line"
            done
        fi
        
        echo -e "\n${CYAN}${BOLD}DNS Management Options:${NC}"
        echo "1. View Current DNS Configuration"
        echo "2. Change DNS Servers"
        echo "3. Add Custom DNS Server"
        echo "4. Remove DNS Server"
        echo "5. Flush DNS Cache"
        echo "6. Test DNS Resolution"
        echo "7. Configure DNS over HTTPS (DoH)"
        echo "8. Back to Main Menu"
        
        read -p "Enter choice: " dns_choice
        
        case "$dns_choice" in
            1) view_dns_config ;;
            2) change_dns_servers ;;
            3) add_dns_server ;;
            4) remove_dns_server ;;
            5) flush_dns_cache ;;
            6) test_dns_resolution ;;
            7) configure_doh ;;
            8) break ;;
            *) echo -e "${RED}❌ Invalid option${NC}"; sleep 1 ;;
        esac
        
        if [ "$dns_choice" != "8" ]; then
            read -p "Press Enter to continue..."
        fi
    done
}

# --- View DNS Configuration ---
view_dns_config() {
    echo -e "\n${CYAN}${BOLD}Complete DNS Configuration:${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    
    echo -e "\n${YELLOW}/etc/resolv.conf:${NC}"
    cat /etc/resolv.conf 2>/dev/null || echo "File not found"
    
    echo -e "\n${YELLOW}systemd-resolved status:${NC}"
    if command -v systemd-resolve &>/dev/null; then
        systemd-resolve --status | head -20
    elif command -v resolvectl &>/dev/null; then
        resolvectl status | head -20
    else
        echo "systemd-resolved not available"
    fi
    
    echo -e "\n${YELLOW}Current DNS test:${NC}"
    nslookup google.com 2>/dev/null | head -10 || echo "DNS resolution test failed"
}

# --- Change DNS Servers ---
change_dns_servers() {
    echo -e "\n${YELLOW}${BOLD}🌐 Change DNS Servers${NC}"
    echo -e "${BLUE}────────────────────────────────────────${NC}"
    
    echo -e "${CYAN}Popular DNS Servers:${NC}"
    echo "1. Google DNS (8.8.8.8, 8.8.4.4)"
    echo "2. Cloudflare DNS (1.1.1.1, 1.0.0.1)"
    echo "3. Quad9 DNS (9.9.9.9, 149.112.112.112)"
    echo "4. OpenDNS (208.67.222.222, 208.67.220.220)"
    echo "5. Custom DNS servers"
    
    read -p "Select option (1-5): " dns_option
    
    local dns1="" dns2=""
    
    case "$dns_option" in
        1) dns1="8.8.8.8"; dns2="8.8.4.4" ;;
        2) dns1="1.1.1.1"; dns2="1.0.0.1" ;;
        3) dns1="9.9.9.9"; dns2="149.112.112.112" ;;
        4) dns1="208.67.222.222"; dns2="208.67.220.220" ;;
        5) 
            read -p "Enter primary DNS server: " dns1
            read -p "Enter secondary DNS server: " dns2
            ;;
        *) echo -e "${RED}❌ Invalid option${NC}"; return 1 ;;
    esac
    
    # Validate IP addresses
    if ! [[ "$dns1" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo -e "${RED}❌ Invalid primary DNS IP address${NC}"
        return 1
    fi
    
    if [ -n "$dns2" ] && ! [[ "$dns2" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo -e "${RED}❌ Invalid secondary DNS IP address${NC}"
        return 1
    fi
    
    # Backup current configuration
    backup_config "/etc/resolv.conf" "resolv_conf"
    
    # Update DNS configuration
    echo -e "${BLUE}🔄 Updating DNS configuration...${NC}"
    
    # Create new resolv.conf
    cat > /etc/resolv.conf << EOF
# Generated by Server Manager
nameserver $dns1
EOF
    
    if [ -n "$dns2" ]; then
        echo "nameserver $dns2" >> /etc/resolv.conf
    fi
    
    echo -e "${GREEN}✅ DNS servers updated to: $dns1${dns2:+, $dns2}${NC}"
    
    # Test new DNS
    echo -e "${BLUE}🧪 Testing DNS resolution...${NC}"
    if nslookup google.com >/dev/null 2>&1; then
        echo -e "${GREEN}✅ DNS resolution test successful${NC}"
    else
        echo -e "${RED}❌ DNS resolution test failed${NC}"
    fi
    
    log_message "INFO" "DNS servers changed to: $dns1${dns2:+, $dns2}"
}

# --- Add DNS Server ---
add_dns_server() {
    echo -e "\n${YELLOW}${BOLD}➕ Add DNS Server${NC}"
    echo -e "${BLUE}────────────────────────────────────────${NC}"
    
    read -p "Enter DNS server IP to add: " new_dns
    
    # Validate IP address
    if ! [[ "$new_dns" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo -e "${RED}❌ Invalid IP address${NC}"
        return 1
    fi
    
    # Check if DNS already exists
    if grep -q "nameserver $new_dns" /etc/resolv.conf 2>/dev/null; then
        echo -e "${YELLOW}⚠️  DNS server $new_dns already exists${NC}"
        return 0
    fi
    
    # Backup and add DNS server
    backup_config "/etc/resolv.conf" "resolv_conf"
    echo "nameserver $new_dns" >> /etc/resolv.conf
    
    echo -e "${GREEN}✅ DNS server $new_dns added${NC}"
    log_message "INFO" "DNS server added: $new_dns"
}

# --- SSL/TLS Certificate Management ---
manage_ssl() {
    while true; do
        clear
        echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║                    ${WHITE}${BOLD}SSL/TLS MANAGEMENT${NC}${BLUE}                         ║${NC}"
        echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
        
        echo -e "\n${CYAN}${BOLD}SSL/TLS Management Options:${NC}"
        echo "1. Install Certbot (Let's Encrypt Client)"
        echo "2. Generate SSL Certificate"
        echo "3. Renew SSL Certificates"
        echo "4. List SSL Certificates"
        echo "5. Configure Auto-renewal"
        echo "6. Generate Self-signed Certificate"
        echo "7. Check Certificate Expiry"
        echo "8. Back to Main Menu"
        
        read -p "Enter choice: " ssl_choice
        
        case "$ssl_choice" in
            1) install_certbot ;;
            2) generate_ssl_certificate ;;
            3) renew_ssl_certificates ;;
            4) list_ssl_certificates ;;
            5) configure_ssl_autorenewal ;;
            6) generate_selfsigned_certificate ;;
            7) check_certificate_expiry ;;
            8) break ;;
            *) echo -e "${RED}❌ Invalid option${NC}"; sleep 1 ;;
        esac
        
        if [ "$ssl_choice" != "8" ]; then
            read -p "Press Enter to continue..."
        fi
    done
}

# --- Install Certbot ---
install_certbot() {
    echo -e "\n${YELLOW}${BOLD}📜 Installing Certbot (Let's Encrypt Client)${NC}"
    echo -e "${BLUE}────────────────────────────────────────${NC}"
    
    if command -v certbot &>/dev/null; then
        echo -e "${GREEN}✅ Certbot is already installed${NC}"
        certbot --version
        return 0
    fi
    
    echo -e "${BLUE}🔄 Installing Certbot...${NC}"
    
    if [ "$OS_FAMILY" = "*debian*" ] || [ "$OS_FAMILY" = "*ubuntu*" ]; then
        $PKG_UPDATE
        $PKG_INSTALL snapd
        snap install core; snap refresh core
        snap install --classic certbot
        ln -sf /snap/bin/certbot /usr/bin/certbot
    else
        $PKG_UPDATE
        $PKG_INSTALL certbot
    fi
    
    if command -v certbot &>/dev/null; then
        echo -e "${GREEN}✅ Certbot installed successfully${NC}"
        log_message "INFO" "Certbot installed"
    else
        echo -e "${RED}❌ Failed to install Certbot${NC}"
        log_message "ERROR" "Failed to install Certbot"
        return 1
    fi
}

# --- User Management ---
manage_users() {
    while true; do
        clear
        echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║                     ${WHITE}${BOLD}USER MANAGEMENT${NC}${BLUE}                          ║${NC}"
        echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
        
        echo -e "\n${CYAN}${BOLD}User Management Options:${NC}"
        echo "1. List All Users"
        echo "2. Add New User"
        echo "3. Delete User"
        echo "4. Change User Password"
        echo "5. Add User to Group"
        echo "6. Remove User from Group"
        echo "7. Lock/Unlock User Account"
        echo "8. Set User Shell"
        echo "9. Configure SSH Key for User"
        echo "10. Back to Main Menu"
        
        read -p "Enter choice: " user_choice
        
        case "$user_choice" in
            1) list_users ;;
            2) add_user ;;
            3) delete_user ;;
            4) change_user_password ;;
            5) add_user_to_group ;;
            6) remove_user_from_group ;;
            7) lock_unlock_user ;;
            8) set_user_shell ;;
            9) configure_ssh_key ;;
            10) break ;;
            *) echo -e "${RED}❌ Invalid option${NC}"; sleep 1 ;;
        esac
        
        if [ "$user_choice" != "10" ]; then
            read -p "Press Enter to continue..."
        fi
    done
}

# --- List Users ---
list_users() {
    echo -e "\n${CYAN}${BOLD}👥 System Users${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    
    echo -e "\n${YELLOW}Regular Users (UID >= 1000):${NC}"
    awk -F: '$3 >= 1000 && $3 < 65534 {print $1 "\t" $3 "\t" $5 "\t" $7}' /etc/passwd | \
    while read username uid fullname shell; do
        echo -e "${GREEN}$username${NC} (UID: $uid) - $fullname - Shell: $shell"
    done
    
    echo -e "\n${YELLOW}System Users (UID < 1000):${NC}"
    awk -F: '$3 < 1000 {print $1 "\t" $3 "\t" $7}' /etc/passwd | head -10 | \
    while read username uid shell; do
        echo -e "${CYAN}$username${NC} (UID: $uid) - Shell: $shell"
    done
    
    echo -e "\n${YELLOW}Currently Logged In Users:${NC}"
    who
}

# --- Add User ---
add_user() {
    echo -e "\n${YELLOW}${BOLD}👤 Add New User${NC}"
    echo -e "${BLUE}────────────────────────────────────────${NC}"
    
    read -p "Enter username: " username
    
    # Validate username
    if [[ -z "$username" ]]; then
        echo -e "${RED}❌ Username cannot be empty${NC}"
        return 1
    fi
    
    if [[ ! "$username" =~ ^[a-z]([a-z0-9_-]){0,31}$ ]]; then
        echo -e "${RED}❌ Invalid username format${NC}"
        echo -e "${YELLOW}Username must start with lowercase letter, max 32 chars${NC}"
        return 1
    fi
    
    # Check if user already exists
    if id "$username" &>/dev/null; then
        echo -e "${RED}❌ User $username already exists${NC}"
        return 1
    fi
    
    read -p "Enter full name (optional): " fullname
    read -s -p "Enter password: " password
    echo
    read -s -p "Confirm password: " password_confirm
    echo
    
    if [[ "$password" != "$password_confirm" ]]; then
        echo -e "${RED}❌ Passwords do not match${NC}"
        return 1
    fi
    
    # Create user
    echo -e "${BLUE}🔄 Creating user $username...${NC}"
    
    if [ -n "$fullname" ]; then
        useradd -m -c "$fullname" -s /bin/bash "$username"
    else
        useradd -m -s /bin/bash "$username"
    fi
    
    if [ $? -eq 0 ]; then
        echo "$username:$password" | chpasswd
        echo -e "${GREEN}✅ User $username created successfully${NC}"
        
        # Ask if user should be added to sudo group
        read -p "Add user to sudo group? (y/N): " sudo_choice
        if [[ $sudo_choice =~ ^[Yy]$ ]]; then
            usermod -aG sudo "$username" 2>/dev/null || usermod -aG wheel "$username"
            echo -e "${GREEN}✅ User added to sudo group${NC}"
        fi
        
        log_message "INFO" "User $username created"
    else
        echo -e "${RED}❌ Failed to create user${NC}"
        log_message "ERROR" "Failed to create user $username"
        return 1
    fi
}

# --- Docker Management ---
manage_docker() {
    while true; do
        clear
        echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║                    ${WHITE}${BOLD}DOCKER MANAGEMENT${NC}${BLUE}                         ║${NC}"
        echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
        
        # Check Docker status
        local docker_status="❌ Not Installed"
        if command -v docker &>/dev/null; then
            if systemctl is-active --quiet docker; then
                docker_status="✅ Running"
            else
                docker_status="⚠️ Installed, Stopped"
            fi
        fi
        
        echo -e "\n${GREEN}Docker Status: ${docker_status}${NC}"
        
        echo -e "\n${CYAN}${BOLD}Docker Management Options:${NC}"
        echo "1. Install Docker"
        echo "2. Start/Stop Docker Service"
        echo "3. List Docker Containers"
        echo "4. List Docker Images"
        echo "5. Docker System Information"
        echo "6. Pull Docker Image"
        echo "7. Run Docker Container"
        echo "8. Remove Docker Container"
        echo "9. Remove Docker Image"
        echo "10. Docker Cleanup"
        echo "11. Back to Main Menu"
        
        read -p "Enter choice: " docker_choice
        
        case "$docker_choice" in
            1) install_docker ;;
            2) manage_docker_service ;;
            3) list_docker_containers ;;
            4) list_docker_images ;;
            5) docker_system_info ;;
            6) pull_docker_image ;;
            7) run_docker_container ;;
            8) remove_docker_container ;;
            9) remove_docker_image ;;
            10) docker_cleanup ;;
            11) break ;;
            *) echo -e "${RED}❌ Invalid option${NC}"; sleep 1 ;;
        esac
        
        if [ "$docker_choice" != "11" ]; then
            read -p "Press Enter to continue..."
        fi
    done
}

# --- Install Docker ---
install_docker() {
    echo -e "\n${YELLOW}${BOLD}🐳 Installing Docker${NC}"
    echo -e "${BLUE}────────────────────────────────────────${NC}"
    
    if command -v docker &>/dev/null; then
        echo -e "${GREEN}✅ Docker is already installed${NC}"
        docker --version
        return 0
    fi
    
    echo -e "${BLUE}🔄 Installing Docker...${NC}"
    
    if [[ "$OS_FAMILY" == *debian* ]] || [[ "$OS_FAMILY" == *ubuntu* ]]; then
        # Install Docker on Debian/Ubuntu
        $PKG_UPDATE
        $PKG_INSTALL apt-transport-https ca-certificates curl gnupg lsb-release
        
        # Add Docker's official GPG key
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        
        # Add Docker repository
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        $PKG_UPDATE
        $PKG_INSTALL docker-ce docker-ce-cli containerd.io docker-compose-plugin
        
    elif [[ "$OS_FAMILY" == *rhel* ]] || [[ "$OS_FAMILY" == *fedora* ]] || [[ "$OS_FAMILY" == *centos* ]]; then
        # Install Docker on CentOS/RHEL
        $PKG_UPDATE
        $PKG_INSTALL yum-utils
        
        # Add Docker repository
        yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        
        $PKG_INSTALL docker-ce docker-ce-cli containerd.io docker-compose-plugin
    fi
    
    # Start and enable Docker
    systemctl start docker
    systemctl enable docker
    
    # Add current user to docker group
    usermod -aG docker $SUDO_USER 2>/dev/null || true
    
    if command -v docker &>/dev/null; then
        echo -e "${GREEN}✅ Docker installed successfully${NC}"
        docker --version
        echo -e "${YELLOW}💡 You may need to log out and back in for group changes to take effect${NC}"
        log_message "INFO" "Docker installed"
    else
        echo -e "${RED}❌ Failed to install Docker${NC}"
        log_message "ERROR" "Failed to install Docker"
        return 1
    fi
}

# --- Security Hardening ---
security_hardening() {
    while true; do
        clear
        echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║                   ${WHITE}${BOLD}SECURITY HARDENING${NC}${BLUE}                        ║${NC}"
        echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
        
        echo -e "\n${CYAN}${BOLD}Security Hardening Options:${NC}"
        echo "1. Install and Configure Fail2Ban"
        echo "2. Configure SSH Security"
        echo "3. Set Strong Password Policy"
        echo "4. Configure Automatic Updates"
        echo "5. Disable Unused Services"
        echo "6. Configure Intrusion Detection (AIDE)"
        echo "7. Set up Log Monitoring"
        echo "8. Configure UFW with Security Rules"
        echo "9. System Security Audit"
        echo "10. Back to Main Menu"
        
        read -p "Enter choice: " security_choice
        
        case "$security_choice" in
            1) install_configure_fail2ban ;;
            2) configure_ssh_security ;;
            3) set_password_policy ;;
            4) configure_auto_updates ;;
            5) disable_unused_services ;;
            6) configure_aide ;;
            7) setup_log_monitoring ;;
            8) configure_security_firewall ;;
            9) security_audit ;;
            10) break ;;
            *) echo -e "${RED}❌ Invalid option${NC}"; sleep 1 ;;
        esac
        
        if [ "$security_choice" != "10" ]; then
            read -p "Press Enter to continue..."
        fi
    done
}

# --- Install and Configure Fail2Ban ---
install_configure_fail2ban() {
    echo -e "\n${YELLOW}${BOLD}🛡️  Installing and Configuring Fail2Ban${NC}"
    echo -e "${BLUE}────────────────────────────────────────${NC}"
    
    # Install Fail2Ban
    if ! command -v fail2ban-server &>/dev/null; then
        echo -e "${BLUE}🔄 Installing Fail2Ban...${NC}"
        $PKG_UPDATE
        $PKG_INSTALL fail2ban
    else
        echo -e "${GREEN}✅ Fail2Ban is already installed${NC}"
    fi
    
    # Create custom configuration
    echo -e "${BLUE}🔧 Configuring Fail2Ban...${NC}"
    
    # Backup existing configuration
    backup_config "/etc/fail2ban/jail.conf" "fail2ban_jail_conf" 2>/dev/null || true
    
    # Create custom jail.local
    cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
# Ban hosts for 10 minutes
bantime = 600
# Host is banned after 3 attempts
maxretry = 3
# Monitor logs for 10 minutes
findtime = 600

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 1800

[nginx-http-auth]
enabled = true
filter = nginx-http-auth
port = http,https
logpath = /var/log/nginx/error.log

[nginx-limit-req]
enabled = true
filter = nginx-limit-req
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 10
EOF
    
    # Start and enable Fail2Ban
    systemctl enable fail2ban
    systemctl restart fail2ban
    
    echo -e "${GREEN}✅ Fail2Ban configured and started${NC}"
    echo -e "${CYAN}📊 Fail2Ban Status:${NC}"
    fail2ban-client status
    
    log_message "INFO" "Fail2Ban installed and configured"
}

# --- Performance Optimization ---
performance_optimization() {
    while true; do
        clear
        echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║                ${WHITE}${BOLD}PERFORMANCE OPTIMIZATION${NC}${BLUE}                    ║${NC}"
        echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
        
        echo -e "\n${CYAN}${BOLD}Performance Optimization Options:${NC}"
        echo "1. System Performance Analysis"
        echo "2. Memory Optimization"
        echo "3. CPU Optimization"
        echo "4. Disk I/O Optimization"
        echo "5. Network Optimization"
        echo "6. Kernel Parameter Tuning"
        echo "7. Install Performance Monitoring Tools"
        echo "8. Configure Swappiness"
        echo "9. Clean Temporary Files"
        echo "10. Back to Main Menu"
        
        read -p "Enter choice: " perf_choice
        
        case "$perf_choice" in
            1) system_performance_analysis ;;
            2) memory_optimization ;;
            3) cpu_optimization ;;
            4) disk_optimization ;;
            5) network_optimization ;;
            6) kernel_parameter_tuning ;;
            7) install_monitoring_tools ;;
            8) configure_swappiness ;;
            9) clean_temporary_files ;;
            10) break ;;
            *) echo -e "${RED}❌ Invalid option${NC}"; sleep 1 ;;
        esac
        
        if [ "$perf_choice" != "10" ]; then
            read -p "Press Enter to continue..."
        fi
    done
}

# --- System Performance Analysis ---
system_performance_analysis() {
    echo -e "\n${CYAN}${BOLD}📊 System Performance Analysis${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    
    echo -e "\n${YELLOW}CPU Information:${NC}"
    lscpu | grep -E "^CPU\(s\)|^Model name|^CPU MHz|^Core\(s\) per socket"
    
    echo -e "\n${YELLOW}Memory Usage:${NC}"
    free -h
    
    echo -e "\n${YELLOW}Disk Usage:${NC}"
    df -h
    
    echo -e "\n${YELLOW}System Load:${NC}"
    uptime
    
    echo -e "\n${YELLOW}Top 10 Processes by CPU:${NC}"
    ps aux --sort=-%cpu | head -11
    
    echo -e "\n${YELLOW}Top 10 Processes by Memory:${NC}"
    ps aux --sort=-%mem | head -11
    
    echo -e "\n${YELLOW}Network Connections:${NC}"
    ss -tuln | wc -l
    echo "Active connections: $(ss -tuln | wc -l)"
    
    echo -e "\n${YELLOW}Disk I/O Statistics:${NC}"
    if command -v iostat &>/dev/null; then
        iostat -x 1 1
    else
        echo "iostat not available (install sysstat package)"
    fi
}

# --- Web Server Management ---
manage_webserver() {
    while true; do
        clear
        echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║                   ${WHITE}${BOLD}WEB SERVER MANAGEMENT${NC}${BLUE}                     ║${NC}"
        echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
        
        echo -e "\n${CYAN}${BOLD}Web Server Management Options:${NC}"
        echo "1. Install Nginx"
        echo "2. Install Apache"
        echo "3. Configure Virtual Host"
        echo "4. Manage Web Server Service"
        echo "5. View Web Server Logs"
        echo "6. Test Web Server Configuration"
        echo "7. Install PHP"
        echo "8. Back to Main Menu"
        
        read -p "Enter choice: " web_choice
        
        case "$web_choice" in
            1) install_nginx ;;
            2) install_apache ;;
            3) configure_virtual_host ;;
            4) manage_webserver_service ;;
            5) view_webserver_logs ;;
            6) test_webserver_config ;;
            7) install_php ;;
            8) break ;;
            *) echo -e "${RED}❌ Invalid option${NC}"; sleep 1 ;;
        esac
        
        if [ "$web_choice" != "8" ]; then
            read -p "Press Enter to continue..."
        fi
    done
}

# --- Install Nginx ---
install_nginx() {
    echo -e "\n${YELLOW}${BOLD}🌐 Installing Nginx${NC}"
    echo -e "${BLUE}────────────────────────────────────────${NC}"
    
    if command -v nginx &>/dev/null; then
        echo -e "${GREEN}✅ Nginx is already installed${NC}"
        nginx -v
        return 0
    fi
    
    echo -e "${BLUE}🔄 Installing Nginx...${NC}"
    $PKG_UPDATE
    $PKG_INSTALL nginx
    
    # Start and enable Nginx
    systemctl start nginx
    systemctl enable nginx
    
    # Configure firewall
    if [ "$FIREWALL_TOOL" = "ufw" ]; then
        ufw allow 'Nginx Full'
    elif [ "$FIREWALL_TOOL" = "firewalld" ]; then
        firewall-cmd --permanent --add-service=http
        firewall-cmd --permanent --add-service=https
        firewall-cmd --reload
    fi
    
    if command -v nginx &>/dev/null; then
        echo -e "${GREEN}✅ Nginx installed successfully${NC}"
        nginx -v
        echo -e "${CYAN}📍 Default web root: /var/www/html${NC}"
        echo -e "${CYAN}📍 Configuration: /etc/nginx/nginx.conf${NC}"
        
        # Create a simple index page
        mkdir -p /var/www/html
        cat > /var/www/html/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Welcome to Nginx!</title>
</head>
<body>
    <h1>Welcome to Nginx!</h1>
    <p>If you can see this page, the Nginx web server is successfully installed and working.</p>
    <p>Configured by Server Manager</p>
</body>
</html>
EOF
        chown -R $WEB_USER:$WEB_USER /var/www/html
        
        log_message "INFO" "Nginx installed and configured"
    else
        echo -e "${RED}❌ Failed to install Nginx${NC}"
        log_message "ERROR" "Failed to install Nginx"
        return 1
    fi
}

# --- Backup Management ---
manage_backups() {
    while true; do
        clear
        echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║                    ${WHITE}${BOLD}BACKUP MANAGEMENT${NC}${BLUE}                         ║${NC}"
        echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
        
        echo -e "\n${CYAN}${BOLD}Backup Management Options:${NC}"
        echo "1. Create System Backup"
        echo "2. Create Database Backup"
        echo "3. Create Web Files Backup"
        echo "4. Schedule Automatic Backups"
        echo "5. Restore from Backup"
        echo "6. List Available Backups"
        echo "7. Configure Backup Settings"
        echo "8. Back to Main Menu"
        
        read -p "Enter choice: " backup_choice
        
        case "$backup_choice" in
            1) create_system_backup ;;
            2) create_database_backup ;;
            3) create_web_backup ;;
            4) schedule_auto_backups ;;
            5) restore_from_backup ;;
            6) list_backups ;;
            7) configure_backup_settings ;;
            8) break ;;
            *) echo -e "${RED}❌ Invalid option${NC}"; sleep 1 ;;
        esac
        
        if [ "$backup_choice" != "8" ]; then
            read -p "Press Enter to continue..."
        fi
    done
}

# --- Create System Backup ---
create_system_backup() {
    echo -e "\n${YELLOW}${BOLD}💾 Creating System Backup${NC}"
    echo -e "${BLUE}────────────────────────────────────────${NC}"
    
    local backup_name="system_backup_$(date +%Y%m%d_%H%M%S)"
    local backup_path="$BACKUP_DIR/$backup_name.tar.gz"
    
    echo -e "${CYAN}Creating backup of important system files...${NC}"
    echo -e "${YELLOW}This may take several minutes...${NC}"
    
    # Create backup directory if not exists
    mkdir -p "$BACKUP_DIR"
    
    # Define what to backup
    local backup_items=(
        "/etc"
        "/home"
        "/var/www"
        "/var/log"
        "/root"
    )
    
    # Create exclusion list
    local exclude_file="$TEMP_DIR/backup_exclude.txt"
    cat > "$exclude_file" << 'EOF'
/var/log/*.log*
/var/log/journal/*
/tmp/*
/var/tmp/*
/proc/*
/sys/*
/dev/*
/run/*
/mnt/*
/media/*
EOF
    
    echo -e "${BLUE}🔄 Creating backup archive...${NC}"
    
    # Create the backup
    if tar -czf "$backup_path" --exclude-from="$exclude_file" "${backup_items[@]}" 2>/dev/null; then
        local backup_size=$(du -h "$backup_path" | cut -f1)
        echo -e "${GREEN}✅ System backup created successfully${NC}"
        echo -e "${CYAN}📍 Backup location: $backup_path${NC}"
        echo -e "${CYAN}📏 Backup size: $backup_size${NC}"
        
        log_message "INFO" "System backup created: $backup_path"
    else
        echo -e "${RED}❌ Failed to create system backup${NC}"
        log_message "ERROR" "Failed to create system backup"
        return 1
    fi
    
    # Clean up
    rm -f "$exclude_file"
}

# --- Advanced System Monitoring ---
advanced_monitoring() {
    while true; do
        clear
        echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║                ${WHITE}${BOLD}ADVANCED SYSTEM MONITORING${NC}${BLUE}                   ║${NC}"
        echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
        
        echo -e "\n${CYAN}${BOLD}Advanced Monitoring Options:${NC}"
        echo "1. Real-time System Monitor"
        echo "2. Network Traffic Monitor"
        echo "3. Disk I/O Monitor"
        echo "4. Process Tree Viewer"
        echo "5. System Resource History"
        echo "6. Log File Monitor"
        echo "7. Service Status Monitor"
        echo "8. Security Events Monitor"
        echo "9. Back to Main Menu"
        
        read -p "Enter choice: " monitor_choice
        
        case "$monitor_choice" in
            1) realtime_system_monitor ;;
            2) network_traffic_monitor ;;
            3) disk_io_monitor ;;
            4) process_tree_viewer ;;
            5) system_resource_history ;;
            6) log_file_monitor ;;
            7) service_status_monitor ;;
            8) security_events_monitor ;;
            9) break ;;
            *) echo -e "${RED}❌ Invalid option${NC}"; sleep 1 ;;
        esac
        
        if [ "$monitor_choice" != "9" ]; then
            read -p "Press Enter to continue..."
        fi
    done
}

# --- Real-time System Monitor ---
realtime_system_monitor() {
    echo -e "${BLUE}Starting enhanced real-time monitoring... (Press Ctrl+C to stop)${NC}"
    echo -e "${YELLOW}Updating every 2 seconds with detailed metrics${NC}\n"
    
    while true; do
        clear
        echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
        echo -e "${CYAN}${BOLD}              ENHANCED REAL-TIME SYSTEM MONITOR${NC}"
        echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}Time: $(date '+%Y-%m-%d %H:%M:%S')${NC} | ${GREEN}Hostname: $(hostname)${NC}"
        echo ""
        
        # System Load and Uptime
        local load=$(uptime | awk -F'load average:' '{print $2}')
        local uptime_info=$(uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}')
        echo -e "${YELLOW}${BOLD}SYSTEM LOAD & UPTIME${NC}"
        echo -e "${GREEN}Uptime: $uptime_info${NC} | ${GREEN}Load Average:$load${NC}"
        echo ""
        
        # CPU Information
        local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
        local cpu_cores=$(nproc)
        echo -e "${YELLOW}${BOLD}CPU METRICS${NC}"
        echo -e "${GREEN}Cores: $cpu_cores${NC} | ${GREEN}Usage: ${cpu_usage}%${NC}"
        
        # CPU per core (if available)
        if command -v mpstat &>/dev/null; then
            echo -e "${CYAN}Per-core usage:${NC}"
            mpstat -P ALL 1 1 | grep -E "Average.*[0-9]" | awk '{printf "Core %s: %.1f%% ", $2, 100-$12}'
            echo ""
        fi
        echo ""
        
        # Memory Information
        local mem_info=$(free -h)
        local mem_used=$(echo "$mem_info" | grep Mem | awk '{print $3}')
        local mem_total=$(echo "$mem_info" | grep Mem | awk '{print $2}')
        local mem_percent=$(echo "$mem_info" | grep Mem | awk '{printf "%.1f", ($3/$2) * 100.0}')
        local swap_used=$(echo "$mem_info" | grep Swap | awk '{print $3}')
        local swap_total=$(echo "$mem_info" | grep Swap | awk '{print $2}')
        
        echo -e "${YELLOW}${BOLD}MEMORY METRICS${NC}"
        echo -e "${GREEN}RAM: $mem_used/$mem_total (${mem_percent}%)${NC} | ${GREEN}Swap: $swap_used/$swap_total${NC}"
        echo ""
        
        # Disk Usage
        echo -e "${YELLOW}${BOLD}DISK USAGE${NC}"
        df -h | grep -E "^/dev/" | while read device size used avail percent mount; do
            echo -e "${GREEN}$mount: $used/$size ($percent) on $device${NC}"
        done
        echo ""
        
        # Network Activity
        echo -e "${YELLOW}${BOLD}NETWORK ACTIVITY${NC}"
        local interface=$(get_primary_interface)
        if [ -n "$interface" ] && [ -f "/sys/class/net/$interface/statistics/rx_bytes" ]; then
            local rx_bytes=$(cat /sys/class/net/$interface/statistics/rx_bytes)
            local tx_bytes=$(cat /sys/class/net/$interface/statistics/tx_bytes)
            local rx_mb=$((rx_bytes / 1024 / 1024))
            local tx_mb=$((tx_bytes / 1024 / 1024))
            echo -e "${GREEN}Interface: $interface${NC} | ${GREEN}RX: ${rx_mb}MB${NC} | ${GREEN}TX: ${tx_mb}MB${NC}"
        fi
        
        # Active connections
        local connections=$(ss -tuln | wc -l)
        echo -e "${GREEN}Active connections: $connections${NC}"
        echo ""
        
        # Top 5 processes by CPU
        echo -e "${YELLOW}${BOLD}TOP 5 PROCESSES (CPU)${NC}"
        ps aux --sort=-%cpu | head -6 | tail -5 | awk '{printf "%-15s %6s %6s %s\n", $1, $3"%", $4"%", $11}'
        echo ""
        
        # Top 5 processes by Memory
        echo -e "${YELLOW}${BOLD}TOP 5 PROCESSES (MEMORY)${NC}"
        ps aux --sort=-%mem | head -6 | tail -5 | awk '{printf "%-15s %6s %6s %s\n", $1, $3"%", $4"%", $11}'
        echo ""
        
        echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
        echo -e "${YELLOW}Press Ctrl+C to exit monitoring${NC}"
        
        sleep 2
    done
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

# --- Enhanced Main Menu ---
main_menu() {
    while true; do
        clear
        echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║                                                                ║${NC}"
        echo -e "${BLUE}║            ${WHITE}${BOLD}PROFESSIONAL LINUX SERVER MANAGER${NC}${BLUE}               ║${NC}"
        echo -e "${BLUE}║                        ${CYAN}Version $SCRIPT_VERSION${NC}${BLUE}                        ║${NC}"
        echo -e "${BLUE}║                    ${CYAN}Memarzade Development${NC}${BLUE}                     ║${NC}"
        echo -e "${BLUE}║                                                                ║${NC}"
        echo -e "${BLUE}╠════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${BLUE}║                          ${WHITE}${BOLD}MAIN MENU${NC}${BLUE}                            ║${NC}"
        echo -e "${BLUE}╠════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${BLUE}║ ${GREEN}1.${NC}  📊 Server Information Dashboard                       ${BLUE}║${NC}"
        echo -e "${BLUE}║ ${GREEN}2.${NC}  🔧 SSH Configuration                                  ${BLUE}║${NC}"
        echo -e "${BLUE}║ ${GREEN}3.${NC}  🏷️  Hostname Configuration                           ${BLUE}║${NC}"
        echo -e "${BLUE}║ ${GREEN}4.${NC}  🌐 DNS Management                                     ${BLUE}║${NC}"
        echo -e "${BLUE}║ ${GREEN}5.${NC}  🛡️  Firewall Management                              ${BLUE}║${NC}"
        echo -e "${BLUE}║ ${GREEN}6.${NC}  📜 SSL/TLS Certificate Management                    ${BLUE}║${NC}"
        echo -e "${BLUE}║ ${GREEN}7.${NC}  👥 User Management                                   ${BLUE}║${NC}"
        echo -e "${BLUE}║ ${GREEN}8.${NC}  🐳 Docker Management                                 ${BLUE}║${NC}"
        echo -e "${BLUE}║ ${GREEN}9.${NC}  🔒 Security Hardening                               ${BLUE}║${NC}"
        echo -e "${BLUE}║ ${GREEN}10.${NC} ⚡ Performance Optimization                         ${BLUE}║${NC}"
        echo -e "${BLUE}║ ${GREEN}11.${NC} 🌐 Web Server Management                            ${BLUE}║${NC}"
        echo -e "${BLUE}║ ${GREEN}12.${NC} 💾 Backup Management                                ${BLUE}║${NC}"
        echo -e "${BLUE}║ ${GREEN}13.${NC} 📈 Advanced System Monitoring                       ${BLUE}║${NC}"
        echo -e "${BLUE}║ ${GREEN}14.${NC} 🔧 System Maintenance                               ${BLUE}║${NC}"
        echo -e "${BLUE}║ ${GREEN}15.${NC} 📁 View Backups                                     ${BLUE}║${NC}"
        echo -e "${BLUE}║ ${GREEN}16.${NC} 📜 View Logs                                        ${BLUE}║${NC}"
        echo -e "${BLUE}║ ${RED}0.${NC}  🚪 Exit                                              ${BLUE}║${NC}"
        echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
        
        echo -e "\n${CYAN}Server: ${BOLD}$(hostname)${NC} ${CYAN}| IP: ${BOLD}$(get_primary_ip | cut -d' ' -f1)${NC} ${CYAN}| SSH: ${BOLD}$(get_current_ssh_port)${NC}"
        
        read -p "Enter your choice: " choice
        
        case "$choice" in
            1) display_server_info; read -p "Press Enter to continue..." ;;
            2) change_ssh_port; read -p "Press Enter to continue..." ;;
            3) change_hostname; read -p "Press Enter to continue..." ;;
            4) manage_dns ;;
            5) manage_firewall ;;
            6) manage_ssl ;;
            7) manage_users ;;
            8) manage_docker ;;
            9) security_hardening ;;
            10) performance_optimization ;;
            11) manage_webserver ;;
            12) manage_backups ;;
            13) advanced_monitoring ;;
            14) system_maintenance ;;
            15) view_backups; read -p "Press Enter to continue..." ;;
            16) view_logs; read -p "Press Enter to continue..." ;;
            0)
                echo -e "\n${GREEN}Thank you for using ${SCRIPT_NAME}!${NC}"
                echo -e "${CYAN}Visit: https://github.com/memarzade-dev/linux-server-manager${NC}"
                echo -e "${CYAN}Goodbye! 👋${NC}"
                log_message "INFO" "Script session ended"
                exit 0
                ;;
            *)
                echo -e "${RED}❌ Invalid option. Please select 0-16.${NC}"
                sleep 1
                ;;
        esac
    done
}

# --- System Maintenance (Enhanced) ---
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
        echo "7. Clean Log Files"
        echo "8. Check Disk Space"
        echo "9. Repair File System"
        echo "10. Back to Main Menu"
        
        read -p "Enter choice: " maint_choice
        
        case "$maint_choice" in
            1) update_system_packages ;;
            2) clean_package_cache ;;
            3) remove_unused_packages ;;
            4) check_system_health ;;
            5) manage_system_services ;;
            6) configure_auto_updates ;;
            7) clean_log_files ;;
            8) check_disk_space ;;
            9) repair_filesystem ;;
            10) break ;;
            *) echo -e "${RED}❌ Invalid option${NC}"; sleep 1 ;;
        esac
        
        if [ "$maint_choice" != "10" ]; then
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

# --- View Backups ---
view_backups() {
    echo -e "\n${YELLOW}${BOLD}📁 Configuration Backups${NC}"
    echo -e "${BLUE}────────────────────────────────────────${NC}"
    
    if [ -d "$BACKUP_DIR" ] && [ "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
        echo -e "${GREEN}Backup directory: $BACKUP_DIR${NC}"
        echo -e "\n${CYAN}Available backups:${NC}"
        ls -la "$BACKUP_DIR" | grep -E '\.(bak|backup|tar\.gz)$' | while read line; do
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

# --- Cleanup function ---
cleanup() {
    # Remove temporary files
    rm -rf "$TEMP_DIR"
    log_message "INFO" "Cleanup completed"
}

# --- Signal handlers ---
trap cleanup EXIT
trap 'echo -e "\n${YELLOW}Script interrupted by user${NC}"; cleanup; exit 1' INT TERM

# --- Main Execution Flow ---
check_root
initialize_script
detect_os
main_menu