<#
.SYNOPSIS

A script used to create an Azure Blob Storage with SSH File Transfer Protocol (SFTP) enabled.

.DESCRIPTION

A script used to create an Azure Blob Storage with SSH File Transfer Protocol (SFTP) enabled.
This script will do all of the following:

Remove the breaking change warning messages.
Change the current context to use a management subscription holding your central Log Analytics workspace.
Save the Log Analytics workspace from the management subscription as a variable.
Change the current context to the specified subscription.
Store a specified set of tags in a hash table.
Register the required Azure resource provider feature "AllowSFTP" in the current subscription context, if not yet registered.
Create a resource group for the storage account if it does not already exist. Also apply the necessary tags to this resource group.
Create a general-purpose v2 storage account if it does not already exist; otherwise, exit the script. Also apply the necessary tags to this storage account.
Create a container in the storage account if it does not exist.
Modify the storage account to set blob public access and storage account key access to disabled.
Upgrade the Azure Blob Storage with Azure Data Lake Storage Gen2 capabilities.
Set the log and metrics settings for the storage account resource if they don't exist.
Update the NetworkRule property of the Storage account with the allowed client IP addresses or IP ranges.
Enable SFTP support.
Lock the resource group with a CanNotDelete lock.

.NOTES

Filename:       Create-Azure-Blob-Storage-SFTP.ps1
Created:        02/04/2023
Last modified:  05/04/2023
Author:         Wim Matthyssen
Version:        2.0
PowerShell:     Azure PowerShell and Azure Cloud Shell
Requires:       PowerShell Az (v9.4.0)
Action:         Change variables were needed to fit your needs. 
Disclaimer:     This script is provided "as is" with no warranties.

.EXAMPLE

Connect-AzAccount
Get-AzTenant (if not using the default tenant)
Set-AzContext -tenantID "xxxxxxxx-xxxx-xxxx-xxxxxxxxxxxx" (if not using the default tenant)
.\Create-Azure-Blob-Storage-SFTP -SubscriptionName <"your Azure subscription name here"> -Spoke <"your spoke name here"> -AllowedIP <"your allowed (public) client IP address or range here">

-> .\Create-Azure-Blob-Storage-SFTP -SubscriptionName sub-prd-myh-corp-01 -Spoke prd -AllowedIP 89.198.143.219

.LINK

https://wmatthyssen.com/2023/04/04/create-an-sftp-enabled-azure-storage-account-within-a-specified-subscription-using-an-azure-powershell-script/
#>

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Parameters

param(
    # $subscriptionName -> Name of the Azure Subscription
    [parameter(Mandatory =$true)][ValidateNotNullOrEmpty()] [string] $subscriptionName,
    # $spoke -> Name of the spoke
    [parameter(Mandatory =$true)][ValidateNotNullOrEmpty()] [string] $spoke,
    # $allowedIP -> Allowed client IP address or range
    [parameter(Mandatory =$true)][ValidateNotNullOrEmpty()] [string] $allowedIP
)

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Variables

$region = #<your region here> The used Azure public region. Example: "westeurope"
$purpose = "Sftp"

$featureName = "AllowSFTP"
$providerNameSpace = "Microsoft.Storage"

$rgNameStorage = #<your storage account resource group name here> The name of the Azure resource group in which your new or existing storage account is deployed. Example: "rg-hub-myh-storage-01"

$logAnalyticsWorkSpaceName = #<your Log Analytics workspace name here> The name of your existing Log Analytics workspace. Example: "law-hub-myh-01"

$storageAccountName = #<your storage account name here> The name of your new storage account. Example: "stprdmyhsftp01"
$storageAccountSkuName = "Standard_LRS" #"Standard_ZRS" "Standard_GRS" "Standard_RAGRS" "Premium_LRS" "Premium_ZRS" "Standard_GZRS" "Standard_RAGZRS"
$storageAccountType = "StorageV2"
$storageMinimumTlsVersion = "TLS1_2"
$storageAccountDiagnosticsName = "diag" + "-" + $storageAccountName

$storageContainerName = #<your storage account container name here> The name of your new storage account container. Example: "file-upload"

$tagSpokeName = #<your environment tag name here> The environment tag name you want to use. Example:"Env"
$tagSpokeValue = "$($spoke[0].ToString().ToUpper())$($spoke.SubString(1))"
$tagCostCenterName  = #<your costCenter tag name here> The costCenter tag name you want to use. Example:"CostCenter"
$tagCostCenterValue = #<your costCenter tag value here> The costCenter tag value you want to use. Example: "23"
$tagCriticalityName = #<your businessCriticality tag name here> The businessCriticality tag name you want to use. Example: "Criticality"
$tagCriticalityValue = #<your businessCriticality tag value here> The businessCriticality tag value you want to use. Example: "High"
$tagPurposeName  = #<your purpose tag name here> The purpose tag name you want to use. Example:"Purpose"
$tagSkuName = "Sku"
$tagSkuValue = $storageAccountSkuName

$global:currenttime= Set-PSBreakpoint -Variable currenttime -Mode Read -Action {$global:currenttime= Get-Date -UFormat "%A %m/%d/%Y %R"}
$foregroundColor1 = "Green"
$foregroundColor2 = "Yellow"
$writeEmptyLine = "`n"
$writeSeperatorSpaces = " - "

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Remove the breaking change warning messages

Set-Item -Path Env:\SuppressAzurePowerShellBreakingChangeWarnings -Value $true | Out-Null
Update-AzConfig -DisplayBreakingChangeWarning $false | Out-Null

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Write script started

Write-Host ($writeEmptyLine + "# Script started. Without errors, it can take up to 4 minutes to complete" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor1 $writeEmptyLine 

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Change the current context to use a management subscription holding your central Log Anlytics workspace

# Replace <your subscription purpose name here> with purpose name of your subscription. Example: "*management*"
$subNameManagement = Get-AzSubscription | Where-Object {$_.Name -like "*management*"}

Set-AzContext -SubscriptionId $subNameManagement.SubscriptionId | Out-Null 

Write-Host ($writeEmptyLine + "# Management subscription in current tenant selected" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Save Log Analytics workspace from the management subscription in a variable

$workSpace = Get-AzOperationalInsightsWorkspace | Where-Object Name -Match $logAnalyticsWorkSpaceName

Write-Host ($writeEmptyLine + "# Log Analytics workspace variable created" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Change the current context to the specified subscription

$subName = Get-AzSubscription | Where-Object {$_.Name -like $subscriptionName}

Set-AzContext -SubscriptionId $subName.SubscriptionId | Out-Null 

Write-Host ($writeEmptyLine + "# Specified subscription in current tenant selected" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Register the required Azure resource provider feature "AllowSFTP" in the current subscription context, if not yet registerd

$featureInstalled = Get-AzProviderFeature -FeatureName $featureName -ProviderNamespace $providerNameSpace 

# Register the provider feature "AllowSFTP" if not yet registered
if ($featureInstalled.RegistrationState -notlike $true) {
    Register-AzProviderFeature -FeatureName $featureName -ProviderNamespace $providerNameSpace | Out-Null 
}

Write-Host ($writeEmptyLine + "# SFTP feature registered in the current subscription context" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Store the specified set of tags in a hash table

$tags = @{$tagSpokeName=$tagSpokeValue;$tagCostCenterName=$tagCostCenterValue;$tagCriticalityName=$tagCriticalityValue;$tagPurposeName=$purpose}

Write-Host ($writeEmptyLine + "# Specified set of tags available to add" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine 

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Create a resource group for the storage account if it does not already exist. Also apply the necessary tags to this resource group

try {
    Get-AzResourceGroup -Name $rgNameStorage -ErrorAction Stop | Out-Null 
} catch {
    New-AzResourceGroup -Name $rgNameStorage -Location $region -Force | Out-Null 
}

# Save variable tags in a new variable to add tags.
$tagsResourceGroup = $tags

# Set tags rg storage.
Set-AzResourceGroup -Name $rgNameStorage -Tag $tagsResourceGroup | Out-Null

Write-Host ($writeEmptyLine + "# Resource group $rgNameStorage available" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Create a general-purpose v2 storage account if it does not already exist; otherwise, exit the script. Also apply the necessary tags to this storage account

try {
	$storageAccountObject = Get-AzStorageAccount -ResourceGroupName $rgNameStorage -Name $storageAccountName -ErrorAction Stop
    Write-Host ($writeEmptyLine + "# Storage account already exists, please validate" + $writeSeperatorSpaces + $currentTime)`
    -foregroundcolor $foregroundColor3 $writeEmptyLine
    Start-Sleep -s 3
    Write-Host -NoNewLine ("# Press any key to exit the script ..." + $writeEmptyLine)`
    -foregroundcolor $foregroundColor1 $writeEmptyLine;
    $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null;
    return
} catch {
    $storageAccountObject = New-AzStorageAccount -ResourceGroupName $rgNameStorage -Name $storageAccountName -SkuName $storageAccountSkuName -Location $region -Kind $storageAccountType `
    -AllowBlobPublicAccess $true -AllowSharedKeyAccess $true -MinimumTlsVersion $storageMinimumTlsVersion
}

# Save variable tags in a new variable to add tags
$tagsStorageAccount = $tags

# Add Sku tag to tags for the storage account
$tagsStorageAccount += @{$tagSkuName = $tagSkuValue}

# Set tags storage account
Set-AzStorageAccount -ResourceGroupName $rgNameStorage -Name $storageAccountName -Tag $tagsStorageAccount | Out-Null

Write-Host ($writeEmptyLine + "# Storage account $storageAccountName created" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Create a container in the storage account if it does not exist

$storageContext = $storageAccountObject.Context

New-AzStorageContainer -Name $storageContainerName -Context $storageContext | Out-Null

Write-Host ($writeEmptyLine + "# Container $storageContainerName created" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Modify the storage account to set blob public access and storage account key access to disabled

Set-AzStorageAccount -ResourceGroupName $rgNameStorage -Name $storageAccountName -AllowBlobPublicAccess $false -AllowSharedKeyAccess $false | Out-Null

Write-Host ($writeEmptyLine + "# Storage account $storageAccountName public blob and storage account key access set to disabled" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Upgrade Azure Blob Storage with Azure Data Lake Storage Gen2 capabilities

Write-Host ($writeEmptyLine + "# Starting the Data Lake Storage Gen2 upgrade, which can take up to 3 minutes" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor1 $writeEmptyLine

# Validates if the stroage account can be upgrade to enable HierarchicalNamespace
Invoke-AzStorageAccountHierarchicalNamespaceUpgrade -ResourceGroupName $rgNameStorage -Name $storageAccountName -RequestType Validation | Out-Null 

# Upgrade the storage account to enable HierarchicalNamespace and wait until the job completes
$task = Invoke-AzStorageAccountHierarchicalNamespaceUpgrade -ResourceGroupName $rgNameStorage -Name $storageAccountName -RequestType Upgrade -Force -AsJob
$task | Wait-Job | Out-Null 
 
Write-Host ($writeEmptyLine + "# Storage account $storageAccountName upgraded with Azure Data Lake Storage Gen2 capabilities" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Set the log and metrics settings for the storage account resource if they don't exist

$storageAccount = Get-AzStorageAccount -ResourceGroupName $rgNameStorage -Name $storageAccountName

try {
    Get-AzDiagnosticSetting -Name $storageAccountDiagnosticsName -ResourceId ($storageAccount.Id) -ErrorAction Stop | Out-Null
} catch { 
    $metric = @()
    $metric += New-AzDiagnosticSettingMetricSettingsObject -Enabled $true -Category AllMetrics
    New-AzDiagnosticSetting -Name $storageAccountDiagnosticsName -ResourceId ($storageAccount.Id) -WorkspaceId ($workSpace.ResourceId) -Metric $metric | Out-Null
}

Write-Host ($writeEmptyLine + "# Storage account $storageAccountName diagnostic settings set" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Update the NetworkRule property of the Storage account with the allowed client IP addresses or IP ranges

# Only allow traffic from specific virtual networks, IP addresses or resources
Update-AzStorageAccountNetworkRuleSet -ResourceGroupName $rgNameStorage -Name $storageAccountName -DefaultAction Deny | Out-Null

# Add allowed client IP addresses or IP ranges
Add-AzStorageAccountNetworkRule -ResourceGroupName $rgNameStorage -Name $storageAccountName -IPRule (@{IPAddressOrRange=$allowedIP;Action="allow"}) | Out-Null

Write-Host ($writeEmptyLine + "# Storage account firewall set with the allowed IP addresses or CIDR ranges" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Enable SFTP support

Set-AzStorageAccount -ResourceGroupName $rgNameStorage -Name $storageAccountName -EnableSftp $true | Out-Null

Write-Host ($writeEmptyLine + "# SFTP support for storage account $storageAccountName enabled" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Lock the resource group with a CanNotDelete lock

$lock = Get-AzResourceLock -ResourceGroupName $rgNameStorage

if ($null -eq $lock){
    New-AzResourceLock -LockName DoNotDeleteLock -LockLevel CanNotDelete -ResourceGroupName $rgNameStorage -LockNotes "Prevent $rgNameStorage from deletion" -Force | Out-Null
    } 

Write-Host ($writeEmptyLine + "# Resource group $rgNameStorage locked" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Write script completed

Write-Host ($writeEmptyLine + "# Script completed" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor1 $writeEmptyLine 

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
