# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- TODO

## [1.0.0] - Initial Release - 2025-05-17

### Added
- Core functionality for managing isolated SSH profiles:
  - Profile switching (`sshps sw <profile>`)
  - Interactive profile selection menu
  - Profile listing (`sshps list`)
- Profile management commands:
  - Create new profiles (`sshps add`)
  - Backup current config as profile (`sshps bak`)
  - Delete profiles (`sshps del`)
  - Edit profiles (`sshps edit`)
- SSH key management:
  - Key generation (RSA, ED25519, ECDSA, DSA)
  - Automatic key loading to ssh-agent
  - Passphrase support for keys
- Security features:
  - Automatic permission fixing (chmod 600)
  - Separate known_hosts files per profile
  - Config validation before switching
- Comprehensive help system (`sshps -h`)

### Technical Details
- Written in Bash (4.0+ compatible)
- Supports Linux and macOS
- Requires standard Unix tools and OpenSSH