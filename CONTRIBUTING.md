# Contributing to SSH Profile Switcher (sshps)

Thank you for considering contributing to sshps! We welcome all contributions that help improve this tool for managing SSH profiles.

## How to Contribute

### Reporting Issues
- Check existing issues to avoid duplicates
- Provide detailed information:
  - OS and version
  - Steps to reproduce
  - Expected vs actual behavior
  - Relevant error messages

### Feature Requests
- Describe the use case clearly
- Explain why this would benefit most users
- Suggest implementation if possible

### Code Contributions
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/your-feature`)
3. Commit your changes with clear messages
4. Push to your branch (`git push origin feature/your-feature`)
5. Open a Pull Request

## Development Guidelines

### Code Style
- Follow existing style (4-space indentation, snake_case variables)
- Include comments for complex logic
- Keep functions focused and modular

### Testing
- Test changes manually with:
  - Different SSH configurations
  - Various key types (RSA, ED25519)
  - Edge cases (empty configs, missing files)

### Documentation
- Update README.md for new features
- Add comments for non-obvious code
- Keep help text (`show_help` function) current

## Security Considerations

When working with SSH-related code:
- Never log sensitive information (keys, passphrases)
- Maintain strict file permissions (600 for keys/configs)
- Validate all file operations
- Handle errors gracefully without exposing system details

## Pull Request Process

1. Ensure all tests pass
2. Update documentation if needed
3. Keep PRs focused - one feature/bugfix per PR
4. PRs will be reviewed within 3-5 days

## Community

For questions or discussions:
- Open a GitHub Discussion
- Join our [community chat] (link to be added)

We appreciate your contributions to making sshps better!