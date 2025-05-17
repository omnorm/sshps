# SSH Profile Switcher (sshps)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
![Platform: Linux/macOS](https://img.shields.io/badge/Platform-Linux%20%7C%20macOS-lightgrey)

## 🚀 The Problem This Solves

Working with multiple SSH environments (work, personal, cloud, etc.) leads to:
- **Config chaos**: Manual editing of `~/.ssh/config` for different contexts
- **Cross-contamination**: Accidentally using production keys for personal servers
- **known_hosts conflicts**: Mixed host keys causing connection warnings
- **Key management headaches**: Remembering which identity files belong to which environment

**sshps solves this by**:
- Providing isolated profile environments
- Automating config/key/known_hosts switching
- Preventing accidental credential leaks between environments

## Features
- 🔄 One-command profile switching
- 🔐 Per-profile SSH keys and configurations
- 🏷 Dedicated `known_hosts` for each environment
- 🤖 Auto key loading to ssh-agent
- 🛠 Automatic permission fixes (chmod 600)

## Installation
```bash
curl -o sshps https://raw.githubusercontent.com/YOUR-USERNAME/sshps/main/sshps.sh && \
chmod +x sshps && \
sudo mv sshps /usr/local/bin/
```

## Usage
```
  sshps sw <profile>      Switch to specified profile
  sshps list             List available profiles
  sshps add <name>       Create empty profile (interactive)
  sshps add <name> -u <login> [-i <keyfile>] [-t <type>] [-s <size>] [-p]  Create profile with options
  sshps bak <name>       Create profile from current ~/.ssh/config
  sshps del <name>       Delete profile
  sshps edit <name>      Edit profile config
  sshps -h|--help        Show this help message
  sshps                  Interactive profile selection
```


## Basic Usage
```bash
# Create and switch to work profile:
sshps add work -u yourname -t ed25519
sshps sw work

# List all profiles:
sshps list
```

## Advanced Features
```bash
# Backup current SSH config as profile:
sshps bak legacy-config

# Secure profile with passphrase:
sshps add production -p

# Edit profile config:
sshps edit work
```

## Requirements
- Bash 4.0+
- OpenSSH
- Standard Unix tools

## Changelog

See [CHANGELOG.md](CHANGELOG.md)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md)

## License
MIT © [Permishen Denaev] - See [LICENSE](LICENSE)
