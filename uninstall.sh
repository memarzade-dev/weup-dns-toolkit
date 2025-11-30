#!/usr/bin/env bash
################################################################################
#
#  WeUp DNS Toolkit - Uninstallation Script
#  
#  Removes the DNS Toolkit and all associated files
#  Optionally preserves configuration and backups
#
#  Usage: sudo ./uninstall.sh [OPTIONS]
#
#  Copyright (c) 2024-2025 WeUp.one Group
#  License: MIT
#
################################################################################

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

readonly PROJECT_NAME="weup-dns-toolkit"
readonly VERSION="2.0.0"

# Installation paths
readonly INSTALL_DIR="/opt/${PROJECT_NAME}"
readonly BIN_DIR="/usr/local/bin"
readonly CONFIG_DIR="/etc/${PROJECT_NAME}"
readonly DATA_DIR="/var/lib/${PROJECT_NAME}"
readonly BACKUP_DIR="/var/backups/${PROJECT_NAME}"
readonly LOG_FILE="/var/log/${PROJECT_NAME}.log"
readonly SYSTEMD_DIR="/etc/systemd/system"
readonly COMPLETION_DIR="/etc/bash_completion.d"

# Terminal colors
if [[ -t 1 ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly CYAN='\033[0;36m'
    readonly NC='\033[0m'
else
    readonly RED='' GREEN='' YELLOW='' CYAN='' NC=''
fi

# Options
PURGE_ALL=0
FORCE=0
QUIET=0

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

log_info() {
    [[ ${QUIET} -eq 1 ]] && return
    printf "%b[INFO]%b %s\n" "${GREEN}" "${NC}" "$*"
}

log_warn() {
    printf "%b[WARN]%b %s\n" "${YELLOW}" "${NC}" "$*" >&2
}

log_error() {
    printf "%b[ERROR]%b %s\n" "${RED}" "${NC}" "$*" >&2
}

die() {
    log_error "$1"
    exit "${2:-1}"
}

# ============================================================================
# CHECKS
# ============================================================================

check_root() {
    if [[ $EUID -ne 0 ]]; then
        die "This script must be run as root. Use: sudo $0" 1
    fi
}

check_installed() {
    if [[ ! -d "${INSTALL_DIR}" ]] && [[ ! -L "${BIN_DIR}/weup-dns" ]]; then
        log_warn "${PROJECT_NAME} does not appear to be installed."
        exit 0
    fi
}

# ============================================================================
# UNINSTALLATION STEPS
# ============================================================================

stop_services() {
    log_info "Stopping services..."
    
    if systemctl is-active --quiet "${PROJECT_NAME}.timer" 2>/dev/null; then
        systemctl stop "${PROJECT_NAME}.timer" 2>/dev/null || true
    fi
    
    if systemctl is-active --quiet "${PROJECT_NAME}.service" 2>/dev/null; then
        systemctl stop "${PROJECT_NAME}.service" 2>/dev/null || true
    fi
    
    systemctl disable "${PROJECT_NAME}.timer" 2>/dev/null || true
    systemctl disable "${PROJECT_NAME}.service" 2>/dev/null || true
}

remove_systemd_files() {
    log_info "Removing systemd files..."
    
    rm -f "${SYSTEMD_DIR}/${PROJECT_NAME}.service"
    rm -f "${SYSTEMD_DIR}/${PROJECT_NAME}.timer"
    
    systemctl daemon-reload 2>/dev/null || true
}

remove_symlinks() {
    log_info "Removing symlinks..."
    
    rm -f "${BIN_DIR}/weup-dns"
    rm -f "${BIN_DIR}/dns-toolkit"
}

remove_completion() {
    log_info "Removing bash completion..."
    
    rm -f "${COMPLETION_DIR}/${PROJECT_NAME}"
}

remove_installation() {
    log_info "Removing installation directory..."
    
    rm -rf "${INSTALL_DIR}"
}

remove_data() {
    log_info "Removing data directory..."
    
    rm -rf "${DATA_DIR}"
}

remove_logs() {
    log_info "Removing log files..."
    
    rm -f "${LOG_FILE}"
    rm -f "${LOG_FILE}.lock"
}

remove_config() {
    if [[ ${PURGE_ALL} -eq 1 ]]; then
        log_info "Removing configuration directory..."
        rm -rf "${CONFIG_DIR}"
    else
        log_info "Preserving configuration: ${CONFIG_DIR}"
    fi
}

remove_backups() {
    if [[ ${PURGE_ALL} -eq 1 ]]; then
        log_info "Removing backup directory..."
        rm -rf "${BACKUP_DIR}"
    else
        log_info "Preserving backups: ${BACKUP_DIR}"
    fi
}

# ============================================================================
# MAIN
# ============================================================================

print_header() {
    [[ ${QUIET} -eq 1 ]] && return
    
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║         WeUp DNS Toolkit - Uninstaller v${VERSION}           ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
}

print_what_will_be_removed() {
    echo "The following will be ${RED}REMOVED${NC}:"
    echo ""
    [[ -d "${INSTALL_DIR}" ]] && echo "  • ${INSTALL_DIR}"
    [[ -L "${BIN_DIR}/weup-dns" ]] && echo "  • ${BIN_DIR}/weup-dns"
    [[ -L "${BIN_DIR}/dns-toolkit" ]] && echo "  • ${BIN_DIR}/dns-toolkit"
    [[ -f "${SYSTEMD_DIR}/${PROJECT_NAME}.service" ]] && echo "  • ${SYSTEMD_DIR}/${PROJECT_NAME}.service"
    [[ -f "${SYSTEMD_DIR}/${PROJECT_NAME}.timer" ]] && echo "  • ${SYSTEMD_DIR}/${PROJECT_NAME}.timer"
    [[ -f "${COMPLETION_DIR}/${PROJECT_NAME}" ]] && echo "  • ${COMPLETION_DIR}/${PROJECT_NAME}"
    [[ -d "${DATA_DIR}" ]] && echo "  • ${DATA_DIR}"
    [[ -f "${LOG_FILE}" ]] && echo "  • ${LOG_FILE}"
    
    if [[ ${PURGE_ALL} -eq 1 ]]; then
        [[ -d "${CONFIG_DIR}" ]] && echo "  • ${CONFIG_DIR}"
        [[ -d "${BACKUP_DIR}" ]] && echo "  • ${BACKUP_DIR}"
    fi
    
    echo ""
    
    if [[ ${PURGE_ALL} -eq 0 ]]; then
        echo "The following will be ${GREEN}PRESERVED${NC}:"
        echo ""
        [[ -d "${CONFIG_DIR}" ]] && echo "  • ${CONFIG_DIR} (configuration)"
        [[ -d "${BACKUP_DIR}" ]] && echo "  • ${BACKUP_DIR} (DNS backups)"
        echo ""
    fi
}

confirm_uninstall() {
    if [[ ${FORCE} -eq 1 ]]; then
        return 0
    fi
    
    read -rp "Continue with uninstallation? [y/N]: " confirm
    if [[ ! "${confirm}" =~ ^[Yy]$ ]]; then
        echo ""
        echo "Uninstallation cancelled."
        exit 0
    fi
}

print_success() {
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    printf "%b  Uninstallation complete!%b\n" "${GREEN}" "${NC}"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    
    if [[ ${PURGE_ALL} -eq 0 ]]; then
        echo "Preserved directories:"
        [[ -d "${CONFIG_DIR}" ]] && echo "  • ${CONFIG_DIR}"
        [[ -d "${BACKUP_DIR}" ]] && echo "  • ${BACKUP_DIR}"
        echo ""
        echo "To completely remove all data:"
        echo "  sudo rm -rf ${CONFIG_DIR} ${BACKUP_DIR}"
    fi
    
    echo ""
}

print_help() {
    cat << EOF
WeUp DNS Toolkit Uninstaller v${VERSION}

Usage: sudo $0 [OPTIONS]

Options:
  --purge         Remove all data including config and backups
  -f, --force     Don't ask for confirmation
  -q, --quiet     Suppress non-error output
  -h, --help      Show this help message
  -v, --version   Show version

Examples:
  sudo $0                 # Standard uninstall (preserves config)
  sudo $0 --purge         # Remove everything
  sudo $0 --force         # No confirmation prompt
EOF
}

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --purge)
                PURGE_ALL=1
                shift
                ;;
            -f|--force)
                FORCE=1
                shift
                ;;
            -q|--quiet)
                QUIET=1
                shift
                ;;
            -h|--help)
                print_help
                exit 0
                ;;
            -v|--version)
                echo "WeUp DNS Toolkit Uninstaller v${VERSION}"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                print_help
                exit 1
                ;;
        esac
    done
    
    check_root
    check_installed
    
    print_header
    print_what_will_be_removed
    confirm_uninstall
    
    echo ""
    
    stop_services
    remove_systemd_files
    remove_symlinks
    remove_completion
    remove_installation
    remove_data
    remove_logs
    remove_config
    remove_backups
    
    print_success
}

main "$@"
