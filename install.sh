#!/usr/bin/env bash
################################################################################
#
#  WeUp DNS Toolkit - Installation Script
#  
#  Installs dns_toolkit.sh and all required dependencies on Ubuntu Linux
#  Supports Ubuntu 18.04, 20.04, 22.04, 24.04 LTS
#
#  Usage: sudo ./install.sh [OPTIONS]
#
#  Copyright (c) 2024-2025 WeUp.one Group
#  License: MIT
#
################################################################################

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

readonly TOOLKIT_VERSION="2.0.0"
readonly PROJECT_NAME="weup-dns-toolkit"
readonly SCRIPT_NAME="dns_toolkit.sh"
readonly DATASET_NAME="dns_dataset.json"

# Installation paths
readonly INSTALL_DIR="/opt/${PROJECT_NAME}"
readonly BIN_DIR="/usr/local/bin"
readonly CONFIG_DIR="/etc/${PROJECT_NAME}"
readonly DATA_DIR="/var/lib/${PROJECT_NAME}"
readonly LOG_DIR="/var/log"
readonly BACKUP_DIR="/var/backups/${PROJECT_NAME}"
readonly MAN_DIR="/usr/local/share/man/man1"
readonly SYSTEMD_DIR="/etc/systemd/system"

# Source directory (where install.sh is located)
readonly SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

readonly RED='' GREEN='' YELLOW='' BLUE='' CYAN='' BOLD='' NC=''

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

log_info() {
    printf "[INFO] %s\n" "$*"
}

log_warn() {
    printf "[WARN] %s\n" "$*" >&2
}

log_error() {
    printf "[ERROR] %s\n" "$*" >&2
}

log_step() {
    printf "\n--- %s\n" "$*"
}

die() {
    log_error "$1"
    exit "${2:-1}"
}

command_exists() {
    command -v "$1" &>/dev/null
}

# ============================================================================
# SYSTEM CHECKS
# ============================================================================

check_root() {
    if [[ $EUID -ne 0 ]]; then
        die "This script must be run as root. Use: sudo $0" 1
    fi
}

check_os() {
    log_step "Checking operating system..."
    
    if [[ ! -f /etc/os-release ]]; then
        die "Cannot detect operating system. /etc/os-release not found." 1
    fi
    
    # shellcheck source=/dev/null
    source /etc/os-release
    
    local os_name="${ID:-unknown}"
    local os_version="${VERSION_ID:-unknown}"
    
    log_info "Detected: ${PRETTY_NAME:-${os_name} ${os_version}}"
    
    if [[ "${os_name}" != "ubuntu" ]]; then
        log_warn "This system is not Ubuntu. Installation may not work correctly."
        log_warn "Supported: Ubuntu 18.04, 20.04, 22.04, 24.04 LTS"
        
        read -rp "Continue anyway? [y/N]: " confirm
        if [[ ! "${confirm}" =~ ^[Yy]$ ]]; then
            die "Installation cancelled by user." 0
        fi
    fi
    
    # Check Ubuntu version
    case "${os_version}" in
        18.04*|20.04*|22.04*|24.04*)
            log_info "Ubuntu version ${os_version} is supported."
            ;;
        *)
            log_warn "Ubuntu ${os_version} is not officially tested."
            ;;
    esac
}

check_architecture() {
    local arch
    arch="$(uname -m)"
    
    case "${arch}" in
        x86_64|amd64)
            log_info "Architecture: x86_64 (supported)"
            ;;
        aarch64|arm64)
            log_info "Architecture: ARM64 (supported)"
            ;;
        *)
            log_warn "Architecture ${arch} is not tested."
            ;;
    esac
}

check_source_files() {
    log_step "Checking source files..."
    
    local -a required_files=(
        "${SOURCE_DIR}/${SCRIPT_NAME}"
        "${SOURCE_DIR}/${DATASET_NAME}"
    )
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "${file}" ]]; then
            die "Required file not found: ${file}" 1
        fi
        log_info "Found: $(basename "${file}")"
    done
}

# ============================================================================
# DEPENDENCY MANAGEMENT
# ============================================================================

install_dependencies() {
    log_step "Installing dependencies..."
    
    # Update package lists
    log_info "Updating package lists..."
    apt-get update -qq || die "Failed to update package lists" 1
    
    # Required packages
    local -a packages=(
        "jq"
        "curl"
        "dnsutils"
        "coreutils"
        "gawk"
        "sed"
        "grep"
        "util-linux"
    )
    
    # Optional packages (don't fail if unavailable)
    local -a optional_packages=(
        "net-tools"
        "network-manager"
    )
    
    log_info "Installing required packages: ${packages[*]}"
    
    if ! apt-get install -y "${packages[@]}" 2>&1 | while read -r line; do
        [[ -n "${line}" ]] && printf "  %s\n" "${line}"
    done; then
        die "Failed to install required packages" 1
    fi
    
    log_info "Installing optional packages..."
    for pkg in "${optional_packages[@]}"; do
        apt-get install -y "${pkg}" 2>/dev/null || log_warn "Optional package not available: ${pkg}"
    done
    
    log_info "Dependencies installed successfully."
}

verify_dependencies() {
    log_step "Verifying dependencies..."
    
    local -a required_commands=(
        "jq"
        "curl"
        "dig"
        "timeout"
        "awk"
        "sed"
        "grep"
        "flock"
        "mktemp"
    )
    
    local missing=0
    
    for cmd in "${required_commands[@]}"; do
        if command_exists "${cmd}"; then
            log_info "OK ${cmd}"
        else
            log_error "MISSING ${cmd} - NOT FOUND"
            missing=1
        fi
    done
    
    if [[ ${missing} -eq 1 ]]; then
        die "Some required commands are missing. Please install them manually." 1
    fi
}

# ============================================================================
# INSTALLATION
# ============================================================================

create_directories() {
    log_step "Creating directories..."
    
    local -a directories=(
        "${INSTALL_DIR}"
        "${CONFIG_DIR}"
        "${DATA_DIR}"
        "${BACKUP_DIR}"
        "${LOG_DIR}"
    )
    
    for dir in "${directories[@]}"; do
        if [[ ! -d "${dir}" ]]; then
            mkdir -p "${dir}"
            log_info "Created: ${dir}"
        else
            log_info "Exists: ${dir}"
        fi
    done
    
    # Set permissions
    chmod 755 "${INSTALL_DIR}"
    chmod 755 "${CONFIG_DIR}"
    chmod 750 "${DATA_DIR}"
    chmod 750 "${BACKUP_DIR}"
}

install_files() {
    log_step "Installing files..."
    
    # Install main script
    log_info "Installing ${SCRIPT_NAME}..."
    cp "${SOURCE_DIR}/${SCRIPT_NAME}" "${INSTALL_DIR}/${SCRIPT_NAME}"
    chmod 755 "${INSTALL_DIR}/${SCRIPT_NAME}"
    
    # Install DNS dataset
    log_info "Installing ${DATASET_NAME}..."
    cp "${SOURCE_DIR}/${DATASET_NAME}" "${INSTALL_DIR}/${DATASET_NAME}"
    chmod 644 "${INSTALL_DIR}/${DATASET_NAME}"
    
    # Install configuration file if exists
    if [[ -f "${SOURCE_DIR}/config.conf" ]]; then
        if [[ ! -f "${CONFIG_DIR}/config.conf" ]]; then
            log_info "Installing config.conf..."
            cp "${SOURCE_DIR}/config.conf" "${CONFIG_DIR}/config.conf"
            chmod 644 "${CONFIG_DIR}/config.conf"
        else
            log_info "Config file exists, preserving: ${CONFIG_DIR}/config.conf"
            cp "${SOURCE_DIR}/config.conf" "${CONFIG_DIR}/config.conf.new"
        fi
    fi
    
    # Create symlink in /usr/local/bin
    log_info "Creating symlink: ${BIN_DIR}/weup-dns"
    ln -sf "${INSTALL_DIR}/${SCRIPT_NAME}" "${BIN_DIR}/weup-dns"
    
    # Also create alias without prefix
    ln -sf "${INSTALL_DIR}/${SCRIPT_NAME}" "${BIN_DIR}/dns-toolkit"
}

install_systemd_service() {
    log_step "Installing systemd service..."
    
    # Create systemd service for automatic DNS optimization
    cat > "${SYSTEMD_DIR}/${PROJECT_NAME}.service" << 'EOF'
[Unit]
Description=WeUp DNS Toolkit - Automatic DNS Optimization
Documentation=https://github.com/memarzade-dev/weup-dns-toolkit
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/opt/weup-dns-toolkit/dns_toolkit.sh --auto --quiet
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    chmod 644 "${SYSTEMD_DIR}/${PROJECT_NAME}.service"
    log_info "Created: ${SYSTEMD_DIR}/${PROJECT_NAME}.service"
    
    # Create timer for periodic optimization
    cat > "${SYSTEMD_DIR}/${PROJECT_NAME}.timer" << 'EOF'
[Unit]
Description=WeUp DNS Toolkit - Periodic DNS Check
Documentation=https://github.com/memarzade-dev/weup-dns-toolkit

[Timer]
OnBootSec=2min
OnUnitActiveSec=6h
RandomizedDelaySec=5min
Persistent=true

[Install]
WantedBy=timers.target
EOF
    
    chmod 644 "${SYSTEMD_DIR}/${PROJECT_NAME}.timer"
    log_info "Created: ${SYSTEMD_DIR}/${PROJECT_NAME}.timer"
    
    # Reload systemd
    systemctl daemon-reload
    
    log_info "Systemd services installed."
    log_info "To enable automatic DNS optimization:"
    log_info "  sudo systemctl enable --now ${PROJECT_NAME}.timer"
}

install_bash_completion() {
    log_step "Installing bash completion..."
    
    local completion_dir="/etc/bash_completion.d"
    
    if [[ -d "${completion_dir}" ]]; then
        cat > "${completion_dir}/${PROJECT_NAME}" << 'EOF'
# Bash completion for weup-dns-toolkit

_weup_dns_completion() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    
    opts="--auto --iranian --international --security --family --unfiltered \
          --test --benchmark --restore --update --info \
          --verbose --quiet --dry-run --force --version --help \
          -a -i -t -s -b -r -v -q -n -f -h"
    
    if [[ ${cur} == -* ]]; then
        COMPREPLY=( $(compgen -W "${opts}" -- "${cur}") )
        return 0
    fi
}

complete -F _weup_dns_completion weup-dns
complete -F _weup_dns_completion dns-toolkit
EOF
        
        chmod 644 "${completion_dir}/${PROJECT_NAME}"
        log_info "Bash completion installed."
    else
        log_warn "Bash completion directory not found. Skipping."
    fi
}

create_uninstall_script() {
    log_step "Creating uninstall script..."
    
    cat > "${INSTALL_DIR}/uninstall.sh" << 'UNINSTALL_EOF'
#!/usr/bin/env bash
################################################################################
#  WeUp DNS Toolkit - Uninstallation Script
################################################################################

set -euo pipefail

readonly PROJECT_NAME="weup-dns-toolkit"
readonly INSTALL_DIR="/opt/${PROJECT_NAME}"
readonly BIN_DIR="/usr/local/bin"
readonly CONFIG_DIR="/etc/${PROJECT_NAME}"
readonly DATA_DIR="/var/lib/${PROJECT_NAME}"
readonly BACKUP_DIR="/var/backups/${PROJECT_NAME}"
readonly SYSTEMD_DIR="/etc/systemd/system"

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root. Use: sudo $0"
    exit 1
fi

echo "WeUp DNS Toolkit Uninstaller"
echo "============================"
echo ""
echo "This will remove:"
echo "  - ${INSTALL_DIR}"
echo "  - ${BIN_DIR}/weup-dns"
echo "  - ${BIN_DIR}/dns-toolkit"
echo "  - Systemd services"
echo ""
echo "Will preserve:"
echo "  - ${CONFIG_DIR} (configuration)"
echo "  - ${BACKUP_DIR} (DNS backups)"
echo ""

read -rp "Continue? [y/N]: " confirm
if [[ ! "${confirm}" =~ ^[Yy]$ ]]; then
    echo "Uninstallation cancelled."
    exit 0
fi

echo ""
echo "Stopping services..."
systemctl stop "${PROJECT_NAME}.timer" 2>/dev/null || true
systemctl stop "${PROJECT_NAME}.service" 2>/dev/null || true
systemctl disable "${PROJECT_NAME}.timer" 2>/dev/null || true
systemctl disable "${PROJECT_NAME}.service" 2>/dev/null || true

echo "Removing systemd files..."
rm -f "${SYSTEMD_DIR}/${PROJECT_NAME}.service"
rm -f "${SYSTEMD_DIR}/${PROJECT_NAME}.timer"
systemctl daemon-reload

echo "Removing symlinks..."
rm -f "${BIN_DIR}/weup-dns"
rm -f "${BIN_DIR}/dns-toolkit"

echo "Removing bash completion..."
rm -f "/etc/bash_completion.d/${PROJECT_NAME}"

echo "Removing installation directory..."
rm -rf "${INSTALL_DIR}"

echo "Removing data directory..."
rm -rf "${DATA_DIR}"

echo ""
echo "Uninstallation complete."
echo ""
echo "Preserved directories:"
echo "  - ${CONFIG_DIR}"
echo "  - ${BACKUP_DIR}"
echo ""
echo "To remove everything: sudo rm -rf ${CONFIG_DIR} ${BACKUP_DIR}"
UNINSTALL_EOF
    
    chmod 755 "${INSTALL_DIR}/uninstall.sh"
    log_info "Uninstall script created: ${INSTALL_DIR}/uninstall.sh"
}

# ============================================================================
# POST-INSTALLATION
# ============================================================================

verify_installation() {
    log_step "Verifying installation..."
    
    local errors=0
    
    # Check main script
    if [[ -x "${INSTALL_DIR}/${SCRIPT_NAME}" ]]; then
        log_info "OK Main script installed"
    else
        log_error "✗ Main script not found or not executable"
        ((errors++))
    fi
    
    # Check dataset
    if [[ -f "${INSTALL_DIR}/${DATASET_NAME}" ]]; then
        if jq empty "${INSTALL_DIR}/${DATASET_NAME}" 2>/dev/null; then
            log_info "OK DNS dataset valid"
        else
            log_error "✗ DNS dataset is invalid JSON"
            ((errors++))
        fi
    else
        log_error "✗ DNS dataset not found"
        ((errors++))
    fi
    
    # Check symlinks
    if [[ -L "${BIN_DIR}/weup-dns" ]]; then
        log_info "OK Symlink weup-dns created"
    else
        log_error "✗ Symlink weup-dns not found"
        ((errors++))
    fi
    
    # Check systemd
    if [[ -f "${SYSTEMD_DIR}/${PROJECT_NAME}.service" ]]; then
        log_info "OK Systemd service installed"
    else
        log_warn "⚠ Systemd service not found"
    fi
    
    # Test execution
    if "${BIN_DIR}/weup-dns" --version &>/dev/null; then
        log_info "OK Script executes successfully"
    else
        log_error "✗ Script execution failed"
        ((errors++))
    fi
    
    return ${errors}
}

print_success() {
    cat << EOF

===============================================================
WeUp DNS Toolkit v${TOOLKIT_VERSION} Installed Successfully!
===============================================================

Usage:
  weup-dns                    Interactive menu
  weup-dns --auto             Auto-optimize DNS
  weup-dns --iranian          Use Iranian anti-sanction DNS
  weup-dns --test             Test current DNS
  weup-dns --help             Show all options

Automatic optimization:
  sudo systemctl enable --now ${PROJECT_NAME}.timer

Uninstall:
  sudo ${INSTALL_DIR}/uninstall.sh

Documentation:
  https://github.com/memarzade-dev/weup-dns-toolkit

EOF
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    echo ""
    echo "============================================================="
    echo "WeUp DNS Toolkit v${TOOLKIT_VERSION} - Installation"
    echo "============================================================="
    echo ""
    
    check_root
    check_os
    check_architecture
    check_source_files
    
    install_dependencies
    verify_dependencies
    
    create_directories
    install_files
    install_systemd_service
    install_bash_completion
    create_uninstall_script
    
    if verify_installation; then
        print_success
    else
        log_error "Installation completed with errors. Please check the output above."
        exit 1
    fi
}

# Handle arguments
case "${1:-}" in
    -h|--help)
        echo "WeUp DNS Toolkit Installer v${TOOLKIT_VERSION}"
        echo ""
        echo "Usage: sudo $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  -h, --help      Show this help message"
        echo "  -v, --version   Show version"
        echo ""
        echo "This script installs the WeUp DNS Toolkit on Ubuntu Linux."
        echo "Requires root privileges."
        exit 0
        ;;
    -v|--version)
        echo "WeUp DNS Toolkit Installer v${TOOLKIT_VERSION}"
        exit 0
        ;;
esac

main "$@"
