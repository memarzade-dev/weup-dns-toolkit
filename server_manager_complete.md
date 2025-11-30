-----

## Professional Linux Server Management Script: SSH, Hostname, and IP Configuration

You're looking for a professional and comprehensive Linux server management script that acts like a control panel, allowing you to easily **edit SSH ports, hostnames, and primary IP addresses**, along with firewall management. This script is designed to be robust and user-friendly, catering to both Debian/Ubuntu and CentOS/RHEL distributions.

**Important Considerations Before Use:**

  * **Execution Environment:** This script is designed for Debian/Ubuntu and CentOS/RHEL based Linux distributions.
  * **Permissions:** You **must have root privileges** to run this script.
  * **Backup:** Always perform a **full backup** of your server before making significant changes.
  * **Security:** While this script helps manage server security, a thorough understanding of Linux security principles is crucial.
  * **Firewall:** This script is configured to manage **UFW** (for Debian/Ubuntu) and **firewalld** (for CentOS/RHEL). If you use a different firewall, you'll need to adjust the relevant sections of the script.

-----

## The Bash Script: `server_pro_manager.sh`

Create a new file named `server_pro_manager.sh` and paste the following code into it:

```bash
#!/bin/bash

# --- Professional Linux Server Management Script ---
# Author: Your Name (Optional)
# Version: 1.1
# Description: A professional script to manage SSH port, hostname, and primary IP,
#              along with firewall settings on a Linux server.

# --- Colors for better UI ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Check for Root Privileges ---
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Error: This script must be run with root privileges.${NC}"
        echo -e "${YELLOW}Please run with 'sudo su -' or 'sudo ./server_pro_manager.sh'.${NC}"
        exit 1
    fi
}

# --- Detect OS Type ---
detect_os() {
    if [ -f /etc/debian_version ]; then
        OS="debian"
        PKG_MANAGER="apt"
        SERVICE_MANAGER="systemctl"
    elif [ -f /etc/redhat-release ]; then
        OS="centos"
        PKG_MANAGER="yum"
        SERVICE_MANAGER="systemctl"
    else
        echo -e "${RED}Unsupported operating system. This script supports Debian/Ubuntu and CentOS/RHEL.${NC}"
        exit 1
    fi
    echo -e "${BLUE}Detected OS: ${OS}${NC}"
}

# --- Get Current SSH Port ---
get_current_ssh_port() {
    SSH_CONFIG="/etc/ssh/sshd_config"
    CURRENT_SSH_PORT=$(grep -i '^Port' "$SSH_CONFIG" | awk '{print $2}' | head -n 1)
    if [ -z "$CURRENT_SSH_PORT" ]; then
        CURRENT_SSH_PORT="22" # Default SSH port
    fi
    echo "$CURRENT_SSH_PORT"
}

# --- Get Primary IP Address (Improved) ---
get_primary_ip() {
    # Attempt to get public IP first
    PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null)
    if [[ -n "$PUBLIC_IP" && "$PUBLIC_IP" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo "$PUBLIC_IP"
    else
        # Fallback to local primary IP
        hostname -I | awk '{print $1}'
    fi
}


# --- Display Server Information ---
display_server_info() {
    echo -e "\n${YELLOW}--- Server Information ---${NC}"
    echo -e "${GREEN}Hostname:${NC} $(hostname)"
    echo -e "${GREEN}Primary IP Address:${NC} $(get_primary_ip)"
    echo -e "${GREEN}Operating System:${NC} $(lsb_release -ds 2>/dev/null || cat /etc/*release 2>/dev/null | grep -m 1 NAME | cut -d'=' -f2 | tr -d '"')"
    echo -e "${GREEN}Kernel Version:${NC} $(uname -r)"
    echo -e "${GREEN}Current SSH Port:${NC} $(get_current_ssh_port)"
    echo -e "${YELLOW}--------------------------${NC}\n"
}

# --- Change SSH Port ---
change_ssh_port() {
    echo -e "\n${YELLOW}--- Change SSH Port ---${NC}"
    CURRENT_PORT=$(get_current_ssh_port)
    echo -e "${BLUE}Your current SSH port: ${CURRENT_PORT}${NC}"
    read -p "Please enter the new SSH port (e.g., 2222): " NEW_PORT

    # Input validation
    if [[ -z "$NEW_PORT" ]]; then
        echo -e "${RED}New port cannot be empty. Operation cancelled.${NC}"
        return 1
    fi
    if ! [[ "$NEW_PORT" =~ ^[0-9]+$ ]] || (( NEW_PORT < 1024 )) || (( NEW_PORT > 65535 )); then
        echo -e "${RED}Invalid port. Please enter a number between 1024 and 65535.${NC}"
        return 1
    fi
    if [[ "$NEW_PORT" -eq "$CURRENT_PORT" ]]; then
        echo -e "${YELLOW}New port is the same as the current port. No changes applied.${NC}"
        return 0
    fi

    SSH_CONFIG="/etc/ssh/sshd_config"
    TEMP_CONFIG=$(mktemp)

    # Safely modify sshd_config
    if grep -q "^Port" "$SSH_CONFIG"; then
        sed "s/^Port .*/Port $NEW_PORT/" "$SSH_CONFIG" > "$TEMP_CONFIG"
    else
        cp "$SSH_CONFIG" "$TEMP_CONFIG"
        echo "Port $NEW_PORT" >> "$TEMP_CONFIG"
    fi

    # Update SELinux if on CentOS
    if [ "$OS" == "centos" ]; then
        echo -e "${BLUE}Updating SELinux for the new port...${NC}"
        semanage port -a -t ssh_port_t -p tcp "$NEW_PORT" 2>/dev/null || true # Add new port
        semanage port -d -t ssh_port_t -p tcp "$CURRENT_PORT" 2>/dev/null || true # Remove old port if it was custom
        echo -e "${GREEN}SELinux updated.${NC}"
    fi

    # Apply changes and restart SSH
    mv "$TEMP_CONFIG" "$SSH_CONFIG"
    echo -e "${GREEN}SSH port changed to ${NEW_PORT}.${NC}"
    restart_ssh_service "$NEW_PORT" "$CURRENT_PORT" # Pass ports for firewall adjustment

    echo -e "${YELLOW}Important: After changing the SSH port, you must connect to the server via the new port.${NC}"
    echo -e "${YELLOW}Also, ensure the new port is open in your firewall.${NC}"
}

# --- Restart SSH Service ---
restart_ssh_service() {
    local NEW_SSH_PORT=$1
    local OLD_SSH_PORT=$2
    echo -e "${BLUE}Restarting SSH service...${NC}"
    if $SERVICE_MANAGER is-active --quiet sshd; then
        $SERVICE_MANAGER restart sshd
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}SSH service restarted successfully.${NC}"
            # Attempt to open new port and close old port in firewall automatically
            if [ "$OS" == "debian" ]; then
                if command -v ufw &> /dev/null && ufw status | grep -q "Status: active"; then
                    echo -e "${BLUE}Adjusting UFW rules for new SSH port...${NC}"
                    ufw allow "$NEW_SSH_PORT"/tcp comment 'New SSH Port by Server Manager'
                    if [ "$OLD_SSH_PORT" -ne 22 ] && [ "$OLD_SSH_PORT" -ne "$NEW_SSH_PORT" ]; then # Don't remove default 22 unless explicitly changed
                        ufw delete allow "$OLD_SSH_PORT"/tcp 2>/dev/null || true
                    fi
                    ufw reload
                    echo -e "${GREEN}UFW rules updated.${NC}"
                fi
            elif [ "$OS" == "centos" ]; then
                if command -v firewall-cmd &> /dev/null && firewall-cmd --state &>/dev/null; then
                    echo -e "${BLUE}Adjusting Firewalld rules for new SSH port...${NC}"
                    firewall-cmd --permanent --add-port="$NEW_SSH_PORT"/tcp
                    if [ "$OLD_SSH_PORT" -ne 22 ] && [ "$OLD_SSH_PORT" -ne "$NEW_SSH_PORT" ]; then # Don't remove default 22 unless explicitly changed
                        firewall-cmd --permanent --remove-port="$OLD_SSH_PORT"/tcp 2>/dev/null || true
                    fi
                    firewall-cmd --reload
                    echo -e "${GREEN}Firewalld rules updated.${NC}"
                fi
            fi
        else
            echo -e "${RED}Error restarting SSH service. Please check manually.${NC}"
        fi
    else
        echo -e "${RED}SSH service is not running or not found.${NC}"
    fi
}

# --- Change Hostname ---
change_hostname() {
    echo -e "\n${YELLOW}--- Change Hostname ---${NC}"
    echo -e "${BLUE}Your current Hostname: $(hostname)${NC}"
    read -p "Please enter the new Hostname: " NEW_HOSTNAME

    # Input validation
    if [[ -z "$NEW_HOSTNAME" ]]; then
        echo -e "${RED}Hostname cannot be empty. Operation cancelled.${NC}"
        return 1
    fi
    if [[ "$NEW_HOSTNAME" =~ [^a-zA-Z0-9.-] ]]; then
        echo -e "${RED}Invalid hostname. Hostnames can only contain letters, numbers, hyphens, and periods.${NC}"
        return 1
    fi
    if [[ "$(hostname)" == "$NEW_HOSTNAME" ]]; then
        echo -e "${YELLOW}New hostname is the same as the current hostname. No changes applied.${NC}"
        return 0
    fi

    hostnamectl set-hostname "$NEW_HOSTNAME"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Hostname successfully changed to ${NEW_HOSTNAME}.${NC}"
        echo -e "${YELLOW}For full effect, you might need to restart your system.${NC}"
    else
        echo -e "${RED}Error changing hostname. Please check logs.${NC}"
    fi
}

# --- Edit Primary IP Address (Informational/Network Manager) ---
# NOTE: Changing primary IP often involves editing network configuration files (e.g., /etc/network/interfaces for Debian,
# /etc/sysconfig/network-scripts/ifcfg-eth0 for CentOS) or using tools like nmcli/ip.
# Directly modifying IP here is risky and dependent on server provider/network setup.
# This function will primarily guide the user.

edit_primary_ip() {
    echo -e "\n${YELLOW}--- Edit Primary IP Address ---${NC}"
    echo -e "${BLUE}Your current Primary IP: $(get_primary_ip)${NC}"
    echo -e "${RED}Warning: Changing the primary IP address is a critical operation and can lead to network disconnection if not done correctly.${NC}"
    echo -e "${YELLOW}This operation usually requires direct modification of network configuration files or using network management tools like 'nmcli' or 'ip utility', depending on your server's setup.${NC}"
    echo -e "${YELLOW}Automating this can be highly risky and may vary significantly across different VPS providers and network configurations.${NC}"
    echo -e "${YELLOW}It is strongly recommended to perform this change via your VPS provider's control panel or by manually editing network configuration files with extreme caution.${NC}"

    echo -e "\n${BLUE}Common network configuration file locations:${NC}"
    echo "  - Debian/Ubuntu: /etc/network/interfaces"
    echo "  - CentOS/RHEL:   /etc/sysconfig/network-scripts/ifcfg-ethX (replace X with your interface number, e.g., eth0, ens33)"

    echo -e "\n${YELLOW}Would you like to open the main network configuration file for your OS for manual editing? (y/n)${NC}"
    read -n 1 -r OPEN_NET_CONFIG
    echo

    if [[ $OPEN_NET_CONFIG =~ ^[Yy]$ ]]; then
        if [ "$OS" == "debian" ]; then
            echo -e "${BLUE}Opening /etc/network/interfaces with nano...${NC}"
            nano /etc/network/interfaces
        elif [ "$OS" == "centos" ]; then
            echo -e "${BLUE}Attempting to find and open primary network interface config...${NC}"
            # Find the primary active interface
            PRIMARY_IFACE=$(ip route | grep default | awk '{print $5}' | head -n 1)
            if [ -n "$PRIMARY_IFACE" ]; then
                echo -e "${BLUE}Opening /etc/sysconfig/network-scripts/ifcfg-${PRIMARY_IFACE} with nano...${NC}"
                nano "/etc/sysconfig/network-scripts/ifcfg-${PRIMARY_IFACE}"
            else
                echo -e "${RED}Could not determine primary network interface. Please locate it manually.${NC}"
                echo -e "${YELLOW}Common interface names: eth0, ens33, enp0s3${NC}"
            fi
        fi
        echo -e "${YELLOW}After manual editing, you will likely need to restart the networking service or reboot for changes to take effect.${NC}"
        echo -e "${BLUE}e.g., systemctl restart networking (Debian/Ubuntu) or systemctl restart network (CentOS/RHEL)${NC}"
    else
        echo -e "${YELLOW}Manual IP editing cancelled.${NC}"
    fi
}

# --- Firewall Management (UFW/Firewalld) ---
manage_firewall() {
    echo -e "\n${YELLOW}--- Firewall Management ---${NC}"

    if [ "$OS" == "debian" ]; then
        manage_ufw
    elif [ "$OS" == "centos" ]; then
        manage_firewalld
    fi
}

# --- UFW Management (Debian/Ubuntu) ---
manage_ufw() {
    echo -e "${BLUE}Managing UFW (Uncomplicated Firewall)...${NC}"
    if ! command -v ufw &> /dev/null; then
        echo -e "${YELLOW}UFW is not installed. Would you like to install it? (y/n)${NC}"
        read -n 1 -r INSTALL_UFW_CHOICE
        echo
        if [[ $INSTALL_UFW_CHOICE =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}Installing UFW...${NC}"
            $PKG_MANAGER update -y
            $PKG_MANAGER install ufw -y
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}UFW installed successfully.${NC}"
                ufw enable
                ufw default deny incoming
                ufw default allow outgoing
                echo -e "${GREEN}UFW enabled and default rules applied (deny incoming, allow outgoing).${NC}"
            else
                echo -e "${RED}Error installing UFW.${NC}"
                return 1
            fi
        else
            echo -e "${YELLOW}UFW installation cancelled.${NC}"
            return 1
        fi
    fi

    echo -e "\n${YELLOW}--- UFW Options ---${NC}"
    echo "1. UFW Status"
    echo "2. Enable/Disable UFW"
    echo "3. Add/Delete Rule (Port)"
    echo "4. Add/Delete Rule (Service)"
    echo "5. Reset UFW Rules"
    echo "b. Back to Main Menu"
    read -p "Please enter your choice: " UFW_CHOICE

    case "$UFW_CHOICE" in
        1)
            ufw status verbose
            ;;
        2)
            echo -e "${BLUE}Enabling/Disabling UFW...${NC}"
            read -p "Do you want to enable (e) or disable (d) UFW? (e/d): " UFW_TOGGLE
            if [[ $UFW_TOGGLE =~ ^[Ee]$ ]]; then
                ufw enable
                echo -e "${GREEN}UFW enabled.${NC}"
            elif [[ $UFW_TOGGLE =~ ^[Dd]$ ]]; then
                ufw disable
                echo -e "${YELLOW}UFW disabled. (Caution: This is not recommended for security!)${NC}"
            else
                echo -e "${RED}Invalid option.${NC}"
            fi
            ;;
        3)
            echo -e "${BLUE}Adding/Deleting UFW Port Rule...${NC}"
            read -p "Do you want to add (a) or delete (d) a rule? (a/d): " RULE_ACTION
            read -p "Enter port number (e.g., 80, 2222): " PORT
            read -p "Enter protocol (tcp/udp/any - default: tcp): " PROTOCOL
            PROTOCOL=${PROTOCOL:-tcp} # Default to tcp

            if ! [[ "$PORT" =~ ^[0-9]+$ ]] || (( PORT < 1 )) || (( PORT > 65535 )); then
                echo -e "${RED}Invalid port number.${NC}"
                return 1
            fi
            if ! [[ "$PROTOCOL" =~ ^(tcp|udp|any)$ ]]; then
                echo -e "${RED}Invalid protocol. Must be tcp, udp, or any.${NC}"
                return 1
            fi

            if [[ $RULE_ACTION =~ ^[Aa]$ ]]; then
                ufw allow "$PORT"/"$PROTOCOL" comment "Port $PORT/$PROTOCOL added by Server Manager"
                echo -e "${GREEN}Rule for port ${PORT}/${PROTOCOL} added.${NC}"
            elif [[ $RULE_ACTION =~ ^[Dd]$ ]]; then
                ufw delete allow "$PORT"/"$PROTOCOL"
                echo -e "${YELLOW}Rule for port ${PORT}/${PROTOCOL} deleted.${NC}"
            else
                echo -e "${RED}Invalid option.${NC}"
            fi
            ufw reload # Apply changes
            ;;
        4)
            echo -e "${BLUE}Adding/Deleting UFW Service Rule...${NC}"
            read -p "Do you want to add (a) or delete (d) a service rule? (a/d): " RULE_ACTION
            read -p "Enter service name (e.g., 'ssh', 'http', 'https'): " SERVICE_NAME

            if [[ -z "$SERVICE_NAME" ]]; then
                echo -e "${RED}Service name cannot be empty. Operation cancelled.${NC}"
                return 1
            fi

            if [[ $RULE_ACTION =~ ^[Aa]$ ]]; then
                ufw allow "$SERVICE_NAME" comment "Service $SERVICE_NAME added by Server Manager"
                echo -e "${GREEN}Rule for service ${SERVICE_NAME} added.${NC}"
            elif [[ $RULE_ACTION =~ ^[Dd]$ ]]; then
                ufw delete allow "$SERVICE_NAME"
                echo -e "${YELLOW}Rule for service ${SERVICE_NAME} deleted.${NC}"
            else
                echo -e "${RED}Invalid option.${NC}"
            fi
            ufw reload # Apply changes
            ;;
        5)
            echo -e "${RED}Warning: Resetting UFW will delete ALL rules.${NC}"
            read -p "Are you sure you want to reset UFW? (y/n): " RESET_UFW_CHOICE
            if [[ $RESET_UFW_CHOICE =~ ^[Yy]$ ]]; then
                ufw reset
                echo -e "${GREEN}UFW reset.${NC}"
                ufw enable
                ufw default deny incoming
                ufw default allow outgoing
                echo -e "${GREEN}UFW re-enabled with default rules.${NC}"
            else
                echo -e "${YELLOW}UFW reset cancelled.${NC}"
            fi
            ;;
        b)
            echo -e "${YELLOW}Returning to main menu.${NC}"
            ;;
        *)
            echo -e "${RED}Invalid option. Please select a valid number.${NC}"
            ;;
    esac
}

# --- Firewalld Management (CentOS/RHEL) ---
manage_firewalld() {
    echo -e "${BLUE}Managing Firewalld...${NC}"
    if ! command -v firewall-cmd &> /dev/null; then
        echo -e "${YELLOW}Firewalld is not installed. Would you like to install it? (y/n)${NC}"
        read -n 1 -r INSTALL_FIREWALLD_CHOICE
        echo
        if [[ $INSTALL_FIREWALLD_CHOICE =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}Installing Firewalld...${NC}"
            $PKG_MANAGER update -y
            $PKG_MANAGER install firewalld -y
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}Firewalld installed successfully.${NC}"
                $SERVICE_MANAGER start firewalld
                $SERVICE_MANAGER enable firewalld
                echo -e "${GREEN}Firewalld enabled.${NC}"
            else
                echo -e "${RED}Error installing Firewalld.${NC}"
                return 1
            fi
        else
            echo -e "${YELLOW}Firewalld installation cancelled.${NC}"
            return 1
        fi
    fi

    echo -e "\n${YELLOW}--- Firewalld Options ---${NC}"
    echo "1. Firewalld Status"
    echo "2. Start/Stop Firewalld"
    echo "3. Add/Remove Port"
    echo "4. Add/Remove Service"
    echo "5. Reload Firewalld"
    echo "6. Reset Firewalld (Clear all rules)"
    echo "b. Back to Main Menu"
    read -p "Please enter your choice: " FIREWALLD_CHOICE

    case "$FIREWALLD_CHOICE" in
        1)
            firewall-cmd --state
            echo -e "\n${BLUE}Active Zone Rules:${NC}"
            firewall-cmd --list-all
            ;;
        2)
            echo -e "${BLUE}Starting/Stopping Firewalld...${NC}"
            read -p "Do you want to start (s) or stop (p) Firewalld? (s/p): " FIREWALLD_TOGGLE
            if [[ $FIREWALLD_TOGGLE =~ ^[Ss]$ ]]; then
                $SERVICE_MANAGER start firewalld
                $SERVICE_MANAGER enable firewalld
                echo -e "${GREEN}Firewalld started and enabled.${NC}"
            elif [[ $FIREWALLD_TOGGLE =~ ^[Pp]$ ]]; then
                $SERVICE_MANAGER stop firewalld
                $SERVICE_MANAGER disable firewalld
                echo -e "${YELLOW}Firewalld stopped and disabled. (Caution: This is not recommended for security!)${NC}"
            else
                echo -e "${RED}Invalid option.${NC}"
            fi
            ;;
        3)
            echo -e "${BLUE}Adding/Removing Firewalld Port...${NC}"
            read -p "Do you want to add (a) or remove (r) a port? (a/r): " PORT_ACTION
            read -p "Enter port specification (e.g., 80/tcp, 2222/tcp): " PORT_SPEC

            if [[ -z "$PORT_SPEC" ]]; then
                echo -e "${RED}Port specification cannot be empty. Operation cancelled.${NC}"
                return 1
            fi
            # Simple regex to check for port/protocol format
            if ! [[ "$PORT_SPEC" =~ ^[0-9]{1,5}/(tcp|udp)$ ]]; then
                 echo -e "${RED}Invalid port format. Use 'PORT/PROTOCOL' (e.g., 80/tcp).${NC}"
                 return 1
            fi

            if [[ $PORT_ACTION =~ ^[Aa]$ ]]; then
                firewall-cmd --permanent --add-port="$PORT_SPEC"
                echo -e "${GREEN}Port ${PORT_SPEC} added to permanent rules.${NC}"
            elif [[ $PORT_ACTION =~ ^[Rr]$ ]]; then
                firewall-cmd --permanent --remove-port="$PORT_SPEC"
                echo -e "${YELLOW}Port ${PORT_SPEC} removed from permanent rules.${NC}"
            else
                echo -e "${RED}Invalid option.${NC}"
            fi
            firewall-cmd --reload # Apply changes
            ;;
        4)
            echo -e "${BLUE}Adding/Removing Firewalld Service...${NC}"
            read -p "Do you want to add (a) or remove (r) a service? (a/r): " SERVICE_ACTION
            read -p "Enter service name (e.g., http, https, ssh): " SERVICE_NAME

            if [[ -z "$SERVICE_NAME" ]]; then
                echo -e "${RED}Service name cannot be empty. Operation cancelled.${NC}"
                return 1
            fi
            # Basic validation for common services
            if ! firewall-cmd --get-services | grep -q "\b$SERVICE_NAME\b"; then
                echo -e "${YELLOW}Warning: Service '${SERVICE_NAME}' might not be a standard Firewalld service. Continuing anyway.${NC}"
            fi

            if [[ $SERVICE_ACTION =~ ^[Aa]$ ]]; then
                firewall-cmd --permanent --add-service="$SERVICE_NAME"
                echo -e "${GREEN}Service ${SERVICE_NAME} added to permanent rules.${NC}"
            elif [[ $SERVICE_ACTION =~ ^[Rr]$ ]]; then
                firewall-cmd --permanent --remove-service="$SERVICE_NAME"
                echo -e "${YELLOW}Service ${SERVICE_NAME} removed from permanent rules.${NC}"
            else
                echo -e "${RED}Invalid option.${NC}"
            fi
            firewall-cmd --reload # Apply changes
            ;;
        5)
            echo -e "${BLUE}Reloading Firewalld to apply permanent changes...${NC}"
            firewall-cmd --reload
            echo -e "${GREEN}Firewalld reloaded.${NC}"
            ;;
        6)
            echo -e "${RED}Warning: Resetting Firewalld will clear ALL permanent rules and revert to default.${NC}"
            read -p "Are you sure you want to reset Firewalld? (y/n): " RESET_FIREWALLD_CHOICE
            if [[ $RESET_FIREWALLD_CHOICE =~ ^[Yy]$ ]]; then
                firewall-cmd --zone=public --remove-all --permanent
                # Re-add essential services if desired, e.g., SSH
                # firewall-cmd --zone=public --add-service=ssh --permanent
                # Add default incoming deny (optional, zones usually handle this)
                firewall-cmd --reload
                echo -e "${GREEN}Firewalld reset. All permanent rules cleared. You may need to reconfigure essential services like SSH.${NC}"
            else
                echo -e "${YELLOW}Firewalld reset cancelled.${NC}"
            fi
            ;;
        b)
            echo -e "${YELLOW}Returning to main menu.${NC}"
            ;;
        *)
            echo -e "${RED}Invalid option. Please select a valid number.${NC}"
            ;;
    esac
}

# --- Main Menu ---
main_menu() {
    while true; do
        clear
        echo -e "${BLUE}========================================${NC}"
        echo -e "${BLUE}  Linux Server Professional Manager     ${NC}"
        echo -e "${BLUE}========================================${NC}"
        echo -e "${GREEN}1. Display Server Information${NC}"
        echo -e "${GREEN}2. Change SSH Port${NC}"
        echo -e "${GREEN}3. Change Hostname${NC}"
        echo -e "${GREEN}4. Edit Primary IP Address (Manual Guide)${NC}"
        echo -e "${GREEN}5. Firewall Management (UFW/Firewalld)${NC}"
        echo -e "${RED}6. Exit${NC}"
        echo -e "${BLUE}----------------------------------------${NC}"

        read -p "Please select an option: " choice

        case "$choice" in
            1)
                display_server_info
                read -p "Press Enter to continue..."
                ;;
            2)
                change_ssh_port
                read -p "Press Enter to continue..."
                ;;
            3)
                change_hostname
                read -p "Press Enter to continue..."
                ;;
            4)
                edit_primary_ip
                read -p "Press Enter to continue..."
                ;;
            5)
                manage_firewall
                read -p "Press Enter to continue..."
                ;;
            6)
                echo -e "${GREEN}Exiting. Goodbye!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option. Please select a number between 1 and 6.${NC}"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# --- Main Execution Flow ---
check_root
detect_os
main_menu
```

-----

## How to Use the Script:

1.  **Create the file:**
    On your server, create a new file (e.g., `server_pro_manager.sh`):

    ```bash
    nano server_pro_manager.sh
    ```

2.  **Paste the code:**
    Copy the entire script above and paste it into the `server_pro_manager.sh` file. Save and exit (in nano, `Ctrl+X`, then `Y`, then `Enter`).

3.  **Grant execution permissions:**
    Make the script executable:

    ```bash
    chmod +x server_pro_manager.sh
    ```

4.  **Run the script:**
    Execute the script with root privileges:

    ```bash
    sudo ./server_pro_manager.sh
    ```

    Alternatively, if you're already logged in as the root user:

    ```bash
    ./server_pro_manager.sh
    ```

-----

## Key Features and Enhancements:

  * **Improved User Interface (UI):** Utilizes clear color-coding for better readability and feedback.
  * **Robust Input Validation:** Each function now includes more stringent checks for user input to prevent common errors (e.g., invalid port numbers, empty hostnames).
  * **Automatic OS Detection:** Intelligently identifies your operating system (Debian/Ubuntu or CentOS/RHEL) to use the correct package manager (`apt` or `yum`) and firewall tool (`ufw` or `firewalld`).
  * **Root Privilege Check:** Ensures the script is run with necessary permissions, providing clear instructions if not.

### Detailed Functionality:

1.  **Display Server Information (Option 1):**

      * **Hostname:** Shows the server's current hostname.
      * **Primary IP Address:** Now uses `curl ifconfig.me` or `ipinfo.io/ip` to attempt to fetch the **public IP address** first, falling back to the local primary IP if external services are unreachable. This provides a more accurate view for VPS environments.
      * **Operating System:** Displays detailed OS information.
      * **Kernel Version:** Shows the Linux kernel version.
      * **Current SSH Port:** Indicates the port your SSH daemon is listening on.

2.  **Change SSH Port (Option 2):**

      * Allows you to modify the SSH port from its default (usually 22) to any valid custom port (1024-65535).
      * **Automatic Firewall Rule Adjustment:** After successfully changing and restarting the SSH service, the script will attempt to **automatically add the new SSH port and remove the old one** (if it was custom and not port 22) in your active firewall (UFW or Firewalld). This significantly reduces the risk of locking yourself out.
      * **SELinux Integration (for CentOS):** Automatically updates SELinux policy to allow the new SSH port, a crucial step for CentOS security.
      * **Important Warning:** Reminds you to use the new port for future connections.

3.  **Change Hostname (Option 3):**

      * Provides a guided way to change your server's hostname.
      * Includes input validation to ensure the new hostname is in a valid format.
      * Advises that a system restart might be needed for full effect.

4.  **Edit Primary IP Address (Manual Guide) (Option 4):**

      * **Crucial Note:** Directly automating primary IP changes in a generic script is **highly risky and not recommended**, as network configurations vary wildly between VPS providers, cloud platforms, and local setups.
      * Instead, this option acts as a **professional guide**. It displays your current primary IP and provides clear warnings about the risks involved.
      * It offers to **open the most common network configuration file** for your specific OS (`/etc/network/interfaces` for Debian/Ubuntu or `/etc/sysconfig/network-scripts/ifcfg-ethX` for CentOS/RHEL) using `nano`, allowing you to manually make changes.
      * It also reminds you to restart networking services or reboot after manual edits. This approach prioritizes **safety and user awareness** over a potentially dangerous automated process.

5.  **Firewall Management (UFW/Firewalld) (Option 5):**

      * **Intelligent Firewall Detection:** Automatically uses UFW for Debian/Ubuntu and Firewalld for CentOS/RHEL.
      * **On-Demand Installation:** If the respective firewall is not installed, the script will prompt you to install it.
      * **UFW (Debian/Ubuntu):**
          * **Status:** Shows UFW's active status and rules.
          * **Enable/Disable:** Toggles UFW's state with appropriate warnings.
          * **Add/Delete Port Rule:** Allows opening/closing specific TCP/UDP ports.
          * **Add/Delete Service Rule:** Enables/disables access for common services (e.g., HTTP, HTTPS, SSH) by name.
          * **Reset Rules:** Provides an option to clear all UFW rules and revert to a secure default (deny incoming, allow outgoing).
      * **Firewalld (CentOS/RHEL):**
          * **Status:** Displays Firewalld's state and active zone rules.
          * **Start/Stop:** Manages the Firewalld service with warnings.
          * **Add/Remove Port:** Allows opening/closing specific port/protocol combinations (e.g., `80/tcp`).
          * **Add/Remove Service:** Enables/disables common services (e.g., `http`, `https`, `ssh`).
          * **Reload Firewalld:** Applies any permanent changes made to Firewalld rules.
          * **Reset Firewalld:** Clears all permanent rules, essentially resetting Firewalld to a clean state.

This script provides a robust and user-friendly control panel for essential server configurations. By focusing on safety and clear guidance for critical operations like IP editing, it empowers you to manage your server like a professional.

Do you have any specific services or configurations you'd like to add to this server management script next?
