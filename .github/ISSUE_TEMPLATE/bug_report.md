---
name: Bug Report
about: Create a report to help us improve
title: '[BUG] '
labels: ['bug']
assignees: ''
---

## Bug Description
A clear and concise description of what the bug is.

## Expected Behavior
What you expected to happen.

## Actual Behavior
What actually happened.

## Steps to Reproduce
1. Go to '...'
2. Set inputs to '...'
3. Run action
4. See error

## Action Configuration
```yaml
- name: Check if acceptance should run
  uses: optivem/should-run-acceptance-stage-action@v1
  with:
    repo-owner: 'your-org'
    repo-name: 'your-repo'
    image-name: 'your-app'
    workflow-name: 'acceptance.yml'
    force-run: 'false'
```

## Environment
- **OS**: [e.g., ubuntu-latest, windows-latest]
- **Action Version**: [e.g., v1.0.0]
- **Repository Type**: [e.g., public, private, organization]

## Error Logs
```
Paste any error messages here
```

## Additional Context
Add any other context about the problem here.