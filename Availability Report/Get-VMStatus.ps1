# Suppress default output from Connect-AzAccount
Connect-AzAccount -Identity | Out-Null

# Set subscription
$subscriptionId = "<YOUR_SUBSCRIPTION_ID>"
Set-AzContext -SubscriptionId $subscriptionId | Out-Null

# Get all VMs and their power states
$vms = Get-AzVM -Status

# Build report
$report = @()
foreach ($vm in $vms) {
    $report += [PSCustomObject]@{
        VMName        = $vm.Name
        ResourceGroup = $vm.ResourceGroupName
        Location      = $vm.Location
        Status        = $vm.PowerState
        TimeStamp     = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
}

# Only output JSON
$report | ConvertTo-Json -Depth 5