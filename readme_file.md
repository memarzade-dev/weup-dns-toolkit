# 🚀 Professional Linux Server Manager

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell Script](https://img.shields.io/badge/Script-Bash-green.svg)](https://www.gnu.org/software/bash/)
[![Linux](https://img.shields.io/badge/OS-Linux-blue.svg)](https://www.linux.org/)
[![Version](https://img.shields.io/badge/Version-3.0-brightgreen.svg)](https://github.com/memarzade-dev/linux-server-manager)

A comprehensive, professional-grade Linux server management script that provides a user-friendly control panel for managing SSH, DNS, SSL/TLS certificates, users, Docker, security hardening, and much more. Designed for both beginners and advanced Linux administrators.

## 📋 Table of Contents

- [Features](#-features)
- [Quick Start](#-quick-start)
- [Installation](#-installation)
- [Usage](#-usage)
- [System Requirements](#-system-requirements)
- [Advanced Features](#-advanced-features)
- [Security Features](#-security-features)
- [Screenshots](#-screenshots)
- [Contributing](#-contributing)
- [Troubleshooting](#-troubleshooting)
- [License](#-license)
- [Support](#-support)

## ✨ Features

### 🔧 **Core System Management**
- **SSH Configuration**: Change SSH ports, configure security settings, manage SSH keys
- **Hostname Management**: Easy hostname changes with validation
- **Network Configuration**: View and manage network interfaces
- **DNS Management**: Configure DNS servers, DoH (DNS over HTTPS), flush DNS cache
- **System Information Dashboard**: Comprehensive server overview with real-time metrics

### 🛡️ **Security & Hardening**
- **Firewall Management**: UFW (Ubuntu/Debian) and Firewalld (CentOS/RHEL) support
- **SSL/TLS Certificates**: Let's Encrypt integration, self-signed certificates
- **Fail2Ban Integration**: Automated intrusion prevention
- **Security Auditing**: System security assessment and hardening
- **User Management**: Advanced user and group management with SSH key configuration

### 🐳 **Containerization & Web Services**
- **Docker Management**: Complete Docker lifecycle management
- **Web Server Setup**: Nginx and Apache installation and configuration
- **Virtual Host Management**: Easy virtual host setup
- **PHP Installation**: PHP environment setup for web development

### 📊 **Monitoring & Performance**
- **Real-time Monitoring**: Advanced system metrics with live updates
- **Performance Optimization**: CPU, memory, disk, and network optimization
- **Log Management**: Centralized log viewing and analysis
- **Resource Monitoring**: Detailed resource usage tracking

### 💾 **Backup & Maintenance**
- **Automated Backups**: System, database, and web file backups
- **Scheduled Backups**: Cron-based automatic backup scheduling
- **Package Management**: System updates, cleanup, and maintenance
- **Health Checks**: Comprehensive system health monitoring

## 🚀 Quick Start

```bash
# Download and run the script
curl -sSL https://raw.githubusercontent.com/memarzade-dev/linux-server-manager/main/server_manager.sh -o server_manager.sh
chmod +x server_manager.sh
sudo ./server_manager.sh
```

## 📥 Installation

### Method 1: Direct Download
```bash
# Download the script
wget https://raw.githubusercontent.com/memarzade-dev/linux-server-manager/main/server_manager.sh

# Make it executable
chmod +x server_manager.sh

# Run with root privileges
sudo ./server_manager.sh
```

### Method 2: Git Clone
```bash
# Clone the repository
git clone https://github.com/memarzade-dev/linux-server-manager.git

# Navigate to directory
cd linux-server-manager

# Make executable
chmod +x server_manager.sh

# Run the script
sudo ./server_manager.sh
```

### Method 3: One-liner Installation
```bash
curl -sSL https://raw.githubusercontent.com/memarzade-dev/linux-server-manager/main/install.sh | sudo bash
```

## 🖥️ Usage

### Main Menu Navigation
The script provides an intuitive menu-driven interface:

```
╔════════════════════════════════════════════════════════════════╗
║            PROFESSIONAL LINUX SERVER MANAGER                  ║
║                        Version 3.0                            ║
║                    Memarzade Development                       ║
╠════════════════════════════════════════════════════════════════╣
║                          MAIN MENU                            ║
╠════════════════════════════════════════════════════════════════╣
║ 1.  📊 Server Information Dashboard                           ║
║ 2.  🔧 SSH Configuration                                      ║
║ 3.  🏷️  Hostname Configuration                               ║
║ 4.  🌐 DNS Management                                         ║
║ 5.  🛡️  Firewall Management                                  ║
║ 6.  📜 SSL/TLS Certificate Management                         ║
║ 7.  👥 User Management                                        ║
║ 8.  🐳 Docker Management                                      ║
║ 9.  🔒 Security Hardening                                     ║
║ 10. ⚡ Performance Optimization                               ║
║ 11. 🌐 Web Server Management                                  ║
║ 12. 💾 Backup Management                                      ║
║ 13. 📈 Advanced System Monitoring                             ║
║ 14. 🔧 System Maintenance                                     ║
║ 15. 📁 View Backups                                           ║
║ 16. 📜 View Logs                                              ║
║ 0.  🚪 Exit                                                   ║
╚════════════════════════════════════════════════════════════════╝
```

### Common Use Cases

#### 🔧 Change SSH Port
```bash
# Access SSH Configuration menu
# Select option 2 from main menu
# Follow the guided prompts to change SSH port
# Firewall rules are automatically updated
```

#### 🌐 Configure DNS Servers
```bash
# Access DNS Management menu
# Choose from popular DNS providers:
# - Google DNS (8.8.8.8, 8.8.4.4)
# - Cloudflare DNS (1.1.1.1, 1.0.0.1)
# - Quad9 DNS (9.9.9.9, 149.112.112.112)
# - Custom DNS servers
```

#### 🛡️ Enable Security Hardening
```bash
# Access Security Hardening menu
# Install and configure Fail2Ban
# Set strong password policies
# Configure automatic updates
# Disable unused services
```

## 💻 System Requirements

### Supported Operating Systems
- **Ubuntu**: 18.04, 20.04, 22.04, 24.04
- **Debian**: 10, 11, 12
- **CentOS**: 7, 8, 9
- **RHEL**: 7, 8, 9
- **Fedora**: 35+
- **Rocky Linux**: 8, 9
- **AlmaLinux**: 8, 9

### Prerequisites
- **Root/Sudo Access**: Required for system modifications
- **Bash Shell**: Version 4.0 or higher
- **Internet Connection**: Required for package installations and updates
- **Minimum RAM**: 512MB (1GB+ recommended)
- **Disk Space**: 100MB free space for logs and backups

### Required Packages (Auto-installed)
```bash
# Debian/Ubuntu
curl wget nano ufw fail2ban

# CentOS/RHEL/Fedora
curl wget nano firewalld fail2ban
```

## 🚀 Advanced Features

### 🔒 SSL/TLS Certificate Management
- **Let's Encrypt Integration**: Automatic SSL certificate generation
- **Auto-renewal**: Automated certificate renewal setup
- **Self-signed Certificates**: Generate certificates for internal use
- **Certificate Monitoring**: Expiry date tracking and notifications

### 🐳 Docker Management
- **Complete Docker Lifecycle**: Install, configure, and manage Docker
- **Container Management**: Start, stop, remove containers
- **Image Management**: Pull, list, and remove Docker images
- **System Cleanup**: Remove unused containers, images, and volumes

### 📊 Advanced Monitoring
- **Real-time Metrics**: CPU, memory, disk, and network monitoring
- **Process Monitoring**: Top processes by CPU and memory usage
- **Network Traffic**: Interface statistics and connection monitoring
- **Log Analysis**: Centralized log viewing and filtering

### 💾 Backup Solutions
- **System Backups**: Complete system configuration backup
- **Database Backups**: MySQL, PostgreSQL, and MongoDB support
- **Web Backups**: Website files and configurations
- **Scheduled Backups**: Automated backup scheduling with cron

## 🔐 Security Features

### Built-in Security Measures
- **Input Validation**: All user inputs are validated and sanitized
- **Configuration Backups**: Automatic backups before making changes
- **Audit Logging**: All actions are logged for security auditing
- **Privilege Checking**: Root access verification for sensitive operations

### Security Hardening Options
- **Fail2Ban Configuration**: Automated intrusion prevention
- **SSH Hardening**: Key-based authentication, port changes, protocol updates
- **Firewall Rules**: Intelligent firewall configuration
- **Password Policies**: Strong password requirements
- **Service Hardening**: Disable unnecessary services

### Best Practices Implemented
- **Principle of Least Privilege**: Minimal required permissions
- **Defense in Depth**: Multiple security layers
- **Secure Defaults**: Safe default configurations
- **Regular Updates**: Automated security updates

## 📸 Screenshots

### Main Dashboard
```
╔════════════════════════════════════════════════════════════════╗
║                    SERVER INFORMATION DASHBOARD               ║
╠════════════════════════════════════════════════════════════════╣
║ Basic Information:                                             ║
║ Hostname:         server.example.com                          ║
║ Primary IP:       203.0.113.1 (Public) / 192.168.1.100      ║
║ SSH Port:         2222                                         ║
║ Primary Interface: eth0                                        ║
╠════════════════════════════════════════════════════════════════╣
║ System Information:                                            ║
║ OS:               Ubuntu 22.04 LTS                            ║
║ Kernel:           5.15.0-76-generic                           ║
║ Architecture:     x86_64                                       ║
╠════════════════════════════════════════════════════════════════╣
║ Resource Usage:                                                ║
║ CPU Usage:        15.2%                                       ║
║ Memory Usage:     45.8%                                       ║
║ Disk Usage (/):   23%                                         ║
║ Uptime:           15 days, 3:45                               ║
╚════════════════════════════════════════════════════════════════╝
```

### Real-time Monitoring
```
═══════════════════════════════════════════════════════════════
              ENHANCED REAL-TIME SYSTEM MONITOR
═══════════════════════════════════════════════════════════════
Time: 2024-01-15 14:30:25 | Hostname: web-server-01

SYSTEM LOAD & UPTIME
Uptime: 15 days, 3:45 | Load Average: 0.15, 0.18, 0.12

CPU METRICS
Cores: 4 | Usage: 15.2%
Per-core usage: Core 0: 12.1% Core 1: 18.3% Core 2: 14.7% Core 3: 15.9%

MEMORY METRICS
RAM: 1.8G/4.0G (45.8%) | Swap: 0B/2.0G

DISK USAGE
/: 4.5G/20G (23%) on /dev/vda1
/var: 2.1G/10G (21%) on /dev/vda2

NETWORK ACTIVITY
Interface: eth0 | RX: 1245MB | TX: 892MB
Active connections: 127

TOP 5 PROCESSES (CPU)
nginx           2.1%   1.2%  /usr/sbin/nginx
mysql           1.8%   15.3% /usr/sbin/mysqld
php-fpm         1.2%   3.4%  php-fpm: master
ssh             0.8%   0.2%  sshd: user@pts/0
systemd         0.3%   0.1%  /sbin/init
═══════════════════════════════════════════════════════════════
```

## 🤝 Contributing

We welcome contributions! Please follow these guidelines:

### How to Contribute
1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/amazing-feature`
3. **Commit your changes**: `git commit -m 'Add amazing feature'`
4. **Push to the branch**: `git push origin feature/amazing-feature`
5. **Open a Pull Request**

### Development Guidelines
- Follow bash scripting best practices
- Add comments for complex functions
- Test on multiple Linux distributions
- Update documentation for new features
- Maintain backward compatibility

### Code Style
- Use 4 spaces for indentation
- Follow the existing naming conventions
- Add error handling for all functions
- Include logging for important operations

### Testing
Before submitting a PR, test your changes on:
- Ubuntu 22.04 LTS
- Debian 11/12
- CentOS Stream 9
- Rocky Linux 9

## 🔧 Troubleshooting

### Common Issues

#### Permission Denied
```bash
# Ensure you're running with root privileges
sudo ./server_manager.sh

# Check file permissions
ls -la server_manager.sh
chmod +x server_manager.sh
```

#### Package Installation Fails
```bash
# Update package lists first
sudo apt update  # Debian/Ubuntu
sudo dnf update  # Fedora/RHEL 8+
sudo yum update  # CentOS/RHEL 7
```

#### SSH Connection Issues After Port Change
```bash
# Check if SSH is running on new port
sudo ss -tuln | grep :2222

# Check firewall rules
sudo ufw status  # Ubuntu/Debian
sudo firewall-cmd --list-all  # CentOS/RHEL
```

#### Docker Installation Issues
```bash
# Remove old Docker versions
sudo apt remove docker docker-engine docker.io containerd runc

# Clean installation
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
```

### Log Files
- **Script logs**: `/var/log/server_manager.log`
- **Backup location**: `/etc/server_manager_backups/`
- **System logs**: `/var/log/syslog` or `journalctl -f`

### Getting Help
1. Check the [Issues](https://github.com/memarzade-dev/linux-server-manager/issues) page
2. Read the troubleshooting section
3. Create a new issue with:
   - Your Linux distribution and version
   - Error messages (if any)
   - Steps to reproduce the problem

## 📝 Changelog

### Version 3.0 (Latest)
- ✨ Added DNS management with DoH support
- ✨ Comprehensive SSL/TLS certificate management
- ✨ Advanced user management with SSH key configuration
- ✨ Docker lifecycle management
- ✨ Enhanced security hardening with Fail2Ban
- ✨ Performance optimization tools
- ✨ Web server management (Nginx/Apache)
- ✨ Automated backup solutions
- ✨ Real-time system monitoring
- 🔧 Improved error handling and validation
- 🔧 Enhanced logging and audit trails
- 🔧 Better OS compatibility

### Version 2.0
- ✨ Added firewall management
- ✨ System monitoring capabilities
- ✨ Backup management
- 🔧 Improved SSH configuration
- 🔧 Enhanced hostname management

### Version 1.0
- ✨ Basic SSH port management
- ✨ Hostname configuration
- ✨ Simple server information display

## 📋 Roadmap

### Upcoming Features
- 🔮 **Database Management**: MySQL, PostgreSQL, MongoDB administration
- 🔮 **Email Server Setup**: Postfix, Dovecot configuration
- 🔮 **VPN Server Management**: OpenVPN, WireGuard setup
- 🔮 **Load Balancer Configuration**: HAProxy, Nginx load balancing
- 🔮 **Kubernetes Management**: K3s, microk8s administration
- 🔮 **Cloud Integration**: AWS, Google Cloud, Azure tools
- 🔮 **Automated Deployment**: CI/CD pipeline setup
- 🔮 **Compliance Scanning**: CIS benchmarks, security standards

### Version 4.0 (Planned)
- Web-based GUI interface
- API endpoints for automation
- Multi-server management
- Cloud provider integration
- Advanced analytics and reporting

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

```
MIT License

Copyright (c) 2024 Memarzade Development

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## 💬 Support

### Community Support
- **GitHub Issues**: [Report bugs or request features](https://github.com/memarzade-dev/linux-server-manager/issues)
- **GitHub Discussions**: [Community discussions](https://github.com/memarzade-dev/linux-server-manager/discussions)
- **Documentation**: [Wiki pages](https://github.com/memarzade-dev/linux-server-manager/wiki)

### Professional Support
For enterprise support, consulting, or custom development:
- 📧 **Email**: support@memarzade.dev
- 🌐 **Website**: [www.memarzade.dev](https://www.memarzade.dev)
- 💼 **LinkedIn**: [Memarzade Development](https://linkedin.com/company/memarzade-dev)

### Donate
If this project has been helpful, consider supporting its development:
- ☕ **Buy me a coffee**: [ko-fi.com/memarzade](https://ko-fi.com/memarzade)
- 💖 **GitHub Sponsors**: [Sponsor this project](https://github.com/sponsors/memarzade-dev)

---

<div align="center">

**Made with ❤️ by [Memarzade Development](https://github.com/memarzade-dev)**

*Professional Linux Server Management Made Simple*

[⭐ Star this repository](https://github.com/memarzade-dev/linux-server-manager) | [🐛 Report Bug](https://github.com/memarzade-dev/linux-server-manager/issues) | [💡 Request Feature](https://github.com/memarzade-dev/linux-server-manager/issues)

</div>