# Hardcoded values
$subscriptionId   = "#####################"
$resourceGroupName = "restart"

Disable-AzContextAutosave -Scope Process | Out-Null
Connect-AzAccount -Identity | Out-Null

# Ensure correct subscription context
Set-AzContext -SubscriptionId $subscriptionId | Out-Null

# Get all VMs in the Resource Group
$vms = Get-AzVM -ResourceGroupName $resourceGroupName -Status

$results = @()

foreach ($vm in $vms) {
    $vmName = $vm.Name
    $powerState = ($vm.Statuses | Where-Object { $_.Code -like 'PowerState/*' } | Select-Object -ExpandProperty DisplayStatus -First 1)

    if (-not $powerState) { $powerState = "Unknown" }   # fallback

    if ($powerState -ne "VM running") {
        try {
            Start-AzVM -Name $vmName -ResourceGroupName $resourceGroupName -NoWait | Out-Null
            $results += [PSCustomObject]@{
                VMName        = $vmName
                PreviousState = $powerState
                Action        = "Started"
            }
        } catch {
            $results += [PSCustomObject]@{
                VMName        = $vmName
                PreviousState = $powerState
                Action        = "FailedToStart"
                Error         = $_.Exception.Message
            }
        }
    }
    else {
        $results += [PSCustomObject]@{
            VMName        = $vmName
            PreviousState = $powerState
            Action        = "AlreadyRunning"
        }
    }
}

# Return only clean array as JSON
$results | ConvertTo-Json -Depth 5 -AsArray

