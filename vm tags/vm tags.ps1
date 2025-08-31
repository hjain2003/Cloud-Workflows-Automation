# Suppress default output from Connect-AzAccount
Connect-AzAccount -Identity | Out-Null

# Set subscription
$subscriptionId = "21db9181-d64e-45dd-ac4c-3ae1209a2998"
Set-AzContext -SubscriptionId $subscriptionId | Out-Null

# Define required tags
$requiredTags = @("Environment", "Owner", "CostCenter")

# Get all VMs
$vms = Get-AzVM

# Build report
$report = @()
foreach ($vm in $vms) {
    $vmTags = $vm.Tags
    $missingTags = @()

    foreach ($tag in $requiredTags) {
        if (-not $vmTags.ContainsKey($tag)) {
            $missingTags += $tag
        }
    }

    $report += [PSCustomObject]@{
        VMName        = $vm.Name
        ResourceGroup = $vm.ResourceGroupName
        Location      = $vm.Location
        TagsPresent   = ($vmTags.Keys -join ", ")
        MissingTags   = ($missingTags -join ", ")
        Compliance    = if ($missingTags.Count -eq 0) { "Compliant" } else { "Non-Compliant" }
        TimeStamp     = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
}

# Only output JSON
$report | ConvertTo-Json -Depth 5