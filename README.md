# WeUp DNS Toolkit

[![Version](https://img.shields.io/badge/version-2.0.0-blue.svg)](https://github.com/memarzade-dev/weup-dns-toolkit)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Ubuntu](https://img.shields.io/badge/ubuntu-18.04%20|%2020.04%20|%2022.04%20|%2024.04-orange.svg)](https://ubuntu.com)
[![Bash](https://img.shields.io/badge/bash-5.0+-brightgreen.svg)](https://www.gnu.org/software/bash/)

**Professional DNS Management System for Linux**

WeUp DNS Toolkit is a production-ready DNS management solution designed for Ubuntu Linux systems. It provides automatic DNS optimization, Iranian anti-sanction DNS support, and comprehensive DNS testing capabilities.

## Features

- **Auto-Optimization**: Automatically finds and applies the fastest DNS server
- **Anti-Sanction DNS**: Iranian DNS services for bypassing international sanctions
- **Multiple Categories**: International, Security, Family-Safe, and Unfiltered DNS
- **Protocol Support**: DNS, DoH (DNS over HTTPS), DoT (DNS over TLS), DoQ (DNS over QUIC)
- **systemd Integration**: Native systemd service and timer support
- **Atomic Operations**: Safe DNS configuration changes with automatic backup
- **Thread-Safe Logging**: Concurrent-safe logging for all operations
- **Comprehensive Testing**: Latency, success rate, and critical services testing

## System Overview

- Single-file core: `dns_toolkit.sh` provides CLI, interactive menu, testing, ranking, and application logic
- Dataset-driven: `dns_dataset.json` lists providers, protocols, and test domains
- Configuration: `/etc/weup-dns-toolkit/config.conf` controls behavior and thresholds
- OS integration: Applies DNS via `systemd-resolved`, `NetworkManager`, or direct `resolv.conf`, then flushes caches
- Automation: systemd `service` and `timer` enable periodic optimization
- Safety: atomic writes, backups, and validation to prevent misconfiguration

## Quick Start

### Installation

```bash
# Clone the repository
git clone https://github.com/memarzade-dev/weup-dns-toolkit.git
cd weup-dns-toolkit

# Install (requires root)
sudo ./install.sh
```

Alternatively, run explicitly with Bash if the file is not executable:

```bash
sudo bash install.sh
```

### Basic Usage

```bash
# Interactive menu
sudo weup-dns

# Auto-optimize DNS (recommended)
sudo weup-dns --auto

# Use Iranian anti-sanction DNS
sudo weup-dns --iranian

# Test current DNS configuration
sudo weup-dns --test
```

## Requirements

### Supported Operating Systems

| Ubuntu Version | Status | Notes |
|----------------|--------|-------|
| 24.04 LTS | ✅ Fully Supported | Recommended |
| 22.04 LTS | ✅ Fully Supported | |
| 20.04 LTS | ✅ Fully Supported | |
| 18.04 LTS | ✅ Supported | Legacy |

### Dependencies

All dependencies are automatically installed during setup:

- `jq` - JSON processing
- `curl` - HTTP requests
- `dnsutils` - DNS testing (dig, host)
- `coreutils` - Core utilities
- `gawk` - Text processing
- `util-linux` - System utilities (flock)

## Usage

### Command Line Options

```
weup-dns [OPTIONS] [COMMAND]

Options:
  -v, --verbose        Enable verbose output
  -vv                  Enable trace output (very verbose)
  -q, --quiet          Suppress all output except errors
  -n, --dry-run        Show what would be done without making changes
  -f, --force          Force operation without confirmation
  --version            Show version information
  -h, --help           Show help message

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
```

### How It Works

- Detects the DNS manager and system capabilities
- Benchmarks selected providers using `dig` with timeouts against diverse domains
- Computes success rate and average latency, ranks candidates, and applies the best
- Creates a backup prior to changes and flushes caches for consistency
- Persists the applied DNS for visibility and potential restoration

### Examples

```bash
# Auto-optimize with verbose output
sudo weup-dns -v --auto

# Dry run to see what would happen
sudo weup-dns -n --iranian

# Benchmark all DNS categories
sudo weup-dns --benchmark

# Restore previous DNS configuration
sudo weup-dns --restore

# Update DNS dataset to latest version
sudo weup-dns --update
```

## DNS Categories

### Iranian (Anti-Sanction)

Optimized for bypassing international sanctions on services like Docker, GitHub, Google AI, etc.

| Provider | Primary IP | Secondary IP | Features |
|----------|------------|--------------|----------|
| Shecan | 178.22.122.100 | 185.51.200.2 | Comprehensive bypass |
| Begzar | 185.55.226.26 | 185.55.225.25 | Privacy-focused |
| Electro | 78.157.42.100 | 78.157.42.101 | Gaming optimized |
| 403.online | 10.202.10.202 | 10.202.10.102 | 403 error bypass |

### International

Global DNS providers with high reliability:

| Provider | Primary IP | Features |
|----------|------------|----------|
| Cloudflare | 1.1.1.1 | Fastest, Privacy |
| Google | 8.8.8.8 | Reliable, DNSSEC |
| Quad9 | 9.9.9.9 | Security, Privacy |
| AdGuard | 94.140.14.14 | Ad-blocking |

### Security

Malware and phishing protection:

| Provider | Primary IP | Protection |
|----------|------------|------------|
| Cloudflare Security | 1.1.1.2 | Malware blocking |
| Quad9 | 9.9.9.9 | Threat intelligence |
| OpenDNS | 208.67.222.222 | Phishing protection |
| CleanBrowsing | 185.228.168.9 | Security filter |

### Family Safe

Adult content blocking:

| Provider | Primary IP | Features |
|----------|------------|----------|
| Cloudflare Family | 1.1.1.3 | Malware + Adult |
| OpenDNS FamilyShield | 208.67.222.123 | Pre-configured |
| CleanBrowsing Family | 185.228.168.168 | Strictest filter |
| AdGuard Family | 94.140.14.15 | Safe search |

## Configuration

Configuration file: `/etc/weup-dns-toolkit/config.conf`

### Key Settings

```bash
# Preferred DNS category for auto-optimization
PREFERRED_CATEGORY="iranian"

# DNS testing timeout (seconds)
DNS_TEST_TIMEOUT=5

# Minimum success rate threshold
MIN_SUCCESS_RATE=0.60

# Enable automatic backup
AUTO_BACKUP=true

# Fallback DNS servers
FALLBACK_DNS="1.1.1.1 8.8.8.8"
```

You can also override some paths and settings via environment variables at runtime:

```bash
# Example: write logs to a custom location for this run
LOG_FILE=/tmp/weup-dns.log weup-dns --auto
```

## Automatic Optimization

Enable periodic DNS optimization using systemd:

```bash
# Enable and start the timer
sudo systemctl enable --now weup-dns-toolkit.timer

# Check timer status
sudo systemctl status weup-dns-toolkit.timer

# View optimization logs
sudo journalctl -u weup-dns-toolkit.service
```

The timer runs every 6 hours by default, with a 5-minute random delay to prevent thundering herd.

### System Integration Details

- `systemd-resolved`: creates a managed configuration and restarts the resolver
- `NetworkManager`: updates the active connection DNS and prevents auto DNS overrides
- Fallback: writes `nameserver` entries to `/etc/resolv.conf` directly if the above are unavailable
- Cache flushing: uses `resolvectl` or service restart depending on detected components

## File Locations

| Path | Description |
|------|-------------|
| `/opt/weup-dns-toolkit/` | Installation directory |
| `/etc/weup-dns-toolkit/` | Configuration directory |
| `/var/lib/weup-dns-toolkit/` | Data directory |
| `/var/backups/weup-dns-toolkit/` | DNS backup files |
| `/var/log/weup-dns-toolkit.log` | Log file |
| `/usr/local/bin/weup-dns` | Symlink to main script |

## Dataset Management

- The toolkit can update the dataset from an upstream URL:

```bash
weup-dns --update
```

- You may add custom DNS entries in `config.conf` using the `CUSTOM_DNS` setting when needed.

## Uninstallation

Use the generated uninstaller to remove installed files and services:

```bash
sudo /opt/weup-dns-toolkit/uninstall.sh
```

Alternatively, from the cloned repository root:

```bash
sudo ./uninstall.sh
```

To completely purge preserved configuration and backups, follow the prompts or manually remove:

```bash
sudo rm -rf /etc/weup-dns-toolkit /var/backups/weup-dns-toolkit
```

## Troubleshooting

### DNS Changes Not Applied

```bash
# Check current DNS manager
weup-dns --info

# Manually flush DNS cache
sudo resolvectl flush-caches

# Restart systemd-resolved
sudo systemctl restart systemd-resolved
```

### Permission Denied

The toolkit requires root privileges for DNS modifications:

```bash
sudo weup-dns --auto
```

### No Working DNS Found

1. Check network connectivity:
   ```bash
   ping -c 3 1.1.1.1
   ```

2. Try verbose mode:
   ```bash
   sudo weup-dns -vv --auto
   ```

3. Restore default DNS:
   ```bash
   sudo weup-dns --restore
   ```

### Sanction Bypass Not Working

1. Verify DNS is applied:
   ```bash
   cat /etc/resolv.conf
   ```

2. Test specific service:
   ```bash
   dig docker.io @178.22.122.100
   ```

3. Check if using Iranian ISP (required for some DNS services)

### Common Installation Issues

- `sudo: ./install.sh: command not found`
  - Ensure the file is executable: `chmod +x install.sh` or run `sudo bash install.sh`
- Line ending issues (Windows clones)
  - Convert to Unix line endings: `dos2unix *.sh`, or set `git config core.autocrlf false` before cloning
- OS detection warnings
  - The toolkit is designed for Ubuntu LTS; on other distros it falls back to safe operations and may prompt

## Development

### Running Tests

```bash
# Run test suite
./tests/test_dns_toolkit.sh

# Run specific test
./tests/test_dns_toolkit.sh test_validate_ip
```

### Building from Source

```bash
# Clone repository
git clone https://github.com/memarzade-dev/weup-dns-toolkit.git
cd weup-dns-toolkit

# Validate JSON dataset
jq empty dns_dataset.json

# Check bash syntax
bash -n dns_toolkit.sh

# Run shellcheck
shellcheck dns_toolkit.sh install.sh
```

### Architecture

- Core script: `dns_toolkit.sh` (CLI, menu, testing, ranking, application)
- Installer: `install.sh` (dependencies, directories, systemd units, bash completion)
- Uninstaller: `uninstall.sh` (clean removal with optional purge)
- Dataset: `dns_dataset.json` (providers, protocols, performance hints)
- Config: `config.conf` (behavior tuning)

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Commit changes: `git commit -am 'Add new feature'`
4. Push to branch: `git push origin feature/my-feature`
5. Submit a Pull Request

### Code Style

- Follow [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- Use `shellcheck` for linting
- Maintain 100% function documentation
- Write tests for new features

## Security

### Reporting Vulnerabilities

Please report security vulnerabilities to: security@weup.one

Do not create public issues for security vulnerabilities.

### Security Features

- Input validation for all user inputs
- Path traversal protection
- Atomic file operations
- Backup before modifications
- No external code execution

### Compliance Notes

- Designed for Ubuntu LTS releases with regular security maintenance
- Works alongside Ubuntu security services; enabling ESM Apps is optional for broader package coverage

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.

## License

This project is licensed under the MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

- [AdGuard DNS](https://adguard-dns.io) - DNS provider list inspiration
- [Shecan](https://shecan.ir) - Iranian anti-sanction DNS
- [Cloudflare](https://1.1.1.1) - Fast and secure DNS

## Support

- **Documentation**: [https://github.com/memarzade-dev/weup-dns-toolkit/wiki](https://github.com/memarzade-dev/weup-dns-toolkit/wiki)
- **Issues**: [https://github.com/memarzade-dev/weup-dns-toolkit/issues](https://github.com/memarzade-dev/weup-dns-toolkit/issues)
- **Email**: support@weup.one

---

**Made with love by [WeUp.one Group](https://weup.one)**
