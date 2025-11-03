# Should Run Acceptance Stage Action

[![Test Action](https://github.com/optivem/should-run-acceptance-stage-action/actions/workflows/test.yml/badge.svg)](https://github.com/optivem/should-run-acceptance-stage-action/actions/workflows/test.yml)
[![Release](https://github.com/optivem/should-run-acceptance-stage-action/actions/workflows/release.yml/badge.svg)](https://github.com/optivem/should-run-acceptance-stage-action/actions/workflows/release.yml)

[![GitHub release (latest SemVer)](https://img.shields.io/github/v/release/optivem/should-run-acceptance-stage-action)](https://github.com/optivem/should-run-acceptance-stage-action/releases)

[![GitHub](https://img.shields.io/github/license/optivem/should-run-acceptance-stage-action)](LICENSE)

A GitHub Action that determines whether an acceptance stage should run based on Docker image creation timestamps or a force run flag. This action accepts a Docker image timestamp and compares it with the last successful workflow run, helping optimize CI/CD pipelines by only running acceptance tests when there are actual changes to test.

> **Note**: This action works with any Docker image from any registry. Simply provide the creation timestamp from `docker inspect <image>` output.

## Features

- 🔍 **Smart Detection**: Compares Docker image creation timestamp with last successful acceptance run
- 🚀 **Force Run Option**: Bypass image detection and force acceptance stage to run
- 📊 **Detailed Outputs**: Provides comprehensive information about the decision
- ⚡ **Performance Optimized**: Reduces unnecessary acceptance test runs
- 🛡️ **Error Handling**: Graceful handling of edge cases and parsing failures
- 🐳 **Registry Agnostic**: Works with any Docker registry (Docker Hub, GHCR, ECR, ACR, etc.)
- � **Simple Input**: Just provide the timestamp - no complex JSON parsing required

## Input Format Requirements

This action requires a Docker image creation timestamp in ISO 8601 format. The `latest-image-timestamp` input must be:

- **ISO 8601 Format**: Standard timestamp format like `2025-10-15T14:30:45.123456789Z`
- **From Docker Inspect**: Extract the `Created` field from `docker inspect` output
- **UTC Timezone**: Preferably in UTC (Z suffix) for consistent comparison

### ✅ Correct Examples:

```bash
# Extract timestamp from docker inspect
TIMESTAMP=$(docker inspect myimage:latest | jq -r '.[0].Created')
echo "timestamp=$TIMESTAMP" >> $GITHUB_OUTPUT

# Multiple images - use the latest timestamp
IMAGE1_TIME=$(docker inspect myimage1:latest | jq -r '.[0].Created')
IMAGE2_TIME=$(docker inspect myimage2:latest | jq -r '.[0].Created')
# Use whichever is newer, or combine logic as needed
LATEST_TIME=$(echo -e "$IMAGE1_TIME\n$IMAGE2_TIME" | sort -r | head -1)
echo "timestamp=$LATEST_TIME" >> $GITHUB_OUTPUT
```

### ❌ Common Mistakes:

```bash
# DON'T: Pass full JSON object
echo "timestamp={\"Created\": \"2025-01-01T...\", \"Id\": \"...\"}" >> $GITHUB_OUTPUT

# DON'T: Pass non-timestamp format
echo "timestamp=2025-01-01 14:30:45" >> $GITHUB_OUTPUT

# DON'T: Pass empty or null values  
echo "result=" >> $GITHUB_OUTPUT
```

## Usage

### Basic Usage

```yaml
name: CI/CD Pipeline
on: [push, pull_request]

jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      image-timestamp: ${{ steps.inspect.outputs.timestamp }}
    steps:
      - uses: actions/checkout@v4
      
      # Your build and push steps here...
      - name: Build and push Docker image
        run: |
          docker build -t myregistry/myapp:latest .
          docker push myregistry/myapp:latest
      
      - name: Get Docker image timestamp
        id: inspect
        run: |
          # Extract timestamp from docker inspect
          TIMESTAMP=$(docker inspect myregistry/myapp:latest | jq -r '.[0].Created')
          echo "timestamp=$TIMESTAMP" >> $GITHUB_OUTPUT
          
  check-acceptance:
    needs: build
    runs-on: ubuntu-latest
    outputs:
      should-run: ${{ steps.check.outputs.should-run }}
    steps:
      - name: Check if acceptance should run
        id: check
        uses: optivem/should-run-acceptance-stage-action@v1
        with:
          latest-image-timestamp: '${{ needs.build.outputs.image-timestamp }}'
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
          echo "Running acceptance tests..."
          # Your acceptance test steps here...
```

### With Multiple Images

```yaml
name: CI/CD Pipeline
on: [push, pull_request]

jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      image-timestamp: ${{ steps.inspect.outputs.timestamp }}
    steps:
      - uses: actions/checkout@v4
      
      # Your build and push steps here...
      - name: Build and push Docker images
        run: |
          docker build -t myregistry/myapp:latest .
          docker build -t myregistry/myapp:${{ github.sha }} .
          docker push myregistry/myapp:latest
          docker push myregistry/myapp:${{ github.sha }}
      
      - name: Get latest Docker image timestamp
        id: inspect
        run: |
          # Get timestamps from multiple images and find the latest
          LATEST_TIME=$(docker inspect myregistry/myapp:latest | jq -r '.[0].Created')
          SHA_TIME=$(docker inspect myregistry/myapp:${{ github.sha }} | jq -r '.[0].Created')
          
          # Use the newer timestamp
          if [[ "$LATEST_TIME" > "$SHA_TIME" ]]; then
            echo "timestamp=$LATEST_TIME" >> $GITHUB_OUTPUT
          else
            echo "timestamp=$SHA_TIME" >> $GITHUB_OUTPUT
          fi
          
  check-acceptance:
    needs: build
    runs-on: ubuntu-latest
    outputs:
      should-run: ${{ steps.check.outputs.should-run }}
    steps:
      - name: Check if acceptance should run
        id: check
        uses: optivem/should-run-acceptance-stage-action@v1
        with:
          latest-image-timestamp: '${{ needs.build.outputs.image-timestamp }}'
          
  acceptance-tests:
    needs: check-acceptance
    if: needs.check-acceptance.outputs.should-run == 'true'
    runs-on: ubuntu-latest
    steps:
      - name: Run acceptance tests
        run: |
          echo "Running acceptance tests..."
          echo "Reason: ${{ needs.check-acceptance.outputs.reason }}"
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
          latest-image-timestamp: '${{ needs.build.outputs.image-timestamp }}'
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
    acceptance-stage-repo-owner: 'your-org'
    acceptance-stage-repo-name: 'your-repo'
    latest-image-timestamp: '${{ needs.build.outputs.image-timestamp }}'
    acceptance-stage-workflow-name: 'acceptance-tests.yml'
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
| `latest-image-timestamp` | Timestamp of the latest Docker image creation (ISO 8601 format) | ✅ | - |
| `acceptance-stage-repo-owner` | Repository owner (organization or username) | ❌ | `${{ github.repository_owner }}` |
| `acceptance-stage-repo-name` | Repository name | ❌ | `${{ github.event.repository.name }}` |
| `acceptance-stage-workflow-name` | Name of the acceptance stage workflow file | ❌ | `acceptance-stage` |
| `force-run` | Force run even if no new images (bypasses image detection) | ❌ | `false` |

## Outputs

| Output | Description |
|--------|-------------|
| `should-run` | Whether the acceptance stage should run (`true`/`false`) |

## How It Works

1. **Last Run Detection**: Queries the GitHub API to find the timestamp of the last successful acceptance workflow run
2. **Timestamp Comparison**: Compares the provided Docker image creation timestamp with the last successful run
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
- **Image Timestamp**: Provide ISO 8601 timestamp from `docker inspect <image>` output
- **GitHub CLI**: Uses `gh` command (pre-installed on GitHub runners)
- **Permissions**: Requires `actions: read` permission to access workflow history

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
          echo "Latest image created: ${{ steps.check.outputs.latest-image-created-at }}"
          
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

1. **"Could not parse timestamps" Error**
   - **Cause**: Invalid timestamp format provided to `latest-image-timestamp`
   - **Solution**: Ensure you're passing a valid ISO 8601 timestamp from `docker inspect`:
   ```bash
   # ✅ Correct: Extract timestamp from docker inspect
   TIMESTAMP=$(docker inspect your-image:tag | jq -r '.[0].Created')
   echo "timestamp=$TIMESTAMP" >> $GITHUB_OUTPUT
   
   # ❌ Wrong: Don't pass formatted strings or non-timestamp data
   echo "timestamp=2025-01-01 14:30:45" >> $GITHUB_OUTPUT
   ```

2. **"LATEST_IMAGE_TIMESTAMP environment variable is empty" Error**
   - **Cause**: Missing or empty `latest-image-timestamp` input
   - **Solution**: Verify your workflow passes the timestamp:
   ```bash
   docker inspect your-image:tag | jq -r '.[0].Created'
   ```

3. **No Previous Workflow Runs Found**
   - The action will use a fallback timestamp (24 hours ago) for safety
   - This ensures the first run after setup will trigger acceptance tests

4. **Permission Denied on GitHub API**
   - Verify `actions: read` permission is granted in workflow
   - The action will use fallback logic if GitHub API is unavailable

5. **API Rate Limiting**
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
