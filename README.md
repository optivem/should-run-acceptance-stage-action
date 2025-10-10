# Should Run Acceptance Stage Action

[![GitHub release (latest SemVer)](https://img.shields.io/github/v/release/optivem/should-run-acceptance-stage-action)](https://github.com/optivem/should-run-acceptance-stage-action/releases)
[![GitHub](https://img.shields.io/github/license/optivem/should-run-acceptance-stage-action)](LICENSE)

A GitHub Action that determines whether an acceptance stage should run based on Docker image creation timestamps or a force run flag. This action accepts Docker inspect JSON data and compares the image creation time with the last successful workflow run, helping optimize CI/CD pipelines by only running acceptance tests when there are actual changes to test.

> **Note**: This action now works with any Docker image from any registry. Simply provide the output of `docker inspect <image>` as input.

## Features

- 🔍 **Smart Detection**: Compares Docker image creation timestamp with last successful acceptance run
- 🚀 **Force Run Option**: Bypass image detection and force acceptance stage to run
- 📊 **Detailed Outputs**: Provides comprehensive information about the decision and discovered images
- ⚡ **Performance Optimized**: Reduces unnecessary acceptance test runs
- 🛡️ **Error Handling**: Graceful handling of edge cases and parsing failures
- 🐳 **Registry Agnostic**: Works with any Docker registry (Docker Hub, GHCR, ECR, ACR, etc.)

## Usage

### Basic Usage

```yaml
name: CI/CD Pipeline
on: [push, pull_request]

jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      docker-inspect: ${{ steps.inspect.outputs.result }}
    steps:
      - uses: actions/checkout@v4
      
      # Your build and push steps here...
      - name: Build and push Docker image
        run: |
          docker build -t myregistry/myapp:latest .
          docker push myregistry/myapp:latest
      
      - name: Inspect Docker image
        id: inspect
        run: |
          INSPECT_RESULT=$(docker inspect myregistry/myapp:latest)
          echo "result=$INSPECT_RESULT" >> $GITHUB_OUTPUT
          
  check-acceptance:
    needs: build
    runs-on: ubuntu-latest
    outputs:
      should-run: ${{ steps.check.outputs.should-run }}
      reason: ${{ steps.check.outputs.reason }}
    steps:
      - name: Check if acceptance should run
        id: check
        uses: optivem/should-run-acceptance-stage-action@v1
        with:
          latest-image-inspect-result: '${{ needs.build.outputs.docker-inspect }}'
          # All other parameters use defaults:
          # acceptance-stage-repo-owner: (current repo owner)
          # acceptance-stage-repo-name: (current repo name)  
          # acceptance-stage-workflow-name: 'acceptance-stage'
          
  acceptance-tests:
    needs: check-acceptance
    if: needs.check-acceptance.outputs.should-run == 'true'
    runs-on: ubuntu-latest
    steps:
      - name: Run acceptance tests
        run: |
          echo "Running acceptance tests because: ${{ needs.check-acceptance.outputs.reason }}"
          # Your acceptance test steps here...
```

### With Custom Parameters

```yaml
      - name: Check if acceptance should run
        id: check
        uses: optivem/should-run-acceptance-stage-action@v1
        with:
          acceptance-stage-repo-owner: 'your-org'
          acceptance-stage-repo-name: 'your-repo'
          latest-image-inspect-result: '${{ needs.build.outputs.docker-inspect }}'
          acceptance-stage-workflow-name: 'acceptance-tests.yml'
          
  acceptance-tests:
    needs: check-acceptance
    if: needs.check-acceptance.outputs.should-run == 'true'
    runs-on: ubuntu-latest
    steps:
      - name: Run acceptance tests
        run: |
          echo "Running acceptance tests because: ${{ needs.check-acceptance.outputs.reason }}"
          # Your acceptance test steps here...
```

### With Force Run Option

```yaml
- name: Check if acceptance should run
  id: check
  uses: optivem/should-run-acceptance-stage-action@v1
  with:
    repo-owner: 'your-org'
    repo-name: 'your-repo'
    image-name: 'your-app'
    workflow-name: 'acceptance-tests.yml'
    force-run: 'true'  # Force run regardless of image changes
```

### Using Different Versions

```yaml
# Use specific version
- uses: optivem/should-run-acceptance-stage-action@v1.0.0

# Use latest v1.x
- uses: optivem/should-run-acceptance-stage-action@v1

# Use main branch (not recommended for production)
- uses: optivem/should-run-acceptance-stage-action@main
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `acceptance-stage-repo-owner` | Repository owner (organization or username) | ❌ | `${{ github.repository_owner }}` |
| `acceptance-stage-repo-name` | Repository name | ❌ | `${{ github.event.repository.name }}` |
| `latest-image-inspect-result` | Docker inspect JSON result containing image metadata | ✅ | - |
| `acceptance-stage-workflow-name` | Name of the acceptance stage workflow file | ❌ | `acceptance-stage` |
| `force-run` | Force run even if no new images (bypasses image detection) | ❌ | `false` |

## Outputs

| Output | Description |
|--------|-------------|
| `should-run` | Whether the acceptance stage should run (`true`/`false`) |
| `reason` | Reason why acceptance stage should or should not run |
| `latest-commit` | Latest commit SHA |
| `latest-image-id` | Latest image ID if new image is available |
| `latest-image-created-at` | Latest image creation timestamp |
| `new-images-count` | Number of new images found |
| `error-message` | Error message if check failed |

## How It Works

1. **Last Run Detection**: Queries the GitHub API to find the timestamp of the last successful acceptance workflow run
2. **Image Analysis**: Parses the provided Docker inspect JSON data to extract the image creation timestamp
3. **Decision Logic**: 
   - If `force-run` is `true`: Always runs acceptance stage
   - If image creation time is newer than last successful run: Runs acceptance stage
   - If image creation time is older than last successful run: Skips acceptance stage
4. **Output Generation**: Provides detailed information about the decision for transparency

## Supported Registries

This action works with **any Docker registry** including:
- **Docker Hub** (`docker.io`)
- **GitHub Container Registry** (`ghcr.io`)
- **Amazon ECR** (`*.dkr.ecr.*.amazonaws.com`)
- **Azure Container Registry** (`*.azurecr.io`)
- **Google Container Registry** (`gcr.io`, `*.gcr.io`)
- **Private registries** and **self-hosted registries**

Simply provide the output of `docker inspect <image>` regardless of where the image is hosted.

## Requirements

- **GitHub Token**: The action requires `GITHUB_TOKEN` to access GitHub APIs (automatically provided)
- **Docker Inspect Data**: Provide JSON output from `docker inspect <image>` command
- **GitHub CLI**: Uses `gh` command (pre-installed on GitHub runners)
- **Permissions**: Requires `packages: read` permission to access container registry

### Required Permissions

```yaml
permissions:
  contents: read
  packages: read
  actions: read
```

## Example Workflows

### Complete CI/CD Pipeline

```yaml
name: Complete CI/CD Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

permissions:
  contents: read
  packages: read
  actions: read

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Build and push Docker image
        run: |
          # Your build and push logic here
          echo "Building and pushing image..."
          
  check-acceptance-needed:
    needs: build-and-push
    runs-on: ubuntu-latest
    outputs:
      should-run: ${{ steps.check.outputs.should-run }}
      reason: ${{ steps.check.outputs.reason }}
      new-images-count: ${{ steps.check.outputs.new-images-count }}
    steps:
      - name: Check if acceptance tests should run
        id: check
        uses: optivem/should-run-acceptance-stage-action@v1
        with:
          repo-owner: ${{ github.repository_owner }}
          repo-name: ${{ github.event.repository.name }}
          image-name: 'my-app'
          workflow-name: 'acceptance.yml'
          
      - name: Log decision
        run: |
          echo "Should run acceptance: ${{ steps.check.outputs.should-run }}"
          echo "Reason: ${{ steps.check.outputs.reason }}"
          echo "New images found: ${{ steps.check.outputs.new-images-count }}"
          
  acceptance-tests:
    needs: check-acceptance-needed
    if: needs.check-acceptance-needed.outputs.should-run == 'true'
    runs-on: ubuntu-latest
    steps:
      - name: Run acceptance tests
        run: |
          echo "Running acceptance tests..."
          echo "Reason: ${{ needs.check-acceptance-needed.outputs.reason }}"
          # Your acceptance test commands here
```

## Troubleshooting

### Common Issues

1. **Package Not Found (404)**
   - The action will default to running acceptance stage for safety
   - Ensure the package name format is correct: `repo-name/image-name`

2. **Permission Denied**
   - Verify `packages: read` permission is granted
   - Check if the repository has container packages published

3. **API Rate Limiting**
   - The action uses authenticated requests which have higher rate limits
   - Consider adding delays between workflow runs if hitting limits

### Debug Mode

Enable debug logging by setting the `ACTIONS_STEP_DEBUG` secret to `true` in your repository settings.

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Commit your changes: `git commit -m 'Add amazing feature'`
4. Push to the branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

## Support

- 📖 [Documentation](https://github.com/optivem/should-run-acceptance-stage-action)
- 🐛 [Report Issues](https://github.com/optivem/should-run-acceptance-stage-action/issues)
- 💬 [Discussions](https://github.com/optivem/should-run-acceptance-stage-action/discussions)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributors

Made by [Optivem](https://github.com/optivem)

- [Valentina Jemuović](https://www.linkedin.com/in/valentinajemuovic/)
- [Jelena Cupać](https://www.linkedin.com/in/jelenacupac/)