Disable-AzContextAutosave -Scope Process | Out-Null

# Connect using system-assigned managed identity
Connect-AzAccount -Identity | Out-Null

# Set subscription explicitly
$subscriptionId = "##################"
Set-AzContext -SubscriptionId $subscriptionId | Out-Null

# Get all NSGs
$nsgs = Get-AzNetworkSecurityGroup

$insecureRules = @()

foreach ($nsg in $nsgs) {
    foreach ($rule in $nsg.SecurityRules) {
        if ($rule.Access -eq "Allow" -and
            $rule.Direction -eq "Inbound" -and
            ($rule.SourceAddressPrefix -eq "0.0.0.0/0" -or $rule.SourceAddressPrefix -eq "*") -and
            ($rule.DestinationPortRange -eq "22" -or 
             $rule.DestinationPortRange -eq "3389" -or 
             $rule.DestinationPortRange -eq "*")) {
            
            $insecureRules += [PSCustomObject]@{
                NSGName       = $nsg.Name
                ResourceGroup = $nsg.ResourceGroupName
                RuleName      = $rule.Name
                Port          = $rule.DestinationPortRange
                Source        = $rule.SourceAddressPrefix
            }
        }
    }
}

# Output only JSON (clean)
@($insecureRules) | ConvertTo-Json -Depth 5 -Compress
