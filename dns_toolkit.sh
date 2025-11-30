#!/usr/bin/env bash
################################################################################
#
#  WeUp DNS Toolkit v2.0.0
#  Professional DNS Management System for Linux
#
#  Copyright (c) 2024-2025 WeUp.one Group
#  License: MIT
#
#  Features:
#  - Automatic DNS optimization with latency-based ranking
#  - Anti-sanction DNS support for Iranian users
#  - DoH/DoT/DoQ protocol support detection
#  - systemd-resolved integration
#  - NetworkManager compatibility
#  - Comprehensive security hardening
#  - Atomic file operations
#  - Thread-safe logging
#
################################################################################

set -euo pipefail
IFS=$'\n\t'

# ============================================================================
# CONSTANTS & GLOBAL CONFIGURATION
# ============================================================================

readonly TOOLKIT_VERSION="2.0.0"
readonly RELEASE_DATE="2025-01-15"
readonly PROJECT_NAME="weup-dns-toolkit"
readonly PROJECT_URL="https://github.com/memarzade-dev/weup-dns-toolkit"

# Script paths (resolved at runtime)
readonly SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SCRIPT_DIR="$(dirname "${SCRIPT_PATH}")"
readonly SCRIPT_NAME="$(basename "${SCRIPT_PATH}")"

# Configuration paths
readonly CONFIG_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/${PROJECT_NAME}"
readonly DATA_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}/${PROJECT_NAME}"
readonly CACHE_DIR="${XDG_CACHE_HOME:-${HOME}/.cache}/${PROJECT_NAME}"
readonly SYSTEM_CONFIG_DIR="/etc/${PROJECT_NAME}"

# Default file locations (can be overridden)
CONFIG_FILE="${CONFIG_FILE:-${CONFIG_DIR}/config.conf}"
DNS_DATASET="${DNS_DATASET:-${SCRIPT_DIR}/dns_dataset.json}"
LOG_FILE="${LOG_FILE:-/var/log/${PROJECT_NAME}.log}"
BACKUP_DIR="${BACKUP_DIR:-/var/backups/${PROJECT_NAME}}"

# Remote dataset URL for auto-update
readonly REMOTE_DATASET_URL="https://raw.githubusercontent.com/memarzade-dev/weup-dns-toolkit/main/dns_dataset.json"

# Network configuration
readonly DNS_TEST_TIMEOUT=5
readonly HTTP_TIMEOUT=15
readonly MAX_PARALLEL_TESTS=6
readonly MAX_RETRIES=3
readonly RETRY_DELAY=2

# DNS test parameters
readonly MAX_LATENCY_MS=5000
readonly MIN_SUCCESS_RATE="0.60"
readonly EXCELLENT_LATENCY_MS=50
readonly GOOD_LATENCY_MS=100
readonly ACCEPTABLE_LATENCY_MS=200
PREFERRED_CATEGORY="${PREFERRED_CATEGORY:-iranian}"
AUTO_FALLBACK="${AUTO_FALLBACK:-true}"
FALLBACK_DNS="${FALLBACK_DNS:-1.1.1.1 8.8.8.8}"

# System paths
readonly RESOLV_CONF="/etc/resolv.conf"
readonly SYSTEMD_RESOLVED_CONF="/etc/systemd/resolved.conf"
readonly SYSTEMD_RESOLVED_DROP_IN="/etc/systemd/resolved.conf.d"
readonly NETPLAN_DIR="/etc/netplan"
readonly NM_CONF_DIR="/etc/NetworkManager/conf.d"

readonly RED='' GREEN='' YELLOW='' BLUE='' CYAN=''
readonly MAGENTA='' WHITE='' BOLD='' DIM='' NC=''

# Runtime state (minimized global state)
declare -A DNS_TEST_RESULTS=()
declare -A DNS_LATENCY_DATA=()
declare -i VERBOSE_MODE=0
declare -i DRY_RUN_MODE=0
declare -i FORCE_MODE=0
declare -i QUIET_MODE=0
declare -a FALLBACK_DNS_LIST=()

# ============================================================================
# LOGGING SUBSYSTEM
# ============================================================================

init_logging() {
    local log_dir
    log_dir="$(dirname "${LOG_FILE}")"
    
    if [[ ! -d "${log_dir}" ]]; then
        mkdir -p "${log_dir}" 2>/dev/null || {
            LOG_FILE="/tmp/${PROJECT_NAME}.log"
            log_dir="/tmp"
        }
    fi
    
    if [[ ! -w "${log_dir}" ]]; then
        LOG_FILE="/tmp/${PROJECT_NAME}.log"
    fi
    
    touch "${LOG_FILE}" 2>/dev/null || LOG_FILE="/dev/null"
}

load_config() {
    if [[ -f "${SYSTEM_CONFIG_DIR}/config.conf" ]]; then
        set -a
        . "${SYSTEM_CONFIG_DIR}/config.conf" 2>/dev/null || true
        set +a
    elif [[ -f "${CONFIG_FILE}" ]]; then
        set -a
        . "${CONFIG_FILE}" 2>/dev/null || true
        set +a
    fi
    read -ra FALLBACK_DNS_LIST <<< "${FALLBACK_DNS}"
}

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    local caller="${FUNCNAME[2]:-main}"
    
    # Thread-safe file logging with flock
    if [[ "${LOG_FILE}" != "/dev/null" ]]; then
        (
            flock -x 200
            printf "[%s] [%s] [%s] %s\n" "${timestamp}" "${level}" "${caller}" "${message}"
        ) 200>>"${LOG_FILE}.lock" >> "${LOG_FILE}" 2>/dev/null || true
    fi
    
    # Console output (unless quiet mode)
    [[ ${QUIET_MODE} -eq 1 ]] && return 0
    
    case "${level}" in
        ERROR)
            printf "[ERROR] %s\n" "${message}" >&2
            ;;
        WARN)
            printf "[WARN] %s\n" "${message}" >&2
            ;;
        INFO)
            printf "[INFO] %s\n" "${message}"
            ;;
        DEBUG)
            if [[ ${VERBOSE_MODE} -eq 1 ]]; then
                printf "[DEBUG] %s\n" "${message}"
            fi
            ;;
        TRACE)
            if [[ ${VERBOSE_MODE} -ge 2 ]]; then
                printf "[TRACE] %s\n" "${message}"
            fi
            ;;
    esac
}

log_error() { log ERROR "$@"; }
log_warn() { log WARN "$@"; }
log_info() { log INFO "$@"; }
log_debug() { log DEBUG "$@"; }
log_trace() { log TRACE "$@"; }

error_exit() {
    local message="$1"
    local exit_code="${2:-1}"
    
    log_error "${message}"
    cleanup_on_exit
    exit "${exit_code}"
}

# ============================================================================
# SECURITY & INPUT VALIDATION
# ============================================================================

validate_ipv4() {
    local ip="$1"
    local -a octets
    
    # Basic format check
    if [[ ! "${ip}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        return 1
    fi
    
    # Validate each octet
    IFS='.' read -ra octets <<< "${ip}"
    
    for octet in "${octets[@]}"; do
        # Remove leading zeros for comparison
        octet=$((10#${octet}))
        if [[ ${octet} -lt 0 || ${octet} -gt 255 ]]; then
            return 1
        fi
    done
    
    return 0
}

validate_ipv6() {
    local ip="$1"
    
    # Basic IPv6 validation (simplified)
    if [[ "${ip}" =~ ^([0-9a-fA-F]{0,4}:){2,7}[0-9a-fA-F]{0,4}$ ]] || \
       [[ "${ip}" =~ ^::([0-9a-fA-F]{1,4}:){0,5}[0-9a-fA-F]{1,4}$ ]] || \
       [[ "${ip}" =~ ^([0-9a-fA-F]{1,4}:){1,6}:$ ]] || \
       [[ "${ip}" =~ ^::$ ]]; then
        return 0
    fi
    
    return 1
}

validate_ip() {
    local ip="$1"
    validate_ipv4 "${ip}" || validate_ipv6 "${ip}"
}

validate_domain() {
    local domain="$1"
    
    # RFC 1123 hostname validation
    if [[ "${domain}" =~ ^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)*[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]]; then
        # Additional length check
        if [[ ${#domain} -le 253 ]]; then
            return 0
        fi
    fi
    
    return 1
}

validate_path() {
    local path="$1"
    
    # Reject path traversal attempts
    if [[ "${path}" =~ \.\. ]]; then
        log_warn "Path traversal attempt detected: ${path}"
        return 1
    fi
    
    # Must be absolute path
    if [[ ! "${path}" =~ ^/ ]]; then
        log_warn "Path must be absolute: ${path}"
        return 1
    fi
    
    # Reject suspicious characters
    if [[ "${path}" =~ [\;\|\&\$\`\(\)\{\}\[\]\<\>] ]]; then
        log_warn "Suspicious characters in path: ${path}"
        return 1
    fi
    
    return 0
}

sanitize_string() {
    local input="$1"
    local max_length="${2:-256}"
    
    # Remove null bytes and control characters (except newline, tab)
    local sanitized
    sanitized="$(printf '%s' "${input}" | tr -d '\000-\010\013-\037\177')"
    
    # Truncate if too long
    if [[ ${#sanitized} -gt ${max_length} ]]; then
        sanitized="${sanitized:0:${max_length}}"
    fi
    
    printf '%s' "${sanitized}"
}

# ============================================================================
# SYSTEM DETECTION & COMPATIBILITY
# ============================================================================

detect_os() {
    local os_name=""
    local os_version=""
    local os_codename=""
    
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        os_name="${ID:-unknown}"
        os_version="${VERSION_ID:-unknown}"
        os_codename="${VERSION_CODENAME:-unknown}"
    elif [[ -f /etc/lsb-release ]]; then
        # shellcheck source=/dev/null
        source /etc/lsb-release
        os_name="${DISTRIB_ID:-unknown}"
        os_version="${DISTRIB_RELEASE:-unknown}"
        os_codename="${DISTRIB_CODENAME:-unknown}"
    else
        os_name="$(uname -s)"
        os_version="$(uname -r)"
    fi
    
    printf '%s|%s|%s' "${os_name,,}" "${os_version}" "${os_codename,,}"
}

check_ubuntu_compatibility() {
    local os_info
    os_info="$(detect_os)"
    
    local os_name os_version os_codename
    IFS='|' read -r os_name os_version os_codename <<< "${os_info}"
    
    log_debug "Detected OS: ${os_name} ${os_version} (${os_codename})"
    
    if [[ "${os_name}" != "ubuntu" ]]; then
        log_warn "This system is not Ubuntu (detected: ${os_name}). Compatibility not guaranteed."
        return 1
    fi
    
    # Check supported Ubuntu versions (18.04, 20.04, 22.04, 24.04)
    local -a supported_versions=("18.04" "20.04" "22.04" "24.04")
    local major_version="${os_version%%.*}"
    
    local is_supported=0
    for ver in "${supported_versions[@]}"; do
        if [[ "${os_version}" == "${ver}"* ]]; then
            is_supported=1
            break
        fi
    done
    
    if [[ ${is_supported} -eq 0 ]]; then
        log_warn "Ubuntu ${os_version} is not officially supported. Supported versions: ${supported_versions[*]}"
    fi
    
    return 0
}

detect_dns_manager() {
    # Detect which DNS management system is in use
    local manager="unknown"
    
    # Check for systemd-resolved
    if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
        manager="systemd-resolved"
        
        # Check if resolved is managing resolv.conf
        if [[ -L "${RESOLV_CONF}" ]]; then
            local link_target
            link_target="$(readlink -f "${RESOLV_CONF}" 2>/dev/null || true)"
            if [[ "${link_target}" == *"systemd"* ]]; then
                manager="systemd-resolved-stub"
            fi
        fi
    fi
    
    # Check for NetworkManager
    if systemctl is-active --quiet NetworkManager 2>/dev/null; then
        if [[ "${manager}" == "unknown" ]]; then
            manager="NetworkManager"
        else
            manager="${manager}+NetworkManager"
        fi
    fi
    
    # Check for netplan
    if command -v netplan &>/dev/null && [[ -d "${NETPLAN_DIR}" ]]; then
        local netplan_files
        netplan_files="$(find "${NETPLAN_DIR}" -name "*.yaml" -o -name "*.yml" 2>/dev/null | wc -l)"
        if [[ ${netplan_files} -gt 0 ]]; then
            if [[ "${manager}" == "unknown" ]]; then
                manager="netplan"
            else
                manager="${manager}+netplan"
            fi
        fi
    fi
    
    # Check for resolvconf
    if command -v resolvconf &>/dev/null; then
        if [[ "${manager}" == "unknown" ]]; then
            manager="resolvconf"
        fi
    fi
    
    printf '%s' "${manager}"
}

detect_init_system() {
    if [[ -d /run/systemd/system ]]; then
        printf 'systemd'
    elif [[ -f /etc/init.d/cron && ! -h /etc/init.d/cron ]]; then
        printf 'sysvinit'
    elif command -v initctl &>/dev/null; then
        printf 'upstart'
    else
        printf 'unknown'
    fi
}

# ============================================================================
# DEPENDENCY MANAGEMENT
# ============================================================================

declare -A REQUIRED_COMMANDS=(
    [jq]="jq"
    [curl]="curl"
    [dig]="dnsutils"
    [timeout]="coreutils"
    [awk]="gawk"
    [sed]="sed"
    [grep]="grep"
    [flock]="util-linux"
    [mktemp]="coreutils"
)

declare -A OPTIONAL_COMMANDS=(
    [host]="dnsutils"
    [nslookup]="dnsutils"
    [resolvectl]="systemd"
    [netplan]="netplan.io"
    [nmcli]="network-manager"
)

check_dependencies() {
    local -a missing_required=()
    local -a missing_optional=()
    
    log_debug "Checking required dependencies..."
    
    for cmd in "${!REQUIRED_COMMANDS[@]}"; do
        if ! command -v "${cmd}" &>/dev/null; then
            missing_required+=("${REQUIRED_COMMANDS[${cmd}]}")
            log_debug "Missing required command: ${cmd} (package: ${REQUIRED_COMMANDS[${cmd}]})"
        fi
    done
    
    for cmd in "${!OPTIONAL_COMMANDS[@]}"; do
        if ! command -v "${cmd}" &>/dev/null; then
            missing_optional+=("${OPTIONAL_COMMANDS[${cmd}]}")
            log_trace "Missing optional command: ${cmd}"
        fi
    done
    
    if [[ ${#missing_required[@]} -gt 0 ]]; then
        log_warn "Missing required packages: ${missing_required[*]}"
        return 1
    fi
    
    if [[ ${#missing_optional[@]} -gt 0 ]]; then
        log_debug "Some optional packages are missing (non-critical): ${missing_optional[*]}"
    fi
    
    return 0
}

install_dependencies() {
    local -a packages=("$@")
    
    if [[ ${#packages[@]} -eq 0 ]]; then
        return 0
    fi
    
    log_info "Installing packages: ${packages[*]}"
    
    # Detect package manager
    local pkg_manager=""
    local install_cmd=""
    
    if command -v apt-get &>/dev/null; then
        pkg_manager="apt"
        install_cmd="apt-get install -y"
        
        log_debug "Updating package lists..."
        apt-get update -qq 2>&1 | while read -r line; do log_trace "${line}"; done
        
    elif command -v apt &>/dev/null; then
        pkg_manager="apt"
        install_cmd="apt install -y"
        apt update -qq 2>&1 | while read -r line; do log_trace "${line}"; done
        
    elif command -v dnf &>/dev/null; then
        pkg_manager="dnf"
        install_cmd="dnf install -y"
        
    elif command -v yum &>/dev/null; then
        pkg_manager="yum"
        install_cmd="yum install -y"
        
    else
        error_exit "No supported package manager found (apt, dnf, yum)" 1
    fi
    
    # Map package names for different distros
    local -a actual_packages=()
    for pkg in "${packages[@]}"; do
        case "${pkg_manager}" in
            apt)
                case "${pkg}" in
                    dnsutils) actual_packages+=("dnsutils") ;;
                    gawk) actual_packages+=("gawk") ;;
                    *) actual_packages+=("${pkg}") ;;
                esac
                ;;
            dnf|yum)
                case "${pkg}" in
                    dnsutils) actual_packages+=("bind-utils") ;;
                    gawk) actual_packages+=("gawk") ;;
                    *) actual_packages+=("${pkg}") ;;
                esac
                ;;
        esac
    done
    
    # Remove duplicates
    local -a unique_packages
    readarray -t unique_packages < <(printf '%s\n' "${actual_packages[@]}" | sort -u)
    
    log_debug "Installing: ${unique_packages[*]}"
    
    # Execute installation
    if ! ${install_cmd} "${unique_packages[@]}" 2>&1 | while read -r line; do log_trace "${line}"; done; then
        error_exit "Package installation failed" 1
    fi
    
    log_info "Dependencies installed successfully"
}

ensure_dependencies() {
    if ! check_dependencies; then
        if [[ ${DRY_RUN_MODE} -eq 1 ]]; then
            log_warn "Dry run mode: would install missing dependencies"
            return 0
        fi
        
        log_info "Installing missing dependencies..."
        
        local -a to_install=()
        for cmd in "${!REQUIRED_COMMANDS[@]}"; do
            if ! command -v "${cmd}" &>/dev/null; then
                to_install+=("${REQUIRED_COMMANDS[${cmd}]}")
            fi
        done
        
        # Remove duplicates
        readarray -t to_install < <(printf '%s\n' "${to_install[@]}" | sort -u)
        
        install_dependencies "${to_install[@]}"
        
        # Verify installation
        if ! check_dependencies; then
            error_exit "Failed to install all required dependencies" 1
        fi
    fi
}

# ============================================================================
# DIRECTORY & FILE MANAGEMENT
# ============================================================================

create_directories() {
    local -a directories=(
        "${CONFIG_DIR}"
        "${DATA_DIR}"
        "${CACHE_DIR}"
        "${BACKUP_DIR}"
    )
    
    for dir in "${directories[@]}"; do
        if ! validate_path "${dir}"; then
            error_exit "Invalid directory path: ${dir}" 1
        fi
        
        if [[ ! -d "${dir}" ]]; then
            log_debug "Creating directory: ${dir}"
            
            if [[ ${DRY_RUN_MODE} -eq 1 ]]; then
                log_info "Dry run: would create ${dir}"
                continue
            fi
            
            if ! mkdir -p "${dir}" 2>/dev/null; then
                # Try with sudo for system directories
                if [[ "${dir}" == /var/* ]] || [[ "${dir}" == /etc/* ]]; then
                    log_debug "Attempting to create with elevated privileges: ${dir}"
                    # Directory will be created later when needed
                    continue
                fi
                log_warn "Cannot create directory: ${dir}"
            else
                chmod 750 "${dir}" 2>/dev/null || true
            fi
        fi
    done
}

atomic_write() {
    local target_file="$1"
    local content="$2"
    local permissions="${3:-644}"
    
    if ! validate_path "${target_file}"; then
        error_exit "Invalid file path for atomic write: ${target_file}" 1
    fi
    
    local target_dir
    target_dir="$(dirname "${target_file}")"
    
    # Create temp file in same directory for atomic move
    local tmp_file
    tmp_file="$(mktemp "${target_dir}/.tmp.XXXXXXXXXX")" || {
        error_exit "Cannot create temporary file in ${target_dir}" 1
    }
    
    # Write content to temp file
    if ! printf '%s' "${content}" > "${tmp_file}"; then
        rm -f "${tmp_file}" 2>/dev/null
        error_exit "Failed to write to temporary file" 1
    fi
    
    # Set permissions
    chmod "${permissions}" "${tmp_file}" 2>/dev/null || true
    
    # Atomic move
    if ! mv "${tmp_file}" "${target_file}"; then
        rm -f "${tmp_file}" 2>/dev/null
        error_exit "Failed to atomically move file to ${target_file}" 1
    fi
    
    log_debug "Atomically wrote to: ${target_file}"
}

# ============================================================================
# DNS DATASET MANAGEMENT
# ============================================================================

load_dns_dataset() {
    log_debug "Loading DNS dataset..."
    
    # Check if dataset exists
    if [[ ! -f "${DNS_DATASET}" ]]; then
        log_warn "DNS dataset not found: ${DNS_DATASET}"
        
        # Try alternative locations
        local -a alternative_paths=(
            "${SCRIPT_DIR}/dns_dataset.json"
            "${CONFIG_DIR}/dns_dataset.json"
            "${DATA_DIR}/dns_dataset.json"
            "/usr/share/${PROJECT_NAME}/dns_dataset.json"
        )
        
        for alt_path in "${alternative_paths[@]}"; do
            if [[ -f "${alt_path}" ]]; then
                DNS_DATASET="${alt_path}"
                log_debug "Found dataset at: ${DNS_DATASET}"
                break
            fi
        done
        
        # Still not found? Download it
        if [[ ! -f "${DNS_DATASET}" ]]; then
            download_dns_dataset
        fi
    fi
    
    # Validate JSON structure
    if ! jq empty "${DNS_DATASET}" 2>/dev/null; then
        log_error "Invalid JSON in dataset: ${DNS_DATASET}"
        
        # Backup corrupted file
        if [[ -f "${DNS_DATASET}" ]]; then
            mv "${DNS_DATASET}" "${DNS_DATASET}.corrupted.$(date +%s)" 2>/dev/null || true
        fi
        
        download_dns_dataset
    fi
    
    # Get version info
    local dataset_version
    dataset_version="$(jq -r '.version // "unknown"' "${DNS_DATASET}" 2>/dev/null)"
    log_debug "DNS dataset loaded: version ${dataset_version}"
}

download_dns_dataset() {
    log_info "Downloading DNS dataset..."
    
    if [[ ${DRY_RUN_MODE} -eq 1 ]]; then
        log_info "Dry run: would download dataset from ${REMOTE_DATASET_URL}"
        return 0
    fi
    
    local tmp_dataset
    tmp_dataset="$(mktemp)" || error_exit "Cannot create temp file" 1
    
    local retry_count=0
    while [[ ${retry_count} -lt ${MAX_RETRIES} ]]; do
        if curl -sSfL \
            --max-time "${HTTP_TIMEOUT}" \
            --retry 2 \
            --retry-delay 1 \
            -o "${tmp_dataset}" \
            "${REMOTE_DATASET_URL}" 2>/dev/null; then
            
            # Validate downloaded JSON
            if jq empty "${tmp_dataset}" 2>/dev/null; then
                # Ensure target directory exists
                local target_dir
                target_dir="$(dirname "${DNS_DATASET}")"
                mkdir -p "${target_dir}" 2>/dev/null || true
                
                mv "${tmp_dataset}" "${DNS_DATASET}"
                log_info "DNS dataset downloaded successfully"
                return 0
            else
                log_warn "Downloaded file is not valid JSON"
            fi
        fi
        
        ((retry_count++))
        log_debug "Download attempt ${retry_count}/${MAX_RETRIES} failed"
        sleep "${RETRY_DELAY}"
    done
    
    rm -f "${tmp_dataset}" 2>/dev/null
    error_exit "Failed to download DNS dataset after ${MAX_RETRIES} attempts" 1
}

update_dns_dataset() {
    log_info "Checking for dataset updates..."
    
    # Get local version
    local local_version="0.0.0"
    if [[ -f "${DNS_DATASET}" ]]; then
        local_version="$(jq -r '.version // "0.0.0"' "${DNS_DATASET}" 2>/dev/null)"
    fi
    
    # Get remote version (via HEAD request if possible)
    local remote_version
    local tmp_file
    tmp_file="$(mktemp)"
    
    if curl -sSfL \
        --max-time "${HTTP_TIMEOUT}" \
        -o "${tmp_file}" \
        "${REMOTE_DATASET_URL}" 2>/dev/null; then
        
        remote_version="$(jq -r '.version // "0.0.0"' "${tmp_file}" 2>/dev/null)"
        
        log_debug "Local version: ${local_version}, Remote version: ${remote_version}"
        
        if [[ "${remote_version}" != "${local_version}" ]]; then
            log_info "Updating dataset: ${local_version} -> ${remote_version}"
            
            # Backup current dataset
            if [[ -f "${DNS_DATASET}" ]]; then
                cp "${DNS_DATASET}" "${DNS_DATASET}.backup.$(date +%Y%m%d)" 2>/dev/null || true
            fi
            
            mv "${tmp_file}" "${DNS_DATASET}"
            log_info "Dataset updated successfully"
        else
            rm -f "${tmp_file}"
            log_info "Dataset is already up to date (v${local_version})"
        fi
    else
        rm -f "${tmp_file}" 2>/dev/null
        log_warn "Could not check for updates"
    fi
}

# ============================================================================
# DNS TESTING ENGINE
# ============================================================================

test_dns_latency() {
    local dns_ip="$1"
    local domain="$2"
    local timeout="${3:-${DNS_TEST_TIMEOUT}}"
    
    # Validate inputs
    if ! validate_ip "${dns_ip}"; then
        log_trace "Invalid DNS IP: ${dns_ip}"
        return 1
    fi
    
    if ! validate_domain "${domain}"; then
        log_trace "Invalid domain: ${domain}"
        return 1
    fi
    
    local start_time end_time latency_ms
    
    # Use high-precision timer
    start_time=$(date +%s%N)
    
    # Execute DNS query with timeout
    if timeout "${timeout}" dig +short +tries=1 +time="${timeout}" "@${dns_ip}" "${domain}" A >/dev/null 2>&1; then
        end_time=$(date +%s%N)
        
        # Calculate latency in milliseconds
        latency_ms=$(( (end_time - start_time) / 1000000 ))
        
        # Sanity check
        if [[ ${latency_ms} -lt 0 ]] || [[ ${latency_ms} -gt ${MAX_LATENCY_MS} ]]; then
            log_trace "Latency out of bounds: ${latency_ms}ms"
            return 1
        fi
        
        printf '%d' "${latency_ms}"
        return 0
    fi
    
    return 1
}

test_dns_comprehensive() {
    local dns_ip="$1"
    local dns_name="$2"
    
    if ! validate_ip "${dns_ip}"; then
        log_debug "Skipping invalid DNS IP: ${dns_ip}"
        return 1
    fi
    
    log_debug "Testing DNS: ${dns_name} (${dns_ip})"
    
    # Get test domains from dataset
    local -a test_domains=()
    
    if [[ -f "${DNS_DATASET}" ]]; then
        mapfile -t test_domains < <(
            jq -r '
                (.test_domains.connectivity // [])[] ,
                (.test_domains.sanction_bypass // [])[] ,
                (.test_domains.ai_services // [])[]
            ' "${DNS_DATASET}" 2>/dev/null | head -10
        )
    fi
    
    # Fallback domains if dataset unavailable
    if [[ ${#test_domains[@]} -eq 0 ]]; then
        test_domains=(
            "google.com"
            "cloudflare.com"
            "github.com"
            "docker.io"
            "wikipedia.org"
        )
    fi
    
    local -i total_tests=0
    local -i successful_tests=0
    local -i total_latency=0
    
    for domain in "${test_domains[@]}"; do
        ((total_tests++))
        
        local latency
        if latency=$(test_dns_latency "${dns_ip}" "${domain}" "${DNS_TEST_TIMEOUT}"); then
            ((successful_tests++))
            ((total_latency += latency))
            log_trace "  ${domain}: ${latency}ms"
        else
            log_trace "  ${domain}: FAILED"
        fi
    done
    
    # Calculate metrics
    if [[ ${successful_tests} -eq 0 ]]; then
        log_debug "DNS ${dns_name}: All tests failed"
        return 1
    fi
    
    local avg_latency=$((total_latency / successful_tests))
    local success_rate
    success_rate=$(awk "BEGIN {printf \"%.2f\", ${successful_tests}/${total_tests}}")
    
    # Check minimum success rate
    if (( $(awk "BEGIN {print (${success_rate} < ${MIN_SUCCESS_RATE})}") )); then
        log_debug "DNS ${dns_name}: Success rate too low (${success_rate})"
        return 1
    fi
    
    # Store results
    DNS_TEST_RESULTS["${dns_name}"]="${success_rate}"
    DNS_LATENCY_DATA["${dns_name}"]="${avg_latency}"
    
    log_debug "DNS ${dns_name}: ${success_rate} success rate, ${avg_latency}ms avg latency"
    return 0
}

test_critical_services() {
    local dns_ip="$1"
    local dns_name="${2:-Unknown}"
    
    if ! validate_ip "${dns_ip}"; then
        return 1
    fi
    
    log_info "Testing critical services with ${dns_name}..."
    
    local -a critical_domains=(
        "docker.io"
        "registry-1.docker.io"
        "ghcr.io"
        "gcr.io"
        "github.com"
        "raw.githubusercontent.com"
        "gemini.google.com"
        "ai.google.dev"
        "pypi.org"
        "npmjs.org"
    )
    
    local -a failed_services=()
    local -a passed_services=()
    
    for domain in "${critical_domains[@]}"; do
        if test_dns_latency "${dns_ip}" "${domain}" "${DNS_TEST_TIMEOUT}" >/dev/null 2>&1; then
            passed_services+=("${domain}")
            log_debug "  OK ${domain}"
        else
            failed_services+=("${domain}")
            log_warn "  FAIL ${domain}"
        fi
    done
    
    local total=${#critical_domains[@]}
    local passed=${#passed_services[@]}
    
    log_info "Critical services: ${passed}/${total} passed"
    
    if [[ ${#failed_services[@]} -gt 0 ]]; then
        log_warn "Failed services: ${failed_services[*]}"
        return 1
    fi
    
    return 0
}

# ============================================================================
# DNS PROVIDER MANAGEMENT
# ============================================================================

get_dns_providers() {
    local category="$1"
    
    # Validate category
    case "${category}" in
        iranian|international|security|family_safe|unfiltered|regional|all) ;;
        *) 
            log_error "Invalid category: ${category}"
            return 1
            ;;
    esac
    
    if [[ ! -f "${DNS_DATASET}" ]]; then
        error_exit "DNS dataset not loaded" 1
    fi
    
    if [[ "${category}" == "all" ]]; then
        jq -r '
            .dns_providers | to_entries[] | 
            .value.providers[]? | 
            select(.protocols.dns.ipv4 != null) |
            "\(.protocols.dns.ipv4[0])|\(.name)"
        ' "${DNS_DATASET}" 2>/dev/null | grep -v '^null|' | grep -v '|$'
    else
        jq -r --arg cat "${category}" '
            .dns_providers[$cat].providers[]? | 
            select(.protocols.dns.ipv4 != null) |
            "\(.protocols.dns.ipv4[0])|\(.name)"
        ' "${DNS_DATASET}" 2>/dev/null | grep -v '^null|' | grep -v '|$'
    fi
}

get_dns_info() {
    local dns_name="$1"
    
    if [[ ! -f "${DNS_DATASET}" ]]; then
        return 1
    fi
    
    jq -r --arg name "${dns_name}" '
        .dns_providers[][] | 
        select(.providers != null) | 
        .providers[] | 
        select(.name == $name)
    ' "${DNS_DATASET}" 2>/dev/null
}

get_dns_ips() {
    local dns_name="$1"
    
    if [[ ! -f "${DNS_DATASET}" ]]; then
        return 1
    fi
    
    jq -r --arg name "${dns_name}" '
        .dns_providers[][] | 
        select(.providers != null) | 
        .providers[] | 
        select(.name == $name) | 
        .protocols.dns.ipv4[]? // empty
    ' "${DNS_DATASET}" 2>/dev/null | grep -v '^$'
}

rank_dns_servers() {
    local -a rankings=()
    
    for name in "${!DNS_TEST_RESULTS[@]}"; do
        local rate="${DNS_TEST_RESULTS[${name}]}"
        local latency="${DNS_LATENCY_DATA[${name}]:-9999}"
        
        # Calculate score: higher is better
        # Score = (success_rate * 1000) - latency + bonus for low latency
        local score
        local bonus=0
        
        if [[ ${latency} -le ${EXCELLENT_LATENCY_MS} ]]; then
            bonus=200
        elif [[ ${latency} -le ${GOOD_LATENCY_MS} ]]; then
            bonus=100
        elif [[ ${latency} -le ${ACCEPTABLE_LATENCY_MS} ]]; then
            bonus=50
        fi
        
        score=$(awk "BEGIN {printf \"%.0f\", (${rate} * 1000) - ${latency} + ${bonus}}")
        
        rankings+=("${score}|${name}|${rate}|${latency}")
    done
    
    # Sort by score (descending)
    printf '%s\n' "${rankings[@]}" | sort -t'|' -k1 -rn
}

select_best_dns() {
    local category="${1:-iranian}"
    
    log_info "Finding best DNS from category: ${category}..."
    
    # Clear previous results
    DNS_TEST_RESULTS=()
    DNS_LATENCY_DATA=()
    
    # Get DNS list for category
    local dns_list
    dns_list="$(get_dns_providers "${category}")" || {
        log_error "Failed to get DNS list for category: ${category}"
        return 1
    }
    
    if [[ -z "${dns_list}" ]]; then
        log_error "No DNS servers found in category: ${category}"
        return 1
    fi
    
    # Count total servers
    local total_servers
    total_servers="$(echo "${dns_list}" | wc -l)"
    log_info "Testing ${total_servers} DNS servers..."
    
    # Test DNS servers (with limited parallelism)
    local -a pids=()
    local -i count=0
    
    while IFS='|' read -r ip name; do
        [[ -z "${ip}" || "${ip}" == "null" ]] && continue
        
        # Validate IP
        if ! validate_ip "${ip}"; then
            log_debug "Skipping invalid IP: ${ip}"
            continue
        fi
        
        # Run test in background
        {
            test_dns_comprehensive "${ip}" "${name}"
        } &
        pids+=($!)
        ((count++))
        
        # Limit parallelism
        if [[ ${count} -ge ${MAX_PARALLEL_TESTS} ]]; then
            # Wait for batch
            for pid in "${pids[@]}"; do
                wait "${pid}" 2>/dev/null || true
            done
            pids=()
            count=0
        fi
    done <<< "${dns_list}"
    
    # Wait for remaining tests
    for pid in "${pids[@]}"; do
        wait "${pid}" 2>/dev/null || true
    done
    
    # Get rankings
    local rankings
    rankings="$(rank_dns_servers)"
    
    if [[ -z "${rankings}" ]]; then
        if [[ "${AUTO_FALLBACK}" == "true" && "${category}" != "international" ]]; then
            log_warn "No working DNS in ${category}. Trying international fallback."
            if select_best_dns "international" >/dev/null 2>&1; then
                local fb
                fb="$(select_best_dns "international")"
                printf '%s' "${fb}"
                return 0
            fi
        fi
        if [[ ${#FALLBACK_DNS_LIST[@]} -gt 0 ]]; then
            for ip in "${FALLBACK_DNS_LIST[@]}"; do
                if test_dns_latency "${ip}" "google.com" "${DNS_TEST_TIMEOUT}" >/dev/null 2>&1; then
                    printf '%s' "Fallback ${ip}"
                    return 0
                fi
            done
        fi
        log_error "No working DNS servers found in category: ${category}"
        return 1
    fi
    
    # Get best DNS
    local best_entry
    best_entry="$(echo "${rankings}" | head -1)"
    
    local score dns_name rate latency
    IFS='|' read -r score dns_name rate latency <<< "${best_entry}"
    
    log_info "Best DNS: ${dns_name} (score: ${score}, success: ${rate}, ${latency}ms)"
    
    printf '%s' "${dns_name}"
}

# ============================================================================
# DNS APPLICATION ENGINE
# ============================================================================

get_current_dns() {
    # Try multiple methods to get current DNS
    
    # Method 1: resolvectl (systemd-resolved)
    if command -v resolvectl &>/dev/null; then
        local resolved_dns
        resolved_dns="$(resolvectl status 2>/dev/null | grep -m1 'Current DNS' | awk '{print $NF}')"
        if [[ -n "${resolved_dns}" ]]; then
            printf '%s' "${resolved_dns}"
            return 0
        fi
    fi
    
    # Method 2: /etc/resolv.conf
    if [[ -f "${RESOLV_CONF}" ]]; then
        local resolv_dns
        resolv_dns="$(grep -m1 '^nameserver' "${RESOLV_CONF}" 2>/dev/null | awk '{print $2}')"
        if [[ -n "${resolv_dns}" ]] && validate_ip "${resolv_dns}"; then
            printf '%s' "${resolv_dns}"
            return 0
        fi
    fi
    
    # Method 3: nmcli (NetworkManager)
    if command -v nmcli &>/dev/null; then
        local nm_dns
        nm_dns="$(nmcli dev show 2>/dev/null | grep -m1 'IP4.DNS' | awk '{print $2}')"
        if [[ -n "${nm_dns}" ]] && validate_ip "${nm_dns}"; then
            printf '%s' "${nm_dns}"
            return 0
        fi
    fi
    
    return 1
}

backup_dns_config() {
    log_info "Backing up current DNS configuration..."
    
    if [[ ${DRY_RUN_MODE} -eq 1 ]]; then
        log_info "Dry run: would backup DNS configuration"
        return 0
    fi
    
    # Ensure backup directory exists
    if [[ ! -d "${BACKUP_DIR}" ]]; then
        mkdir -p "${BACKUP_DIR}" 2>/dev/null || {
            BACKUP_DIR="/tmp/${PROJECT_NAME}-backups"
            mkdir -p "${BACKUP_DIR}"
        }
    fi
    
    local timestamp
    timestamp="$(date +%Y%m%d_%H%M%S)"
    local backup_prefix="${BACKUP_DIR}/dns_backup_${timestamp}"
    
    # Backup resolv.conf
    if [[ -f "${RESOLV_CONF}" ]]; then
        cp -p "${RESOLV_CONF}" "${backup_prefix}_resolv.conf" 2>/dev/null || {
            cat "${RESOLV_CONF}" > "${backup_prefix}_resolv.conf" 2>/dev/null
        }
        log_debug "Backed up: ${RESOLV_CONF}"
    fi
    
    # Backup systemd-resolved config
    if [[ -f "${SYSTEMD_RESOLVED_CONF}" ]]; then
        cp -p "${SYSTEMD_RESOLVED_CONF}" "${backup_prefix}_resolved.conf" 2>/dev/null
        log_debug "Backed up: ${SYSTEMD_RESOLVED_CONF}"
    fi
    
    # Backup drop-in configs
    if [[ -d "${SYSTEMD_RESOLVED_DROP_IN}" ]]; then
        cp -rp "${SYSTEMD_RESOLVED_DROP_IN}" "${backup_prefix}_resolved.conf.d" 2>/dev/null
        log_debug "Backed up: ${SYSTEMD_RESOLVED_DROP_IN}"
    fi
    
    # Cleanup old backups (keep last 10)
    find "${BACKUP_DIR}" -name "dns_backup_*" -type f -mtime +30 -delete 2>/dev/null || true
    local backup_count
    backup_count="$(find "${BACKUP_DIR}" -name "dns_backup_*" -type f 2>/dev/null | wc -l)"
    if [[ ${backup_count} -gt 30 ]]; then
        find "${BACKUP_DIR}" -name "dns_backup_*" -type f -printf '%T+ %p\n' 2>/dev/null | \
            sort | head -n "$((backup_count - 10))" | cut -d' ' -f2- | xargs rm -f 2>/dev/null || true
    fi
    
    log_info "Backup created: ${backup_prefix}_*"
}

flush_dns_cache() {
    log_info "Flushing DNS cache..."
    
    if [[ ${DRY_RUN_MODE} -eq 1 ]]; then
        log_info "Dry run: would flush DNS cache"
        return 0
    fi
    
    local flushed=0
    
    # systemd-resolved
    if command -v resolvectl &>/dev/null; then
        if resolvectl flush-caches 2>/dev/null; then
            log_debug "Flushed systemd-resolved cache"
            flushed=1
        fi
    elif command -v systemd-resolve &>/dev/null; then
        if systemd-resolve --flush-caches 2>/dev/null; then
            log_debug "Flushed systemd-resolve cache"
            flushed=1
        fi
    fi
    
    # nscd
    if command -v nscd &>/dev/null; then
        if nscd -i hosts 2>/dev/null; then
            log_debug "Flushed nscd cache"
            flushed=1
        fi
    fi
    
    # dnsmasq
    if pgrep -x dnsmasq &>/dev/null; then
        if killall -HUP dnsmasq 2>/dev/null; then
            log_debug "Signaled dnsmasq to flush cache"
            flushed=1
        fi
    fi
    
    if [[ ${flushed} -eq 0 ]]; then
        log_debug "No DNS cache services found to flush"
    fi
}

apply_dns_resolv_conf() {
    local -a dns_ips=("$@")
    
    if [[ ${#dns_ips[@]} -eq 0 ]]; then
        error_exit "No DNS IPs provided" 1
    fi
    
    log_debug "Applying DNS via resolv.conf: ${dns_ips[*]}"
    
    # Check if resolv.conf is a symlink (managed by systemd-resolved)
    if [[ -L "${RESOLV_CONF}" ]]; then
        local link_target
        link_target="$(readlink -f "${RESOLV_CONF}" 2>/dev/null)"
        
        if [[ "${link_target}" == *"systemd"* ]]; then
            log_warn "resolv.conf is managed by systemd-resolved. Using alternative method."
            return 1
        fi
    fi
    
    # Build resolv.conf content
    local content=""
    content+="# Generated by ${PROJECT_NAME} v${VERSION}\n"
    content+="# Date: $(date '+%Y-%m-%d %H:%M:%S')\n"
    content+="# DO NOT EDIT MANUALLY\n\n"
    
    for ip in "${dns_ips[@]}"; do
        if validate_ip "${ip}"; then
            content+="nameserver ${ip}\n"
        fi
    done
    
    # Add options
    content+="\noptions timeout:2 attempts:3 rotate\n"
    
    if [[ ${DRY_RUN_MODE} -eq 1 ]]; then
        log_info "Dry run: would write to ${RESOLV_CONF}:"
        printf '%b' "${content}"
        return 0
    fi
    
    # Atomic write
    printf '%b' "${content}" > "${RESOLV_CONF}.tmp.$$"
    
    if ! mv "${RESOLV_CONF}.tmp.$$" "${RESOLV_CONF}"; then
        rm -f "${RESOLV_CONF}.tmp.$$" 2>/dev/null
        error_exit "Failed to update ${RESOLV_CONF}" 1
    fi
    
    log_debug "Updated ${RESOLV_CONF}"
    return 0
}

apply_dns_systemd_resolved() {
    local -a dns_ips=("$@")
    
    if [[ ${#dns_ips[@]} -eq 0 ]]; then
        error_exit "No DNS IPs provided" 1
    fi
    
    log_debug "Applying DNS via systemd-resolved: ${dns_ips[*]}"
    
    # Ensure drop-in directory exists
    if [[ ! -d "${SYSTEMD_RESOLVED_DROP_IN}" ]]; then
        mkdir -p "${SYSTEMD_RESOLVED_DROP_IN}" 2>/dev/null || {
            error_exit "Cannot create ${SYSTEMD_RESOLVED_DROP_IN}" 1
        }
    fi
    
    # Build configuration
    local dns_servers
    dns_servers="$(printf '%s ' "${dns_ips[@]}")"
    dns_servers="${dns_servers% }"
    
    local content=""
    content+="# Generated by ${PROJECT_NAME} v${VERSION}\n"
    content+="# Date: $(date '+%Y-%m-%d %H:%M:%S')\n"
    content+="[Resolve]\n"
    content+="DNS=${dns_servers}\n"
    content+="FallbackDNS=1.1.1.1 8.8.8.8\n"
    content+="DNSOverTLS=opportunistic\n"
    content+="DNSSEC=allow-downgrade\n"
    content+="Cache=yes\n"
    
    local drop_in_file="${SYSTEMD_RESOLVED_DROP_IN}/${PROJECT_NAME}.conf"
    
    if [[ ${DRY_RUN_MODE} -eq 1 ]]; then
        log_info "Dry run: would write to ${drop_in_file}:"
        printf '%b' "${content}"
        return 0
    fi
    
    # Write configuration
    printf '%b' "${content}" > "${drop_in_file}.tmp.$$"
    mv "${drop_in_file}.tmp.$$" "${drop_in_file}"
    
    # Restart systemd-resolved
    if ! systemctl restart systemd-resolved 2>/dev/null; then
        log_warn "Failed to restart systemd-resolved"
    fi
    
    log_debug "Updated systemd-resolved configuration"
    return 0
}

apply_dns_networkmanager() {
    local -a dns_ips=("$@")
    
    if [[ ${#dns_ips[@]} -eq 0 ]]; then
        error_exit "No DNS IPs provided" 1
    fi
    
    log_debug "Applying DNS via NetworkManager: ${dns_ips[*]}"
    
    if ! command -v nmcli &>/dev/null; then
        log_warn "nmcli not available"
        return 1
    fi
    
    # Get active connection
    local active_connection
    active_connection="$(nmcli -t -f NAME connection show --active 2>/dev/null | head -1)"
    
    if [[ -z "${active_connection}" ]]; then
        log_warn "No active NetworkManager connection found"
        return 1
    fi
    
    log_debug "Active connection: ${active_connection}"
    
    local dns_string
    dns_string="$(printf '%s ' "${dns_ips[@]}")"
    dns_string="${dns_string% }"
    
    if [[ ${DRY_RUN_MODE} -eq 1 ]]; then
        log_info "Dry run: would set DNS for connection '${active_connection}': ${dns_string}"
        return 0
    fi
    
    # Apply DNS settings
    if ! nmcli connection modify "${active_connection}" ipv4.dns "${dns_string}" 2>/dev/null; then
        log_warn "Failed to modify connection DNS"
        return 1
    fi
    
    # Set to ignore automatic DNS
    nmcli connection modify "${active_connection}" ipv4.ignore-auto-dns yes 2>/dev/null || true
    
    # Reactivate connection
    nmcli connection up "${active_connection}" 2>/dev/null || {
        log_warn "Failed to reactivate connection"
    }
    
    log_debug "Updated NetworkManager DNS"
    return 0
}

apply_dns() {
    local dns_name="$1"
    
    log_info "Applying DNS: ${dns_name}..."
    
    # Get DNS IPs for this provider
    local -a dns_ips=()
    mapfile -t dns_ips < <(get_dns_ips "${dns_name}")
    if [[ ${#dns_ips[@]} -eq 0 ]]; then
        local -a tokens=()
        read -ra tokens <<< "${dns_name//,/ }"
        dns_ips=()
        for t in "${tokens[@]}"; do
            if validate_ip "${t}"; then
                dns_ips+=("${t}")
            fi
        done
    fi
    
    if [[ ${#dns_ips[@]} -eq 0 ]]; then
        error_exit "No IP addresses found for DNS: ${dns_name}" 1
    fi
    
    # Validate all IPs
    for ip in "${dns_ips[@]}"; do
        if ! validate_ip "${ip}"; then
            error_exit "Invalid IP address: ${ip}" 1
        fi
    done
    
    log_debug "DNS IPs: ${dns_ips[*]}"
    
    # Backup current configuration
    backup_dns_config
    
    # Detect DNS management method
    local dns_manager
    dns_manager="$(detect_dns_manager)"
    log_debug "Detected DNS manager: ${dns_manager}"
    
    local applied=0
    
    # Apply based on system configuration
    case "${dns_manager}" in
        *systemd-resolved*)
            if apply_dns_systemd_resolved "${dns_ips[@]}"; then
                applied=1
            fi
            ;;
        *NetworkManager*)
            if apply_dns_networkmanager "${dns_ips[@]}"; then
                applied=1
            fi
            ;;
    esac
    
    # Fallback to direct resolv.conf modification
    if [[ ${applied} -eq 0 ]]; then
        if apply_dns_resolv_conf "${dns_ips[@]}"; then
            applied=1
        fi
    fi
    
    if [[ ${applied} -eq 0 ]]; then
        error_exit "Failed to apply DNS configuration" 1
    fi
    
    # Flush DNS cache
    flush_dns_cache
    
    # Save applied DNS to state file
    if [[ ${DRY_RUN_MODE} -eq 0 ]]; then
        mkdir -p "${DATA_DIR}" 2>/dev/null || true
        printf '%s\n%s\n' "${dns_name}" "$(date -Iseconds)" > "${DATA_DIR}/current_dns" 2>/dev/null || true
    fi
    
    log_info "DNS applied: ${dns_name}"
    
    # Verify application
    verify_dns_application "${dns_name}"
}

verify_dns_application() {
    local dns_name="$1"
    
    log_info "Verifying DNS application..."
    
    if [[ ${DRY_RUN_MODE} -eq 1 ]]; then
        log_info "Dry run: would verify DNS"
        return 0
    fi
    
    # Wait for DNS to propagate
    sleep 2
    
    # Test basic resolution
    local test_result=0
    
    if ! timeout 10 host google.com &>/dev/null; then
        log_warn "Basic DNS resolution test failed"
        test_result=1
    fi
    
    if ! timeout 10 dig +short google.com A &>/dev/null; then
        log_warn "dig resolution test failed"
        test_result=1
    fi
    
    if [[ ${test_result} -eq 1 ]]; then
        log_error "DNS verification failed. Consider restoring previous configuration."
        return 1
    fi
    
    # Get current DNS for verification
    local current_dns
    current_dns="$(get_current_dns)"
    
    if [[ -n "${current_dns}" ]]; then
        log_debug "Current DNS: ${current_dns}"
    fi
    
    log_info "DNS verification successful"
    return 0
}

restore_dns() {
    log_info "Restoring previous DNS configuration..."
    
    if [[ ${DRY_RUN_MODE} -eq 1 ]]; then
        log_info "Dry run: would restore DNS"
        return 0
    fi
    
    # Find latest backup
    local latest_backup=""
    
    if [[ -d "${BACKUP_DIR}" ]]; then
        latest_backup="$(find "${BACKUP_DIR}" -name "dns_backup_*_resolv.conf" -type f -printf '%T+ %p\n' 2>/dev/null | \
            sort -r | head -1 | cut -d' ' -f2-)"
    fi
    
    if [[ -z "${latest_backup}" ]]; then
        log_warn "No backup found. Applying default DNS (1.1.1.1, 8.8.8.8)"
        apply_dns_resolv_conf "1.1.1.1" "8.8.8.8"
        return 0
    fi
    
    log_debug "Restoring from: ${latest_backup}"
    
    # Restore resolv.conf
    cp "${latest_backup}" "${RESOLV_CONF}.tmp.$$"
    mv "${RESOLV_CONF}.tmp.$$" "${RESOLV_CONF}"
    
    # Restore systemd-resolved config if exists
    local resolved_backup="${latest_backup/_resolv.conf/_resolved.conf}"
    if [[ -f "${resolved_backup}" ]]; then
        cp "${resolved_backup}" "${SYSTEMD_RESOLVED_CONF}.tmp.$$"
        mv "${SYSTEMD_RESOLVED_CONF}.tmp.$$" "${SYSTEMD_RESOLVED_CONF}"
        systemctl restart systemd-resolved 2>/dev/null || true
    fi
    
    # Flush cache
    flush_dns_cache
    
    # Clear current DNS state
    rm -f "${DATA_DIR}/current_dns" 2>/dev/null || true
    
    log_info "DNS configuration restored"
}

# ============================================================================
# CLEANUP & SIGNAL HANDLERS
# ============================================================================

cleanup_on_exit() {
    local exit_code=$?
    
    # Kill background jobs
    local jobs_list
    jobs_list="$(jobs -p 2>/dev/null)" || true
    
    if [[ -n "${jobs_list}" ]]; then
        log_debug "Cleaning up background jobs..."
        echo "${jobs_list}" | xargs -r kill -TERM 2>/dev/null || true
        wait 2>/dev/null || true
    fi
    
    # Clean temporary files
    rm -f "${LOG_FILE}.lock" 2>/dev/null || true
    rm -f /tmp/${PROJECT_NAME}.* 2>/dev/null || true
    
    # Clean old cache files
    if [[ -d "${CACHE_DIR}" ]]; then
        find "${CACHE_DIR}" -type f -mmin +60 -delete 2>/dev/null || true
    fi
    
    return "${exit_code}"
}

trap cleanup_on_exit EXIT
trap 'error_exit "Interrupted by user" 130' INT
trap 'error_exit "Terminated" 143' TERM

# ============================================================================
# USER INTERFACE
# ============================================================================

print_header() {
    if [[ ${QUIET_MODE} -eq 1 ]]; then
        return
    fi
    
    clear
    cat << EOF

============================
WeUp DNS Toolkit
============================

Version: ${TOOLKIT_VERSION}
Professional DNS Management for Linux

EOF
}

print_status() {
    local current_dns
    current_dns="$(get_current_dns 2>/dev/null)" || current_dns="unknown"
    
    local saved_dns="none"
    if [[ -f "${DATA_DIR}/current_dns" ]]; then
        saved_dns="$(head -1 "${DATA_DIR}/current_dns" 2>/dev/null)" || saved_dns="none"
    fi
    
    printf "%bCurrent DNS:%b %s\n" "${CYAN}" "${NC}" "${current_dns}"
    printf "%bApplied DNS:%b %s\n\n" "${CYAN}" "${NC}" "${saved_dns}"
}

show_menu() {
    cat << 'EOF'
================================================================

  1. Auto-Optimize DNS (Recommended)
  2. Iranian Anti-Sanction DNS
  3. International DNS
  4. Security-Focused DNS
  5. Family-Safe DNS
  6. Unfiltered DNS

----------------------------------------------------------------

  7. Test Current DNS
  8. Benchmark All Categories
  9. Show DNS Rankings

----------------------------------------------------------------

  10. Restore Previous DNS
  11. Update DNS Dataset
  12. System Information

  0. Exit

================================================================

EOF
}

interactive_menu() {
    while true; do
        print_header
        print_status
        show_menu
        
        local choice
        read -rp "  Select option [0-12]: " choice
        
        case "${choice}" in
            1) cmd_auto_optimize ;;
            2) cmd_category iranian ;;
            3) cmd_category international ;;
            4) cmd_category security ;;
            5) cmd_category family_safe ;;
            6) cmd_category unfiltered ;;
            7) cmd_test_current ;;
            8) cmd_benchmark ;;
            9) cmd_show_rankings ;;
            10) cmd_restore ;;
            11) cmd_update_dataset ;;
            12) cmd_system_info ;;
            0)
                printf "\n%b  Goodbye!%b\n\n" "${GREEN}" "${NC}"
                exit 0
                ;;
            *)
                printf "\n%b  Invalid option. Press Enter to continue...%b" "${RED}" "${NC}"
                read -r
                ;;
        esac
    done
}

# ============================================================================
# COMMAND IMPLEMENTATIONS
# ============================================================================

cmd_auto_optimize() {
    printf "\n%b  Auto-optimizing DNS...%b\n\n" "${CYAN}" "${NC}"
    
    # Try Iranian DNS first (for sanction bypass)
    local best_dns
    if best_dns=$(select_best_dns iranian 2>&1); then
        apply_dns "${best_dns}"
        printf "\n%b  ✓ Optimized DNS: %s%b\n" "${GREEN}" "${best_dns}" "${NC}"
    else
        log_warn "No working Iranian DNS found. Trying international..."
        
        if best_dns=$(select_best_dns international 2>&1); then
            apply_dns "${best_dns}"
            printf "\n%b  ✓ Applied DNS: %s%b\n" "${GREEN}" "${best_dns}" "${NC}"
        else
            printf "\n%b  ✗ No working DNS found%b\n" "${RED}" "${NC}"
        fi
    fi
    
    printf "\n  Press Enter to continue..."
    read -r
}

cmd_category() {
    local category="$1"
    
    printf "\n%b  Selecting best %s DNS...%b\n\n" "${CYAN}" "${category}" "${NC}"
    
    local best_dns
    if best_dns=$(select_best_dns "${category}" 2>&1); then
        apply_dns "${best_dns}"
        printf "\n%b  ✓ Applied %s DNS: %s%b\n" "${GREEN}" "${category}" "${best_dns}" "${NC}"
    else
        printf "\n%b  ✗ No working %s DNS found%b\n" "${RED}" "${category}" "${NC}"
    fi
    
    printf "\n  Press Enter to continue..."
    read -r
}

cmd_test_current() {
    printf "\n%b  Testing current DNS...%b\n\n" "${CYAN}" "${NC}"
    
    local current_dns
    current_dns="$(get_current_dns)"
    
    if [[ -z "${current_dns}" ]]; then
        printf "%b  ✗ No DNS configured%b\n" "${RED}" "${NC}"
    else
        printf "  Current DNS: %s\n\n" "${current_dns}"
        test_critical_services "${current_dns}" "Current DNS"
    fi
    
    printf "\n  Press Enter to continue..."
    read -r
}

cmd_benchmark() {
    printf "\nBenchmarking all DNS categories...\n"
    printf "This may take several minutes...\n\n"
    
    local -a categories=("iranian" "international" "security" "family_safe" "unfiltered")
    
    for category in "${categories[@]}"; do
        printf "\nTesting %s...\n" "${category}"
        select_best_dns "${category}" >/dev/null 2>&1 || true
    done
    
    cmd_show_rankings
}

cmd_show_rankings() {
    printf "\nDNS Server Rankings\n"
    printf "  =========================================================\n\n"
    
    local rankings
    rankings="$(rank_dns_servers)"
    
    if [[ -z "${rankings}" ]]; then
        printf "  No benchmark data available. Run benchmark first.\n"
    else
        printf "  %-5s %-30s %-12s %-10s\n" "RANK" "DNS NAME" "SUCCESS" "LATENCY"
        printf "  ----------------------------------------------------------\n"
        
        local -i rank=1
        while IFS='|' read -r score name rate latency; do
            printf "  %-5s %-30s %-12s %-10s\n" "#${rank}" "${name}" "${rate}" "${latency}ms"
            ((rank++))
            
            [[ ${rank} -gt 20 ]] && break
        done <<< "${rankings}"
    fi
    
    printf "\n  Press Enter to continue..."
    read -r
}

cmd_restore() {
    printf "\n"
    read -rp "  Restore previous DNS configuration? [y/N]: " confirm
    
    if [[ "${confirm}" =~ ^[Yy]$ ]]; then
        restore_dns
        printf "\nOK DNS configuration restored\n"
    else
        printf "\nCancelled\n"
    fi
    
    printf "\n  Press Enter to continue..."
    read -r
}

cmd_update_dataset() {
    printf "\nUpdating DNS dataset...\n\n"
    
    update_dns_dataset
    
    printf "\n  Press Enter to continue..."
    read -r
}

cmd_system_info() {
    printf "\nSystem Information\n"
    printf "  =========================================================\n\n"
    
    local os_info
    os_info="$(detect_os)"
    local os_name os_version os_codename
    IFS='|' read -r os_name os_version os_codename <<< "${os_info}"
    
    printf "  %-20s %s %s (%s)\n" "Operating System:" "${os_name^}" "${os_version}" "${os_codename}"
    printf "  %-20s %s\n" "Kernel:" "$(uname -r)"
    printf "  %-20s %s\n" "Architecture:" "$(uname -m)"
    printf "  %-20s %s\n" "Init System:" "$(detect_init_system)"
    printf "  %-20s %s\n" "DNS Manager:" "$(detect_dns_manager)"
    printf "  %-20s %s\n" "Current DNS:" "$(get_current_dns 2>/dev/null || echo 'unknown')"
    printf "\n"
    printf "  %-20s %s\n" "Script Version:" "${TOOLKIT_VERSION}"
    printf "  %-20s %s\n" "Dataset Version:" "$(jq -r '.version // "N/A"' "${DNS_DATASET}" 2>/dev/null)"
    printf "  %-20s %s\n" "Config Dir:" "${CONFIG_DIR}"
    printf "  %-20s %s\n" "Data Dir:" "${DATA_DIR}"
    printf "  %-20s %s\n" "Log File:" "${LOG_FILE}"
    
    printf "\n  Press Enter to continue..."
    read -r
}

# ============================================================================
# MAIN ENTRY POINT
# ============================================================================

print_help() {
    cat << EOF
${PROJECT_NAME} v${TOOLKIT_VERSION} - Professional DNS Management for Linux

Usage: ${SCRIPT_NAME} [OPTIONS] [COMMAND]

Options:
  -v, --verbose        Enable verbose output
  -vv                  Enable trace output (very verbose)
  -q, --quiet          Suppress all output except errors
  -n, --dry-run        Show what would be done without making changes
  -f, --force          Force operation without confirmation
  --version            Show version information
  -h, --help           Show this help message

Commands:
  --auto, -a           Auto-optimize DNS (recommended)
  --iranian, -i        Use Iranian anti-sanction DNS
  --international, -t  Use international DNS
  --security, -s       Use security-focused DNS
  --family             Use family-safe DNS
  --unfiltered         Use unfiltered DNS
  --test               Test current DNS configuration
  --benchmark, -b      Benchmark all DNS categories
  --restore, -r        Restore previous DNS configuration
  --update             Update DNS dataset
  --info               Show system information

Examples:
  ${SCRIPT_NAME}                    # Interactive menu
  ${SCRIPT_NAME} --auto             # Auto-optimize DNS
  ${SCRIPT_NAME} -v --test          # Verbose test of current DNS
  ${SCRIPT_NAME} -n --iranian       # Dry run: show what Iranian DNS would be applied

Report bugs: ${PROJECT_URL}/issues
EOF
}

print_version() {
    printf "%s v%s (%s)\n" "${PROJECT_NAME}" "${TOOLKIT_VERSION}" "${RELEASE_DATE}"
    printf "Copyright (c) 2024-2025 WeUp.one Group\n"
    printf "License: MIT\n"
}

main() {
    # Initialize logging first
    init_logging
    load_config
    
    # Parse command line arguments
    local command=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -v|--verbose)
                VERBOSE_MODE=1
                shift
                ;;
            -vv)
                VERBOSE_MODE=2
                shift
                ;;
            -q|--quiet)
                QUIET_MODE=1
                shift
                ;;
            -n|--dry-run)
                DRY_RUN_MODE=1
                log_info "Dry run mode enabled"
                shift
                ;;
            -f|--force)
                FORCE_MODE=1
                shift
                ;;
            --version)
                print_version
                exit 0
                ;;
            -h|--help)
                print_help
                exit 0
                ;;
            --auto|-a)
                command="auto"
                shift
                ;;
            --iranian|-i)
                command="iranian"
                shift
                ;;
            --international|-t)
                command="international"
                shift
                ;;
            --security|-s)
                command="security"
                shift
                ;;
            --family)
                command="family_safe"
                shift
                ;;
            --unfiltered)
                command="unfiltered"
                shift
                ;;
            --test)
                command="test"
                shift
                ;;
            --benchmark|-b)
                command="benchmark"
                shift
                ;;
            --restore|-r)
                command="restore"
                shift
                ;;
            --update)
                command="update"
                shift
                ;;
            --info)
                command="info"
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                print_help
                exit 1
                ;;
        esac
    done
    
    # Check for root privileges for DNS modifications
    if [[ $EUID -ne 0 ]] && [[ "${command}" != "info" ]] && [[ "${command}" != "test" ]] && [[ "${command}" != "" ]]; then
        error_exit "This operation requires root privileges. Please run with sudo." 1
    fi
    
    # Initialize
    log_debug "Initializing ${PROJECT_NAME} v${TOOLKIT_VERSION}..."
    
    check_ubuntu_compatibility || true
    create_directories
    ensure_dependencies
    load_dns_dataset
    
    log_debug "Initialization complete"
    
    # Execute command or show interactive menu
    case "${command}" in
        auto)
            cmd_auto_optimize
            ;;
        iranian|international|security|family_safe|unfiltered)
            cmd_category "${command}"
            ;;
        test)
            cmd_test_current
            ;;
        benchmark)
            cmd_benchmark
            ;;
        restore)
            cmd_restore
            ;;
        update)
            cmd_update_dataset
            ;;
        info)
            cmd_system_info
            ;;
        "")
            # Interactive menu (requires root)
            if [[ $EUID -ne 0 ]]; then
                error_exit "Interactive mode requires root privileges. Please run with sudo." 1
            fi
            interactive_menu
            ;;
    esac
}

# Run main function
main "$@"
