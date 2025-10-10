param(
    [Parameter(Mandatory=$true)]
    [string]$RepoOwner,
    [Parameter(Mandatory=$true)]
    [string]$RepoName,
    [Parameter(Mandatory=$true)]
    [string]$InspectDataResult,
    [Parameter(Mandatory=$true)]
    [string]$WorkflowName,
    [Parameter(Mandatory=$false)]
    [bool]$ForceRun = $false
)

Write-Host "🔍 Checking if acceptance stage should run..."
Write-Host "Repository: $RepoOwner/$RepoName"
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
    # Parse the Docker inspect JSON result
    Write-Host "Parsing Docker inspect data..."
    
    try {
        $inspectData = $InspectDataResult | ConvertFrom-Json
        
        if (-not $inspectData.Created) {
            throw "Docker inspect data does not contain 'Created' field"
        }
        
        $imageCreatedTimestamp = $inspectData.Created
        Write-Host "Image created at: $imageCreatedTimestamp"
        
        # Extract image information for logging
        $imageId = if ($inspectData.Id) { $inspectData.Id.Substring(0, 12) } else { "unknown" }
        $repoTags = if ($inspectData.RepoTags) { $inspectData.RepoTags -join ", " } else { "none" }
        
        Write-Host "Image ID: $imageId"
        Write-Host "Repo Tags: $repoTags"
        
        # Compare timestamps
        $lastChecked = [DateTime]::Parse($LastCheckedTimestamp)
        $imageCreated = [DateTime]::Parse($imageCreatedTimestamp)
        
        if ($imageCreated -gt $lastChecked) {
            Write-Host "✅ Image is newer than last acceptance run!"
            Write-Host "Image created: $imageCreatedTimestamp"
            Write-Host "Last checked: $LastCheckedTimestamp"
            
            # Set outputs for acceptance stage to run
            "should-run=true" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
            "reason=new-image-available" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
            "latest-commit=$env:GITHUB_SHA" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
            "latest-image-id=$imageId" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
            "latest-image-created-at=$imageCreatedTimestamp" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
            "new-images-count=1" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
        } else {
            Write-Host "❌ Image is not newer than last acceptance run"
            Write-Host "Image created: $imageCreatedTimestamp"
            Write-Host "Last checked: $LastCheckedTimestamp"
            "should-run=false" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
            "reason=no-new-images" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
        }
        
    } catch {
        throw "Could not parse Docker inspect data: $($_.Exception.Message)"
    }
} catch {
    $errorMessage = $_.Exception.Message
    Write-Host "⚠️ Could not process Docker inspect data: $errorMessage"
    
    Write-Host "❌ Processing error - failing to prevent silent issues"
    "error-message=$errorMessage" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
    
    exit 1
}