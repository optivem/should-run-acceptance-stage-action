# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.x.x   | :white_check_mark: |

## Reporting a Vulnerability

We take security vulnerabilities seriously. If you discover a security vulnerability, please follow these steps:

### Private Disclosure

1. **DO NOT** create a public GitHub issue for security vulnerabilities
2. Send an email to [security@optivem.com](mailto:security@optivem.com) with:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Any suggested fixes

### What to Expect

- **Acknowledgment**: We'll acknowledge receipt within 48 hours
- **Assessment**: We'll assess the vulnerability within 5 business days
- **Updates**: We'll provide regular updates on our progress
- **Resolution**: We'll work to resolve critical issues as quickly as possible

### Disclosure Timeline

- We aim to resolve critical vulnerabilities within 90 days
- We'll coordinate with you on public disclosure timing
- You'll be credited in the security advisory (if desired)

## Security Considerations

This action:
- Uses GitHub's authenticated API
- Processes repository and package information
- Does not store sensitive data
- Runs in GitHub's secure runner environment

### Safe Usage

- Always use the latest version
- Review inputs to ensure they don't contain sensitive data
- Use repository secrets for any credentials
- Monitor GitHub Security Advisories

## Responsible Disclosure

We appreciate security researchers who:
- Give us reasonable time to fix issues
- Don't exploit vulnerabilities for malicious purposes
- Don't access or modify user data without permission
- Follow coordinated disclosure practices

Thank you for helping keep our action and users safe!