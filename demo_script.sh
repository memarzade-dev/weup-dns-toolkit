#!/bin/bash

# Professional Linux Server Manager - Demo and Examples
# Version: 3.0
# Description: Demonstration script showing usage examples and automation scenarios
# Author: Memarzade Development Team
# License: MIT

# --- Configuration ---
readonly SCRIPT_NAME="Server Manager Demo"
readonly SCRIPT_VERSION="3.0"
readonly MAIN_SCRIPT="./server_manager.sh"

# --- Colors ---
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# --- Helper Functions ---
print_header() {
    local title="$1"
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║$(printf "%64s" " ")║${NC}"
    echo -e "${BLUE}║$(printf "%*s" $(((64 + ${#title}) / 2)) "$title")$(printf "%*s" $(((64 - ${#title}) / 2)) " ")║${NC}"
    echo -e "${BLUE}║$(printf "%64s" " ")║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
}

print_section() {
    local title="$1"
    echo -e "\n${CYAN}${title}${NC}"
    echo -e "${BLUE}$(printf '=%.0s' {1..60})${NC}"
}

print_example() {
    local title="$1"
    local description="$2"
    echo -e "\n${YELLOW}📝 Example: $title${NC}"
    echo -e "${GREEN}$description${NC}"
}

print_code() {
    local code="$1"
    echo -e "${PURPLE}$code${NC}"
}

# --- Demo Functions ---

# Demo 1: Basic Server Information
demo_server_info() {
    print_example "Server Information Display" "Shows comprehensive server information including system specs, resource usage, and service status"
    
    print_code "# Display server information dashboard"
    print_code "echo '1' | sudo $MAIN_SCRIPT"
    
    echo -e "\n${CYAN}This will show:${NC}"
    echo "• Hostname and IP address information"
    echo "• Operating system details"
    echo "• Current resource usage (CPU, Memory, Disk)"
    echo "• Service status (SSH, Firewall, Docker, etc.)"
    echo "• System uptime and load averages"
}

# Demo 2: SSH Configuration
demo_ssh_config() {
    print_example "SSH Port Configuration" "Demonstrates how to change SSH port with automatic firewall updates"
    
    print_code "# Change SSH port to 2222"
    print_code "echo -e '2\n2222\ny' | sudo $MAIN_SCRIPT"
    
    echo -e "\n${CYAN}This will:${NC}"
    echo "• Backup current SSH configuration"
    echo "• Change SSH port to 2222"
    echo "• Validate configuration syntax"
    echo "• Restart SSH service"
    echo "• Update firewall rules automatically"
    echo "• Test new port connectivity"
    
    echo -e "\n${YELLOW}⚠️  Note: Always have alternative access before changing SSH port!${NC}"
}

# Demo 3: DNS Management
demo_dns_config() {
    print_example "DNS Configuration" "Shows how to configure DNS servers for better performance and privacy"
    
    print_code "# Configure Cloudflare DNS"
    print_code "echo -e '4\n2\n2' | sudo $MAIN_SCRIPT"
    
    echo -e "\n${CYAN}This will:${NC}"
    echo "• Access DNS Management menu"
    echo "• Set Cloudflare DNS (1.1.1.1, 1.0.0.1)"
    echo "• Backup current DNS configuration"
    echo "• Test DNS resolution"
    echo "• Update /etc/resolv.conf"
    
    print_code ""
    print_code "# Configure DNS over HTTPS for privacy"
    print_code "echo -e '4\n7\n1' | sudo $MAIN_SCRIPT"
}

# Demo 4: Security Hardening
demo_security_hardening() {
    print_example "Security Hardening" "Comprehensive security setup including Fail2Ban and SSH hardening"
    
    print_code "# Complete security hardening setup"
    print_code "echo -e '9\n1\ny' | sudo $MAIN_SCRIPT"  # Install Fail2Ban
    print_code "echo -e '9\n2\ny' | sudo $MAIN_SCRIPT"  # SSH Security
    
    echo -e "\n${CYAN}This will:${NC}"
    echo "• Install and configure Fail2Ban"
    echo "• Harden SSH configuration"
    echo "• Disable root login"
    echo "• Configure intrusion detection"
    echo "• Set up automated ban rules"
    echo "• Apply security best practices"
    
    print_code ""
    print_code "# Run security audit"
    print_code "echo -e '9\n9' | sudo $MAIN_SCRIPT"
}

# Demo 5: Docker Management
demo_docker_management() {
    print_example "Docker Installation and Management" "Complete Docker setup and container management"
    
    print_code "# Install Docker"
    print_code "echo -e '8\n1\ny' | sudo $MAIN_SCRIPT"
    
    echo -e "\n${CYAN}Docker installation includes:${NC}"
    echo "• Docker CE and Docker Compose"
    echo "• User group configuration"
    echo "• Service setup and startup"
    echo "• Firewall configuration"
    
    print_code ""
    print_code "# List containers and images"
    print_code "echo -e '8\n3' | sudo $MAIN_SCRIPT"  # List containers
    print_code "echo -e '8\n4' | sudo $MAIN_SCRIPT"  # List images
}

# Demo 6: Web Server Setup
demo_web_server() {
    print_example "Web Server Installation" "Nginx installation with SSL certificate setup"
    
    print_code "# Install Nginx web server"
    print_code "echo -e '11\n1' | sudo $MAIN_SCRIPT"
    
    echo -e "\n${CYAN}This will:${NC}"
    echo "• Install and configure Nginx"
    echo "• Create default website"
    echo "• Configure firewall rules"
    echo "• Set proper permissions"
    echo "• Start and enable service"
    
    print_code ""
    print_code "# Generate SSL certificate"
    print_code "echo -e '6\n1\ny' | sudo $MAIN_SCRIPT"  # Install Certbot
    print_code "echo -e '6\n2\nexample.com\nadmin@example.com' | sudo $MAIN_SCRIPT"
}

# Demo 7: System Monitoring
demo_monitoring() {
    print_example "Advanced System Monitoring" "Real-time system monitoring with performance metrics"
    
    print_code "# Launch real-time monitoring"
    print_code "echo -e '13\n1' | sudo $MAIN_SCRIPT"
    
    echo -e "\n${CYAN}Monitoring features:${NC}"
    echo "• Real-time CPU, memory, and disk usage"
    echo "• Network traffic monitoring"
    echo "• Process monitoring by CPU and memory"
    echo "• Service status tracking"
    echo "• Live performance metrics"
    
    print_code ""
    print_code "# Network traffic monitor"
    print_code "echo -e '13\n2' | sudo $MAIN_SCRIPT"
}

# Demo 8: Backup Management
demo_backup_management() {
    print_example "Automated Backup System" "Complete backup solution for system and data"
    
    print_code "# Create system backup"
    print_code "echo -e '12\n1\ny' | sudo $MAIN_SCRIPT"
    
    echo -e "\n${CYAN}Backup includes:${NC}"
    echo "• System configuration files (/etc)"
    echo "• User home directories (/home)"
    echo "• Web server files (/var/www)"
    echo "• Important logs (/var/log)"
    echo "• Root user files (/root)"
    
    print_code ""
    print_code "# Schedule automatic backups"
    print_code "echo -e '12\n4\ndaily\n2\n/backup/remote' | sudo $MAIN_SCRIPT"
}

# Demo 9: Performance Optimization
demo_performance() {
    print_example "Performance Optimization" "System performance analysis and optimization"
    
    print_code "# System performance analysis"
    print_code "echo -e '10\n1' | sudo $MAIN_SCRIPT"
    
    echo -e "\n${CYAN}Performance analysis includes:${NC}"
    echo "• CPU utilization and load analysis"
    echo "• Memory usage optimization"
    echo "• Disk I/O performance metrics"
    echo "• Network throughput analysis"
    echo "• System bottleneck identification"
    
    print_code ""
    print_code "# Configure system swappiness"
    print_code "echo -e '10\n8\n10' | sudo $MAIN_SCRIPT"
}

# Demo 10: Automation Examples
demo_automation() {
    print_example "Automation Scripts" "Examples of automating server management tasks"
    
    echo -e "\n${CYAN}Server Setup Automation:${NC}"
    
    cat << 'EOF'
#!/bin/bash
# Automated server setup script

# Update system packages
echo -e '14\n1\ny' | sudo ./server_manager.sh

# Configure security
echo -e '9\n1\ny' | sudo ./server_manager.sh  # Install Fail2Ban
echo -e '9\n2\ny' | sudo ./server_manager.sh  # SSH hardening

# Install web server
echo -e '11\n1' | sudo ./server_manager.sh    # Install Nginx

# Configure firewall
echo -e '5\n5\ny' | sudo ./server_manager.sh  # Quick security setup

# Create backup
echo -e '12\n1\ny' | sudo ./server_manager.sh # System backup

echo "✅ Server setup completed!"
EOF

    echo -e "\n${CYAN}Monitoring Automation:${NC}"
    
    cat << 'EOF'
#!/bin/bash
# Daily monitoring script

# Check system health
echo -e '14\n4' | sudo ./server_manager.sh > /var/log/daily_health.log

# Security audit
echo -e '9\n9' | sudo ./server_manager.sh >> /var/log/daily_security.log

# Performance analysis
echo -e '10\n1' | sudo ./server_manager.sh >> /var/log/daily_performance.log

# Send reports via email (if configured)
mail -s "Daily Server Report" admin@example.com < /var/log/daily_health.log
EOF
}

# Demo 11: Emergency Recovery
demo_emergency_recovery() {
    print_example "Emergency Recovery Procedures" "What to do when things go wrong"
    
    echo -e "\n${CYAN}SSH Locked Out Recovery:${NC}"
    print_code "# Via console/KVM access:"
    print_code "sudo systemctl stop sshd"
    print_code "sudo nano /etc/ssh/sshd_config  # Reset port to 22"
    print_code "sudo systemctl start sshd"
    
    echo -e "\n${CYAN}Firewall Lockout Recovery:${NC}"
    print_code "# Reset firewall rules"
    print_code "sudo ufw --force reset"
    print_code "sudo ufw allow 22/tcp"
    print_code "sudo ufw enable"
    
    echo -e "\n${CYAN}Configuration Restore:${NC}"
    print_code "# Restore from backup"
    print_code "ls /etc/server_manager_backups/"
    print_code "sudo cp /etc/server_manager_backups/sshd_config_20241230_120000.bak /etc/ssh/sshd_config"
    print_code "sudo systemctl restart sshd"
}

# Demo 12: Advanced Use Cases
demo_advanced_use_cases() {
    print_example "Advanced Use Cases" "Complex scenarios and integrations"
    
    echo -e "\n${CYAN}Multi-Server Management:${NC}"
    cat << 'EOF'
#!/bin/bash
# Manage multiple servers
SERVERS=("server1.example.com" "server2.example.com" "server3.example.com")

for server in "${SERVERS[@]}"; do
    echo "Configuring $server..."
    ssh root@$server 'bash -s' < server_manager.sh
done
EOF

    echo -e "\n${CYAN}CI/CD Integration:${NC}"
    cat << 'EOF'
# GitHub Actions workflow snippet
- name: Configure Production Server
  run: |
    ssh production-server 'echo -e "14\n1\ny" | sudo ./server_manager.sh'
    ssh production-server 'echo -e "9\n9" | sudo ./server_manager.sh'
EOF

    echo -e "\n${CYAN}Monitoring Integration:${NC}"
    cat << 'EOF'
#!/bin/bash
# Integrate with monitoring systems
./server_manager.sh --export-metrics > metrics.json
curl -X POST -H "Content-Type: application/json" \
     -d @metrics.json \
     https://monitoring.example.com/api/metrics
EOF
}

# Main demo menu
show_demo_menu() {
    while true; do
        clear
        print_header "PROFESSIONAL LINUX SERVER MANAGER - DEMO"
        
        echo -e "\n${CYAN}Choose a demonstration:${NC}"
        echo -e "${GREEN}1.${NC}  📊 Server Information Display"
        echo -e "${GREEN}2.${NC}  🔧 SSH Configuration"
        echo -e "${GREEN}3.${NC}  🌐 DNS Management"
        echo -e "${GREEN}4.${NC}  🔒 Security Hardening"
        echo -e "${GREEN}5.${NC}  🐳 Docker Management"
        echo -e "${GREEN}6.${NC}  🌍 Web Server Setup"
        echo -e "${GREEN}7.${NC}  📈 System Monitoring"
        echo -e "${GREEN}8.${NC}  💾 Backup Management"
        echo -e "${GREEN}9.${NC}  ⚡ Performance Optimization"
        echo -e "${GREEN}10.${NC} 🤖 Automation Examples"
        echo -e "${GREEN}11.${NC} 🚨 Emergency Recovery"
        echo -e "${GREEN}12.${NC} 🎯 Advanced Use Cases"
        echo -e "${GREEN}13.${NC} 🏃 Run Quick Demo"
        echo -e "${RED}0.${NC}  🚪 Exit Demo"
        
        echo ""
        read -p "Enter your choice (0-13): " choice
        
        case "$choice" in
            1) clear; print_section "SERVER INFORMATION DEMO"; demo_server_info ;;
            2) clear; print_section "SSH CONFIGURATION DEMO"; demo_ssh_config ;;
            3) clear; print_section "DNS MANAGEMENT DEMO"; demo_dns_config ;;
            4) clear; print_section "SECURITY HARDENING DEMO"; demo_security_hardening ;;
            5) clear; print_section "DOCKER MANAGEMENT DEMO"; demo_docker_management ;;
            6) clear; print_section "WEB SERVER DEMO"; demo_web_server ;;
            7) clear; print_section "SYSTEM MONITORING DEMO"; demo_monitoring ;;
            8) clear; print_section "BACKUP MANAGEMENT DEMO"; demo_backup_management ;;
            9) clear; print_section "PERFORMANCE OPTIMIZATION DEMO"; demo_performance ;;
            10) clear; print_section "AUTOMATION EXAMPLES"; demo_automation ;;
            11) clear; print_section "EMERGENCY RECOVERY"; demo_emergency_recovery ;;
            12) clear; print_section "ADVANCED USE CASES"; demo_advanced_use_cases ;;
            13) run_quick_demo ;;
            0) 
                echo -e "\n${GREEN}Thank you for exploring Professional Linux Server Manager!${NC}"
                echo -e "${CYAN}Visit: https://github.com/memarzade-dev/linux-server-manager${NC}"
                exit 0
                ;;
            *) 
                echo -e "${RED}❌ Invalid option. Please select 0-13.${NC}"
                sleep 1
                ;;
        esac
        
        if [ "$choice" != "13" ] && [ "$choice" != "0" ]; then
            echo -e "\n${YELLOW}Press Enter to continue...${NC}"
            read
        fi
    done
}

# Quick demo function
run_quick_demo() {
    clear
    print_header "QUICK DEMONSTRATION"
    
    echo -e "\n${CYAN}This quick demo will show the main features in action.${NC}"
    echo -e "${YELLOW}⚠️  This will run actual commands on your system!${NC}"
    echo -e "${RED}Only proceed if you understand the implications.${NC}"
    
    read -p "Continue with quick demo? (y/N): " confirm
    
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Demo cancelled.${NC}"
        return 0
    fi
    
    echo -e "\n${BLUE}🚀 Starting quick demonstration...${NC}"
    
    # Check if main script exists
    if [ ! -f "$MAIN_SCRIPT" ]; then
        echo -e "${RED}❌ Main script not found: $MAIN_SCRIPT${NC}"
        echo -e "${YELLOW}Please ensure server_manager.sh is in the current directory.${NC}"
        return 1
    fi
    
    # Make sure it's executable
    chmod +x "$MAIN_SCRIPT"
    
    echo -e "\n${CYAN}1. Displaying server information...${NC}"
    sleep 2
    echo -e '1\n0' | sudo "$MAIN_SCRIPT"
    
    echo -e "\n${CYAN}2. Checking system health...${NC}"
    sleep 2
    echo -e '14\n4\n0' | sudo "$MAIN_SCRIPT"
    
    echo -e "\n${CYAN}3. Viewing current firewall status...${NC}"
    sleep 2
    echo -e '5\n1\n7\n0' | sudo "$MAIN_SCRIPT"
    
    echo -e "\n${GREEN}✅ Quick demo completed!${NC}"
    echo -e "${CYAN}The script is ready for full usage.${NC}"
}

# Usage information
show_usage() {
    echo -e "${CYAN}Professional Linux Server Manager - Demo Script${NC}"
    echo -e "${GREEN}Usage: $0 [option]${NC}"
    echo ""
    echo -e "${YELLOW}Options:${NC}"
    echo "  --help, -h     Show this help message"
    echo "  --version, -v  Show version information"
    echo "  --quick, -q    Run quick demo"
    echo "  --list, -l     List all available demos"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo "  $0              # Interactive demo menu"
    echo "  $0 --quick      # Run quick demonstration"
    echo "  $0 --list       # List all demo options"
}

# List all demos
list_demos() {
    echo -e "${CYAN}Available Demonstrations:${NC}"
    echo ""
    echo -e "${GREEN}Basic Features:${NC}"
    echo "  • Server Information Display"
    echo "  • SSH Configuration"
    echo "  • DNS Management"
    echo ""
    echo -e "${GREEN}Security Features:${NC}"
    echo "  • Security Hardening"
    echo "  • Emergency Recovery"
    echo ""
    echo -e "${GREEN}Service Management:${NC}"
    echo "  • Docker Management"
    echo "  • Web Server Setup"
    echo ""
    echo -e "${GREEN}System Administration:${NC}"
    echo "  • System Monitoring"
    echo "  • Backup Management"
    echo "  • Performance Optimization"
    echo ""
    echo -e "${GREEN}Advanced Topics:${NC}"
    echo "  • Automation Examples"
    echo "  • Advanced Use Cases"
}

# Main execution
main() {
    case "${1:-}" in
        --help|-h)
            show_usage
            ;;
        --version|-v)
            echo -e "${CYAN}$SCRIPT_NAME v$SCRIPT_VERSION${NC}"
            echo -e "${GREEN}Professional Linux Server Manager Demo${NC}"
            ;;
        --quick|-q)
            run_quick_demo
            ;;
        --list|-l)
            list_demos
            ;;
        "")
            show_demo_menu
            ;;
        *)
            echo -e "${RED}❌ Unknown option: $1${NC}"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"