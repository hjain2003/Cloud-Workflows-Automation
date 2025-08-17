Connect-AzAccount -Identity | Out-Null

# Set subscription
$subscriptionId = "f347f7a8-8092-47ce-a30a-ce5f2a7f16a1"
Set-AzContext -SubscriptionId $subscriptionId | Out-Null

# Get unattached disks
$disks = Get-AzDisk | Where-Object { -not $_.ManagedBy } | ForEach-Object {
    [PSCustomObject]@{
        Name            = $_.Name
        ResourceGroup   = $_.ResourceGroupName
        SubscriptionId  = $_.Id.Split("/")[2]
        ResourceType    = "UnattachedDisk"
    }
}

# Get idle public IPs
$publicIps = Get-AzPublicIpAddress | Where-Object { -not $_.IpConfiguration } | ForEach-Object {
    [PSCustomObject]@{
        Name            = $_.Name
        ResourceGroup   = $_.ResourceGroupName
        SubscriptionId  = $_.Id.Split("/")[2]
        ResourceType    = "IdlePublicIp"
    }
}

# Get unused NSGs
$nsgs = Get-AzNetworkSecurityGroup | Where-Object { 
    ($_.NetworkInterfaces.Count -eq 0) -and ($_.Subnets.Count -eq 0)
} | ForEach-Object {
    [PSCustomObject]@{
        Name            = $_.Name
        ResourceGroup   = $_.ResourceGroupName
        SubscriptionId  = $_.Id.Split("/")[2]
        ResourceType    = "UnusedNSG"
    }
}

# Final unified result
$result = @($disks) + @($publicIps) + @($nsgs)

# Convert to JSON
$result | ConvertTo-Json -Depth 5
