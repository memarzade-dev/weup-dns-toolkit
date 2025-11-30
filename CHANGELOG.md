# Changelog

All notable changes to WeUp DNS Toolkit will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2025-01-15

### Added

- Complete rewrite with production-ready architecture
- Iranian anti-sanction DNS support (Shecan, Begzar, Electro, 403.online)
- 156 DNS providers across 6 categories
- Comprehensive DNS dataset with metadata
- systemd service and timer for automatic optimization
- Thread-safe logging with flock
- Atomic file operations for DNS configuration
- Input validation for IP addresses and domains
- Path traversal protection
- Automatic backup with rotation
- DNS cache flushing (systemd-resolved, nscd, dnsmasq)
- NetworkManager integration
- netplan compatibility detection
- Bash completion support
- Comprehensive test suite
- CI/CD pipeline with GitHub Actions
- Professional installation script
- Uninstallation script
- Configuration file with all options

### Changed

- Improved DNS testing algorithm with parallel execution
- Enhanced ranking system with latency bonuses
- Better error handling throughout
- Cleaner command-line interface
- More informative interactive menu
- Updated DNS dataset with latest provider information

### Security

- Fixed command injection vulnerabilities
- Added input sanitization
- Implemented atomic writes to prevent race conditions
- Added JSON validation before parsing
- Path validation for all file operations

### Fixed

- DNS cache not being flushed after changes
- Race conditions in parallel DNS tests
- Integer overflow in latency calculations
- Missing error handling in background jobs
- Inefficient array operations

## [1.1.0] - 2024-12-01

### Added

- Security hardening pass
- DoH/DoT protocol detection
- IPv6 DNS support
- Backup rotation (keeps last 10)
- Smart fallback to international DNS

### Changed

- Reduced parallel workers from 10 to 8 for stability
- Improved jq query efficiency
- Better systemd-resolved detection

### Fixed

- Command injection in test_dns function
- Path traversal in backup operations
- Unvalidated JSON parsing

## [1.0.0] - 2024-10-15

### Added

- Initial release
- Basic DNS management functionality
- Interactive menu
- Iranian DNS support
- International DNS providers
- DNS testing and benchmarking
- Basic backup/restore
- Ubuntu support (20.04, 22.04)

---

## Release Notes

### Upgrading from 1.x to 2.0

**Breaking Changes:**
- Configuration file format changed
- Log file location changed to `/var/log/weup-dns-toolkit.log`
- Data directory moved to `/var/lib/weup-dns-toolkit/`

**Migration Steps:**
1. Backup existing configuration
2. Run new installer: `sudo ./install.sh`
3. Review and update `/etc/weup-dns-toolkit/config.conf`
4. Enable systemd timer if desired

### Known Issues

- Some Iranian DNS services (10.x.x.x range) only work on Iranian ISP networks
- DoQ (DNS over QUIC) support is limited to providers that offer it
- IPv6-only networks may have limited provider options

### Compatibility Notes

- Ubuntu 18.04: Requires manual systemd-resolved configuration
- Ubuntu 24.04: Full native support
- WSL2: Limited functionality due to network stack differences
