param(
    [Parameter(Mandatory=$true)]
    [string]$RepoOwner,
    [Parameter(Mandatory=$true)]
    [string]$RepoName,
    [Parameter(Mandatory=$true)]
    [string]$WorkflowName,
    [Parameter(Mandatory=$false)]
    [bool]$ForceRun = $false
)

Write-Host "🔍 Checking if acceptance stage should run..."
Write-Host "Repository: $RepoOwner/$RepoName"
Write-Host "Acceptance Workflow: $WorkflowName"
Write-Host "Force Run: $ForceRun"

# Get inspect data from environment variable
$InspectDataResults = $env:INSPECT_DATA_RESULTS
if ([string]::IsNullOrWhiteSpace($InspectDataResults)) {
    Write-Host "❌ INSPECT_DATA_RESULTS environment variable is empty or not set"
    "error-message=INSPECT_DATA_RESULTS environment variable is required" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
    exit 1
}

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
        # Validate input format
        if ([string]::IsNullOrWhiteSpace($InspectDataResults)) {
            throw "InspectDataResults parameter is empty or null"
        }
        
        # Check if input looks like JSON array (must start with [ and end with ])
        $trimmedInput = $InspectDataResults.Trim()
        if (-not ($trimmedInput.StartsWith('[') -and $trimmedInput.EndsWith(']'))) {
            Write-Host "❌ Invalid input format detected!"
            Write-Host "Expected: JSON array format like: [{'Id': 'sha256:...', 'Created': '2025-01-01T...', ...}]"
            Write-Host "Received: $($InspectDataResults.Substring(0, [Math]::Min(100, $InspectDataResults.Length)))..."
            Write-Host ""
            Write-Host "💡 To fix this, ensure you're passing a JSON array:"
            Write-Host "   INSPECT_RESULT=`$(docker inspect your-image:tag)  # Returns array by default"
            Write-Host "   - For single image: Pass `$INSPECT_RESULT directly"
            Write-Host "   - For multiple images: Combine like: `"[`$IMAGE1_JSON, `$IMAGE2_JSON]`""
            Write-Host "   - Single object format {..} is NOT supported - wrap in array: [{...}]"
            throw "Input must be a JSON array starting with '[' and ending with ']'"
        }
        
        # Parse as JSON array
        $inspectDataArray = $InspectDataResults | ConvertFrom-Json
        
        # PowerShell sometimes doesn't treat single-element arrays as arrays
        # Force it to be an array if it's not already
        if ($inspectDataArray -isnot [Array]) {
            $inspectDataArray = @($inspectDataArray)
        }
        
        # Validate that each item has required fields
        foreach ($item in $inspectDataArray) {
            if (-not $item.Created) {
                Write-Host "❌ Invalid Docker inspect data: Missing 'Created' field"
                Write-Host "Each inspect result must have a 'Created' field with timestamp"
                throw "Docker inspect data is missing required 'Created' field"
            }
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