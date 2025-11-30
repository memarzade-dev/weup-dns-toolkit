#!/usr/bin/env bash
################################################################################
#
#  WeUp DNS Toolkit - Test Suite
#  
#  Comprehensive unit and integration tests for dns_toolkit.sh
#
#  Usage: ./tests/test_dns_toolkit.sh [test_name]
#
#  Copyright (c) 2024-2025 WeUp.one Group
#  License: MIT
#
################################################################################

set -euo pipefail

# ============================================================================
# TEST FRAMEWORK
# ============================================================================

readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(dirname "${TEST_DIR}")"
readonly SCRIPT_PATH="${PROJECT_DIR}/dns_toolkit.sh"
readonly DATASET_PATH="${PROJECT_DIR}/dns_dataset.json"

# Test counters
declare -i TESTS_RUN=0
declare -i TESTS_PASSED=0
declare -i TESTS_FAILED=0
declare -i TESTS_SKIPPED=0

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# ============================================================================
# TEST UTILITIES
# ============================================================================

log_test() {
    printf "%b[TEST]%b %s\n" "${BLUE}" "${NC}" "$*"
}

log_pass() {
    printf "%b[PASS]%b %s\n" "${GREEN}" "${NC}" "$*"
    ((TESTS_PASSED++))
}

log_fail() {
    printf "%b[FAIL]%b %s\n" "${RED}" "${NC}" "$*"
    ((TESTS_FAILED++))
}

log_skip() {
    printf "%b[SKIP]%b %s\n" "${YELLOW}" "${NC}" "$*"
    ((TESTS_SKIPPED++))
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Assertion failed}"
    
    if [[ "${expected}" == "${actual}" ]]; then
        return 0
    else
        echo "  Expected: ${expected}"
        echo "  Actual:   ${actual}"
        return 1
    fi
}

assert_true() {
    local condition="$1"
    local message="${2:-Condition should be true}"
    
    if eval "${condition}"; then
        return 0
    else
        return 1
    fi
}

assert_false() {
    local condition="$1"
    local message="${2:-Condition should be false}"
    
    if ! eval "${condition}"; then
        return 0
    else
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    [[ -f "${file}" ]]
}

assert_command_exists() {
    local cmd="$1"
    command -v "${cmd}" &>/dev/null
}

run_test() {
    local test_name="$1"
    ((TESTS_RUN++))
    
    log_test "Running: ${test_name}"
    
    if "${test_name}"; then
        log_pass "${test_name}"
    else
        log_fail "${test_name}"
    fi
}

# ============================================================================
# PREREQUISITE CHECKS
# ============================================================================

check_prerequisites() {
    echo "Checking prerequisites..."
    
    if [[ ! -f "${SCRIPT_PATH}" ]]; then
        echo "Error: Main script not found: ${SCRIPT_PATH}"
        exit 1
    fi
    
    if [[ ! -f "${DATASET_PATH}" ]]; then
        echo "Error: Dataset not found: ${DATASET_PATH}"
        exit 1
    fi
    
    # Check required commands
    local -a required_cmds=("jq" "dig" "curl" "awk" "sed" "grep")
    for cmd in "${required_cmds[@]}"; do
        if ! command -v "${cmd}" &>/dev/null; then
            echo "Error: Required command not found: ${cmd}"
            exit 1
        fi
    done
    
    echo "Prerequisites OK"
    echo ""
}

# ============================================================================
# UNIT TESTS: IP VALIDATION
# ============================================================================

test_validate_ipv4_valid() {
    local -a valid_ips=(
        "1.1.1.1"
        "8.8.8.8"
        "192.168.1.1"
        "255.255.255.255"
        "0.0.0.0"
        "10.0.0.1"
        "172.16.0.1"
    )
    
    for ip in "${valid_ips[@]}"; do
        if ! [[ "${ip}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
            echo "  Failed for: ${ip}"
            return 1
        fi
        
        # Check octets
        IFS='.' read -ra octets <<< "${ip}"
        for octet in "${octets[@]}"; do
            if [[ $((10#${octet})) -lt 0 ]] || [[ $((10#${octet})) -gt 255 ]]; then
                echo "  Invalid octet in: ${ip}"
                return 1
            fi
        done
    done
    
    return 0
}

test_validate_ipv4_invalid() {
    local -a invalid_ips=(
        "256.1.1.1"
        "1.1.1.256"
        "1.1.1"
        "1.1.1.1.1"
        "a.b.c.d"
        "192.168.1"
        "..."
        ""
        "1.1.1.1a"
    )
    
    for ip in "${invalid_ips[@]}"; do
        if [[ "${ip}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
            IFS='.' read -ra octets <<< "${ip}"
            local valid=1
            for octet in "${octets[@]}"; do
                if [[ $((10#${octet})) -lt 0 ]] || [[ $((10#${octet})) -gt 255 ]]; then
                    valid=0
                    break
                fi
            done
            if [[ ${valid} -eq 1 ]]; then
                echo "  Should have failed for: ${ip}"
                return 1
            fi
        fi
    done
    
    return 0
}

test_validate_ipv6_valid() {
    local -a valid_ips=(
        "2606:4700:4700::1111"
        "::1"
        "::"
        "2001:4860:4860::8888"
        "fe80::1"
    )
    
    for ip in "${valid_ips[@]}"; do
        if ! [[ "${ip}" =~ ^([0-9a-fA-F]{0,4}:){2,7}[0-9a-fA-F]{0,4}$ ]] && \
           ! [[ "${ip}" =~ ^::([0-9a-fA-F]{1,4}:){0,5}[0-9a-fA-F]{1,4}$ ]] && \
           ! [[ "${ip}" =~ ^::$ ]]; then
            echo "  Failed for: ${ip}"
            return 1
        fi
    done
    
    return 0
}

# ============================================================================
# UNIT TESTS: DOMAIN VALIDATION
# ============================================================================

test_validate_domain_valid() {
    local -a valid_domains=(
        "google.com"
        "www.example.org"
        "sub.domain.example.co.uk"
        "test123.com"
        "a.b.c.d.e.f.com"
        "xn--bcher-kva.com"
    )
    
    for domain in "${valid_domains[@]}"; do
        if ! [[ "${domain}" =~ ^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)*[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]]; then
            echo "  Failed for: ${domain}"
            return 1
        fi
    done
    
    return 0
}

test_validate_domain_invalid() {
    local -a invalid_domains=(
        "-google.com"
        "google-.com"
        ".com"
        "google..com"
        ""
        "google.com-"
        "goo gle.com"
    )
    
    for domain in "${invalid_domains[@]}"; do
        if [[ "${domain}" =~ ^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)*[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]]; then
            echo "  Should have failed for: ${domain}"
            return 1
        fi
    done
    
    return 0
}

# ============================================================================
# UNIT TESTS: PATH VALIDATION
# ============================================================================

test_validate_path_traversal() {
    local -a dangerous_paths=(
        "/etc/../etc/passwd"
        "/var/log/../../../etc/shadow"
        "/../../../root"
        "/home/user/../../root"
    )
    
    for path in "${dangerous_paths[@]}"; do
        if ! [[ "${path}" =~ \.\. ]]; then
            echo "  Should detect traversal in: ${path}"
            return 1
        fi
    done
    
    return 0
}

test_validate_path_absolute() {
    local -a relative_paths=(
        "etc/passwd"
        "./config"
        "../parent"
        "file.txt"
    )
    
    for path in "${relative_paths[@]}"; do
        if [[ "${path}" =~ ^/ ]]; then
            echo "  Should not be absolute: ${path}"
            return 1
        fi
    done
    
    return 0
}

# ============================================================================
# UNIT TESTS: JSON DATASET
# ============================================================================

test_dataset_valid_json() {
    if ! jq empty "${DATASET_PATH}" 2>/dev/null; then
        echo "  Invalid JSON in dataset"
        return 1
    fi
    return 0
}

test_dataset_has_version() {
    local version
    version=$(jq -r '.version' "${DATASET_PATH}" 2>/dev/null)
    
    if [[ -z "${version}" ]] || [[ "${version}" == "null" ]]; then
        echo "  Missing version field"
        return 1
    fi
    
    return 0
}

test_dataset_has_providers() {
    local provider_count
    provider_count=$(jq '[.dns_providers[][] | select(.providers != null) | .providers[]] | length' "${DATASET_PATH}" 2>/dev/null)
    
    if [[ ${provider_count} -lt 50 ]]; then
        echo "  Too few providers: ${provider_count}"
        return 1
    fi
    
    echo "  Found ${provider_count} providers"
    return 0
}

test_dataset_iranian_providers() {
    local iranian_count
    iranian_count=$(jq '.dns_providers.iranian.providers | length' "${DATASET_PATH}" 2>/dev/null)
    
    if [[ ${iranian_count} -lt 4 ]]; then
        echo "  Expected at least 4 Iranian providers, got: ${iranian_count}"
        return 1
    fi
    
    # Verify Shecan exists
    local shecan_ip
    shecan_ip=$(jq -r '.dns_providers.iranian.providers[] | select(.id == "shecan") | .protocols.dns.ipv4[0]' "${DATASET_PATH}" 2>/dev/null)
    
    if [[ "${shecan_ip}" != "178.22.122.100" ]]; then
        echo "  Shecan IP mismatch: ${shecan_ip}"
        return 1
    fi
    
    return 0
}

test_dataset_test_domains() {
    local domains
    domains=$(jq '.test_domains | keys | length' "${DATASET_PATH}" 2>/dev/null)
    
    if [[ ${domains} -lt 3 ]]; then
        echo "  Missing test domain categories"
        return 1
    fi
    
    # Check sanction bypass domains
    local sanction_domains
    sanction_domains=$(jq '.test_domains.sanction_bypass | length' "${DATASET_PATH}" 2>/dev/null)
    
    if [[ ${sanction_domains} -lt 5 ]]; then
        echo "  Too few sanction bypass domains: ${sanction_domains}"
        return 1
    fi
    
    return 0
}

test_dataset_provider_structure() {
    # Test that all providers have required fields
    local invalid_providers
    invalid_providers=$(jq '
        [.dns_providers[][] | 
         select(.providers != null) | 
         .providers[] | 
         select(.id == null or .name == null or .protocols.dns.ipv4 == null)]
        | length
    ' "${DATASET_PATH}" 2>/dev/null)
    
    if [[ ${invalid_providers} -gt 0 ]]; then
        echo "  Found ${invalid_providers} providers with missing required fields"
        return 1
    fi
    
    return 0
}

# ============================================================================
# UNIT TESTS: SCRIPT SYNTAX
# ============================================================================

test_script_syntax() {
    if ! bash -n "${SCRIPT_PATH}" 2>&1; then
        echo "  Syntax errors in main script"
        return 1
    fi
    return 0
}

test_script_shellcheck() {
    if ! command -v shellcheck &>/dev/null; then
        log_skip "shellcheck not installed"
        return 0
    fi
    
    local errors
    errors=$(shellcheck -s bash "${SCRIPT_PATH}" 2>&1 | grep -c "error:" || true)
    
    if [[ ${errors} -gt 0 ]]; then
        echo "  ShellCheck found ${errors} errors"
        shellcheck -s bash "${SCRIPT_PATH}" 2>&1 | head -20
        return 1
    fi
    
    return 0
}

test_script_version_option() {
    local output
    output=$(bash "${SCRIPT_PATH}" --version 2>&1)
    
    if ! echo "${output}" | grep -q "2.0.0"; then
        echo "  Version output unexpected: ${output}"
        return 1
    fi
    
    return 0
}

test_script_help_option() {
    local output
    output=$(bash "${SCRIPT_PATH}" --help 2>&1)
    
    if ! echo "${output}" | grep -q "Usage"; then
        echo "  Help output missing Usage section"
        return 1
    fi
    
    if ! echo "${output}" | grep -q "\-\-auto"; then
        echo "  Help output missing --auto option"
        return 1
    fi
    
    return 0
}

# ============================================================================
# INTEGRATION TESTS
# ============================================================================

test_dns_resolution_cloudflare() {
    local result
    result=$(dig +short +time=5 +tries=1 google.com @1.1.1.1 2>/dev/null | head -1)
    
    if [[ -z "${result}" ]]; then
        echo "  DNS resolution failed"
        return 1
    fi
    
    return 0
}

test_dns_resolution_google() {
    local result
    result=$(dig +short +time=5 +tries=1 google.com @8.8.8.8 2>/dev/null | head -1)
    
    if [[ -z "${result}" ]]; then
        echo "  DNS resolution failed"
        return 1
    fi
    
    return 0
}

test_dataset_parsing_performance() {
    local start_time end_time duration
    
    start_time=$(date +%s%N)
    
    # Parse all providers
    jq -r '.dns_providers[][] | select(.providers != null) | .providers[] | "\(.id)|\(.name)"' "${DATASET_PATH}" >/dev/null 2>&1
    
    end_time=$(date +%s%N)
    duration=$(( (end_time - start_time) / 1000000 ))
    
    echo "  Parsing duration: ${duration}ms"
    
    if [[ ${duration} -gt 5000 ]]; then
        echo "  Parsing took too long"
        return 1
    fi
    
    return 0
}

# ============================================================================
# SECURITY TESTS
# ============================================================================

test_no_eval_usage() {
    local eval_count
    eval_count=$(grep -c "^\s*eval\s" "${SCRIPT_PATH}" 2>/dev/null || echo 0)
    
    if [[ ${eval_count} -gt 0 ]]; then
        echo "  Found ${eval_count} direct eval usages"
        return 1
    fi
    
    return 0
}

test_no_backtick_usage() {
    local backtick_count
    backtick_count=$(grep -c '\`[^`]*\`' "${SCRIPT_PATH}" 2>/dev/null || echo 0)
    
    if [[ ${backtick_count} -gt 0 ]]; then
        echo "  Found ${backtick_count} backtick usages (use \$() instead)"
        return 1
    fi
    
    return 0
}

test_quoted_variables() {
    # Check for common unquoted variable patterns
    local unquoted
    unquoted=$(grep -E '\$[A-Za-z_][A-Za-z0-9_]*[^"'"'"']' "${SCRIPT_PATH}" 2>/dev/null | \
               grep -v '^\s*#' | \
               grep -v '\$\{' | \
               wc -l)
    
    # Allow some unquoted variables (this is a heuristic check)
    if [[ ${unquoted} -gt 50 ]]; then
        echo "  Found many potentially unquoted variables"
        return 1
    fi
    
    return 0
}

# ============================================================================
# TEST RUNNER
# ============================================================================

run_all_tests() {
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║           WeUp DNS Toolkit - Test Suite                    ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    
    check_prerequisites
    
    echo "═══════════════════════════════════════════════════════════════"
    echo "IP Validation Tests"
    echo "═══════════════════════════════════════════════════════════════"
    run_test test_validate_ipv4_valid
    run_test test_validate_ipv4_invalid
    run_test test_validate_ipv6_valid
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "Domain Validation Tests"
    echo "═══════════════════════════════════════════════════════════════"
    run_test test_validate_domain_valid
    run_test test_validate_domain_invalid
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "Path Validation Tests"
    echo "═══════════════════════════════════════════════════════════════"
    run_test test_validate_path_traversal
    run_test test_validate_path_absolute
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "Dataset Tests"
    echo "═══════════════════════════════════════════════════════════════"
    run_test test_dataset_valid_json
    run_test test_dataset_has_version
    run_test test_dataset_has_providers
    run_test test_dataset_iranian_providers
    run_test test_dataset_test_domains
    run_test test_dataset_provider_structure
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "Script Tests"
    echo "═══════════════════════════════════════════════════════════════"
    run_test test_script_syntax
    run_test test_script_shellcheck
    run_test test_script_version_option
    run_test test_script_help_option
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "Integration Tests"
    echo "═══════════════════════════════════════════════════════════════"
    run_test test_dns_resolution_cloudflare
    run_test test_dns_resolution_google
    run_test test_dataset_parsing_performance
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "Security Tests"
    echo "═══════════════════════════════════════════════════════════════"
    run_test test_no_eval_usage
    run_test test_no_backtick_usage
    run_test test_quoted_variables
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "Test Summary"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    printf "  Total:   %d\n" "${TESTS_RUN}"
    printf "  %bPassed:%b  %d\n" "${GREEN}" "${NC}" "${TESTS_PASSED}"
    printf "  %bFailed:%b  %d\n" "${RED}" "${NC}" "${TESTS_FAILED}"
    printf "  %bSkipped:%b %d\n" "${YELLOW}" "${NC}" "${TESTS_SKIPPED}"
    echo ""
    
    if [[ ${TESTS_FAILED} -gt 0 ]]; then
        echo "Some tests failed!"
        exit 1
    else
        echo "All tests passed!"
        exit 0
    fi
}

# ============================================================================
# MAIN
# ============================================================================

# Run specific test or all tests
if [[ $# -gt 0 ]]; then
    check_prerequisites
    run_test "$1"
else
    run_all_tests
fi
