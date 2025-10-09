param(
    [Parameter(Mandatory=$true)]
    [string]$RepoOwner,
    [Parameter(Mandatory=$true)]
    [string]$RepoName,
    [Parameter(Mandatory=$true)]
    [string]$ImageName,
    [Parameter(Mandatory=$true)]
    [string]$WorkflowName,
    [Parameter(Mandatory=$false)]
    [bool]$ForceRun = $false
)

Write-Host "🔍 Checking if acceptance stage should run..."
Write-Host "Repository: $RepoOwner/$RepoName"
Write-Host "Image: $ImageName"
Write-Host "Acceptance Workflow: $WorkflowName"
Write-Host "Force Run: $ForceRun"

# If force run is enabled, always run
if ($ForceRun) {
    Write-Host "🚀 Force run enabled - acceptance stage will run"
    "should-run=true" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
    "reason=force-run" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
    "latest-commit=$env:GITHUB_SHA" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
    exit 0
}

# Get timestamp from last successful acceptance workflow run
$lastWorkflowRun = gh run list --repo "$RepoOwner/$RepoName" --workflow "$WorkflowName" --status success --limit 1 --json createdAt | ConvertFrom-Json
if ($lastWorkflowRun.Count -gt 0) {
    $LastCheckedTimestamp = $lastWorkflowRun[0].createdAt
    Write-Host "Last successful acceptance run: $LastCheckedTimestamp"
} else {
    $LastCheckedTimestamp = (Get-Date).AddDays(-1).ToString("yyyy-MM-ddTHH:mm:ssZ")
    Write-Host "No previous acceptance runs found, using fallback: $LastCheckedTimestamp"
}

Write-Host "Checking for images newer than: $LastCheckedTimestamp"

try {
    # The package we're looking for: repo-name/image-name format
    $targetPackageName = "$RepoName/$ImageName"
    Write-Host "Looking for package: $targetPackageName"
    
    # Try to access the specific package directly using organization endpoint
    # Package names with slashes need URL encoding: / becomes %2F
    $encodedPackageName = $targetPackageName -replace "/", "%2F"
    
    try {
        $packageJson = gh api "/orgs/$RepoOwner/packages/container/$encodedPackageName"
        $package = $packageJson | ConvertFrom-Json
        Write-Host "✅ Found package: $($package.name)"
        Write-Host "Package repository: $($package.repository.name)"
        Write-Host "Package versions: $($package.version_count)"
        
        # Get versions for this package
        $versionsJson = gh api "/orgs/$RepoOwner/packages/container/$encodedPackageName/versions"
        $versions = $versionsJson | ConvertFrom-Json
        
        $lastChecked = [DateTime]::Parse($LastCheckedTimestamp)
        
        $newImages = $versions | Where-Object { 
            [DateTime]::Parse($_.created_at) -gt $lastChecked 
        }
        
        if ($newImages.Count -gt 0) {
            $latestImage = $newImages[0]
            Write-Host "✅ Found $($newImages.Count) new image(s)!"
            Write-Host "Latest image created: $($latestImage.created_at)"
            Write-Host "Latest image name: $($latestImage.name)"
            
            # Set outputs for acceptance stage to run
            "should-run=true" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
            "reason=new-image-available" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
            "latest-commit=$env:GITHUB_SHA" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
            "latest-image-id=$($latestImage.id)" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
            "latest-image-created-at=$($latestImage.created_at)" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
            "new-images-count=$($newImages.Count)" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
        } else {
            Write-Host "❌ No new images found since last acceptance run"
            "should-run=false" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
            "reason=no-new-images" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
        }
        
    } catch {
        throw "Could not access package '$targetPackageName': $($_.Exception.Message)"
    }
} catch {
    $errorMessage = $_.Exception.Message
    Write-Host "⚠️ Could not check container registry: $errorMessage"
    Write-Host "Command: gh api /orgs/$RepoOwner/packages/container/$encodedPackageName"
    
    # Handle 404 specifically - package might not exist yet
    if ($errorMessage -like "*404*") {
        Write-Host "📦 Package '$targetPackageName' not found - this might be the first time checking"
        Write-Host "Defaulting to run acceptance stage to be safe"
        "should-run=true" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
        "reason=package-not-found-run-safe" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
        "latest-commit=$env:GITHUB_SHA" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
    } else {
        Write-Host "❌ API error - failing to prevent silent issues"
        "error-message=$errorMessage" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
    }

    exit 1
}