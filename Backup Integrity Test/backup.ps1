# BackupIntegrityCheck runbook - PowerShell
Disable-AzContextAutosave -Scope Process | Out-Null
Connect-AzAccount -Identity | Out-Null

# Set subscription explicitly
$subscriptionId = "############################"
Set-AzContext -SubscriptionId $subscriptionId | Out-Null

# Vault name and lookback window (hours)
$vaultName = "v1"    # e.g. backupVault
$rgOfVault = "test" # resource group where vault resides
$lookbackHours = 24

# Get vault
$vault = Get-AzRecoveryServicesVault -Name $vaultName -ResourceGroupName $rgOfVault
if (-not $vault) {
    Throw "Vault $vaultName not found in RG $rgOfVault"
}
Set-AzRecoveryServicesVaultContext -Vault $vault | Out-Null

# Get backup jobs in the last X hours
$since = (Get-Date).ToUniversalTime().AddHours(-1 * $lookbackHours)
$jobs = Get-AzRecoveryServicesBackupJob | Where-Object { $_.EndTime -ge $since }

$results = @()

foreach ($job in $jobs) {
    # Handle different property names and null values
    $status = $job.Status
    
    # Try different properties for workload type
    $workload = $job.WorkloadType
    if ([string]::IsNullOrEmpty($workload)) {
        $workload = $job.BackupManagementType
    }
    if ([string]::IsNullOrEmpty($workload)) {
        $workload = "Unknown"
    }
    
    # Try different properties for item name
    $itemName = $job.EntityFriendlyName
    if ([string]::IsNullOrEmpty($itemName)) {
        $itemName = $job.ItemName
    }
    if ([string]::IsNullOrEmpty($itemName)) {
        $itemName = $job.Name
    }
    if ([string]::IsNullOrEmpty($itemName)) {
        # Try to extract from JobId or other properties
        if ($job.JobId) {
            $itemName = "Job-" + $job.JobId.Substring(0, 8)
        } else {
            $itemName = "Unknown"
        }
    }
    
    # Resource Group handling
    $rg = $job.ResourceGroupName
    if ([string]::IsNullOrEmpty($rg)) {
        # Try to extract from other properties if available
        if ($job.Properties -and $job.Properties.ContainsKey("ResourceGroupName")) {
            $rg = $job.Properties["ResourceGroupName"]
        } else {
            $rg = "Unknown"
        }
    }
    
    $ended = $job.EndTime.ToUniversalTime().ToString("o")
    
    $health = "OK"
    if ($status -ne "Completed") { 
        $health = "BackupFailed" 
    }
    
    # Additional VM check - only for VM workloads
    $powerState = $null
    if ($workload -eq "VM" -or $workload -eq "AzureVM" -or $workload -like "*VM*") {
        try {
            # Only try VM check if we have a valid item name and resource group
            if ($itemName -ne "Unknown" -and $rg -ne "Unknown" -and $itemName -notlike "Job-*") {
                $vm = Get-AzVM -Name $itemName -ResourceGroupName $rg -Status -ErrorAction Stop
                # VM statuses array: check power state
                $powerState = ($vm.Statuses | Where-Object { $_.Code -like 'PowerState/*' } | Select-Object -First 1).DisplayStatus
                if ($powerState -ne "VM running") {
                    $health = "VMNotRunning"
                }
            } else {
                $powerState = "SkippedCheck"
            }
        } catch {
            $powerState = "VMNotFound"
            if ($health -eq "OK") {
                $health = "VMNotFound"
            }
        }
    }
    
    $results += [PSCustomObject]@{
        BackupItem      = $itemName
        WorkloadType    = $workload
        ResourceGroup   = $rg
        Status          = $status
        HealthCheck     = $health
        EndTimeUtc      = $ended
        PowerState      = $powerState
        JobId           = $job.JobId
        Operation       = $job.Operation
        StartTime       = if ($job.StartTime) { $job.StartTime.ToUniversalTime().ToString("o") } else { $null }
    }
}

# Ensure array output always (like your original script)
@($results) | ConvertTo-Json -Depth 6 -Compress