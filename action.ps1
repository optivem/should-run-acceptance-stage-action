param(
    [Parameter(Mandatory=$true)]
    [string]$RepoOwner,
    [Parameter(Mandatory=$true)]
    [string]$RepoName,
    [Parameter(Mandatory=$true)]
    [string]$InspectDataResults,
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
    # Parse the Docker inspect JSON results array
    Write-Host "Parsing Docker inspect data array..."
    
    try {
        # Parse as JSON array
        $inspectDataArray = $InspectDataResults | ConvertFrom-Json
        
        # Ensure it's an array
        if ($inspectDataArray -isnot [Array]) {
            $inspectDataArray = @($inspectDataArray)
        }
        
        Write-Host "Processing $($inspectDataArray.Count) image(s)..."
        
        # Compare timestamps for all images - exit early if any newer image found
        $lastChecked = [DateTime]::Parse($LastCheckedTimestamp)
        
        foreach ($inspectData in $inspectDataArray) {
            if (-not $inspectData.Created) {
                Write-Warning "Docker inspect data does not contain 'Created' field, skipping image"
                continue
            }
            
            $imageCreatedTimestamp = $inspectData.Created
            $imageCreated = [DateTime]::Parse($imageCreatedTimestamp)
            
            # Extract image information for logging
            $imageId = if ($inspectData.Id -and $inspectData.Id.Length -gt 12) { 
                $inspectData.Id.Substring(0, 12) 
            } elseif ($inspectData.Id) { 
                $inspectData.Id 
            } else { 
                "unknown" 
            }
            $repoTags = if ($inspectData.RepoTags) { $inspectData.RepoTags -join ", " } else { "none" }
            
            Write-Host "Processing image: $imageId"
            Write-Host "  Repo Tags: $repoTags"
            Write-Host "  Created: $imageCreatedTimestamp"
            
            # Check if this image is newer than last acceptance run
            if ($imageCreated -gt $lastChecked) {
                Write-Host "  ✅ Newer than last acceptance run - ACCEPTANCE SHOULD RUN!"
                Write-Host ""
                Write-Host "✅ Found newer image since last acceptance run!"
                Write-Host "Image ID: $imageId"
                Write-Host "Image created: $imageCreatedTimestamp"
                Write-Host "Last checked: $LastCheckedTimestamp"
                
                # Set outputs for acceptance stage to run and EXIT IMMEDIATELY
                "should-run=true" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
                "reason=new-image-available" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
                "latest-commit=$env:GITHUB_SHA" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
                "latest-image-id=$imageId" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
                "latest-image-created-at=$imageCreatedTimestamp" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
                "new-images-count=1" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
                
                exit 0
            } else {
                Write-Host "  ❌ Not newer than last acceptance run"
            }
        }
        
        # If we get here, ALL images were older than last acceptance run
        Write-Host ""
        Write-Host "❌ No new images found since last acceptance run"
        Write-Host "Processed $($inspectDataArray.Count) image(s) - all were older"
        Write-Host "Last checked: $LastCheckedTimestamp"
        "should-run=false" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
        "reason=no-new-images" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
        
    } catch {
        throw "Could not parse Docker inspect data array: $($_.Exception.Message)"
    }
} catch {
    $errorMessage = $_.Exception.Message
    Write-Host "⚠️ Could not process Docker inspect data: $errorMessage"
    
    Write-Host "❌ Processing error - failing to prevent silent issues"
    "error-message=$errorMessage" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
    
    exit 1
}