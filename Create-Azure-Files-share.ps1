<#
.SYNOPSIS

A script used to create an Azure Files share in a selected Azure subscription.

.DESCRIPTION

A script used to create an Azure Files share in a selected Azure subscription.
This script will do all of the following:

Remove the breaking change warning messages.
Change the current context to use a management subscription holding your central Log Analytics workspace.
Save the Log Analytics workspace from the management subscription as a variable.
Change the current context to the specified subscription.
Store a specified set of tags in a hash table.
Create a resource group for the File Share resources if it does not already exist. Also apply the necessary tags to this resource group.
Create a general-purpose v2 storage account for the File Share with specific configuration settings if it does not already exist. Also apply the necessary tags to this storage account.
Create an Azure file share if it does not exist. Also apply the necessary meta data to this file share.
Set the log and metrics settings for the storage account resource if they don't exist.
Set the log and metrics settings for the file share if they don't exist.

.NOTES

Filename:       Create-Azure-Files-share.ps1
Created:        01/02/2023
Last modified:  21/03/2023
Author:         Wim Matthyssen
Version:        2.0
PowerShell:     Azure PowerShell and Azure Cloud Shell
Requires:       PowerShell Az (v9.3.0)
Action:         Change variables were needed to fit your needs. 
Disclaimer:     This script is provided "as is" with no warranties.

.EXAMPLE

Connect-AzAccount
Get-AzTenant (if not using the default tenant)
Set-AzContext -tenantID "xxxxxxxx-xxxx-xxxx-xxxxxxxxxxxx" (if not using the default tenant)
.\Create-Azure-Files-share <"your Azure subscription name here"> <"your spoke name here"> <"your File Share quota in GiB here">

-> .\Create-Azure-Files-share sub-hub-myh-management-01 hub 5119

.LINK

https://wmatthyssen.com/2023/02/02/create-an-azure-files-share-in-a-specified-subscription-using-an-azure-powershell-script/
#>

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Parameters

param(
    # $subscriptionName -> Name of the Azure Subscription
    [parameter(Mandatory =$true)][ValidateNotNullOrEmpty()] [string] $subscriptionName,
    # $spoke -> Name of the spoke
    [parameter(Mandatory =$true)][ValidateNotNullOrEmpty()] [string] $spoke,
    # $fileShareQuotaGiB -> File share quota 5119 = 5 TiB
    [parameter(Mandatory =$true)][ValidateNotNullOrEmpty()] [string] $fileShareQuotaGiB
)

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Variables

$region = #<your region here> The used Azure public region. Example: "westeurope"
$purpose = "FileShare"

$rgNameStorage = #<your storage account resource group name here> The name of the Azure resource group in which your new or existing storage account is deployed. Example: "rg-hub-myh-storage-01"

$logAnalyticsWorkSpaceName = #<your Log Analytics workspace name here> The name of your existing Log Analytics workspace. Example: "law-hub-myh-01"

$storageAccountName = #<your storage account name here> The existing or new storage account. Example: "sthubmyhlog01"
$storageAccountSkuName = "Standard_LRS" #"Standard_ZRS" "Standard_GRS" "Standard_RAGRS" "Premium_LRS" "Premium_ZRS" "Standard_GZRS" "Standard_RAGZRS"
$storageAccountType = "StorageV2"
$storageMinimumTlsVersion = "TLS1_2"
$storageAccountDiagnosticsName = "diag" + "-" + $storageAccountName

$fileShareName = $abbraviationFileShare + "-" + $spoke.ToLower() + "-" + $companyShortName + "-" + $inventoryNumbering.ToString("D2")
$fileShareAccessTier = "TransactionOptimized" #"Premium" "Hot" "Cool"
$fileShareDiagnosticsName = "diag" + "-" + $fileShareName
$fileShareDeleteRetentionPolicy = 7

$tagSpokeName = #<your environment tag name here> The environment tag name you want to use. Example:"Env"
$tagSpokeValue = "$($spoke[0].ToString().ToUpper())$($spoke.SubString(1))"
$tagCostCenterName  = #<your costCenter tag name here> The costCenter tag name you want to use. Example:"CostCenter"
$tagCostCenterValue = #<your costCenter tag value here> The costCenter tag value you want to use. Example: "23"
$tagCriticalityName = #<your businessCriticality tag name here> The businessCriticality tag name you want to use. Example: "Criticality"
$tagCriticalityValue = #<your businessCriticality tag value here> The businessCriticality tag value you want to use. Example: "High"
$tagPurposeName  = #<your purpose tag name here> The purpose tag name you want to use. Example:"Purpose"
$tagPurposeValue = $purpose 
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

Write-Host ($writeEmptyLine + "# Script started. Without errors, it can take up to 2 minutes to complete" + $writeSeperatorSpaces + $currentTime)`
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

## Store the specified set of tags in a hash table

$tags = @{$tagSpokeName=$tagSpokeValue;$tagCostCenterName=$tagCostCenterValue;$tagCriticalityName=$tagCriticalityValue}

Write-Host ($writeEmptyLine + "# Specified set of tags available to add" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine 

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Create a resource group for the File Share resources if it does not already exist. Also apply the necessary tags to this resource group

try {
    Get-AzResourceGroup -Name $rgNameStorage -ErrorAction Stop | Out-Null 
} catch {
    New-AzResourceGroup -Name $rgNameStorage -Location $region -Force | Out-Null 
}

# Save variable tags in a new variable to add tags.
$tagsResourceGroup = $tags

# Add Purpose tag to tagsResourceGroup.
$tagsResourceGroup += @{$tagPurposeName = "Storage"}

# Set tags rg storage.
Set-AzResourceGroup -Name $rgNameStorage -Tag $tagsResourceGroup | Out-Null

Write-Host ($writeEmptyLine + "# Resource group $rgNameStorage available" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Create a general-purpose v2 storage account for the File Share with specific configuration settings if it does not already exist. Also apply the necessary tags to this storage account

# If you require a large file share (up to 100 TiB), you must add the "-EnableLargeFileShare parameter" at the end of the New-AzStorageAccount cmdlet
# Keep in mind that you cannot use this with a geo-redundant or geo-zone-redundant storage account

# If you require Azure Files AAD DS Authentication, you must add "-EnableAzureActiveDirectoryDomainServicesForFile $true" at the end of the New-AzStorageAccount cmdlet

try {
    Get-AzStorageAccount -ResourceGroupName $rgNameStorage -Name $storageAccountName -ErrorAction Stop | Out-Null 
} catch {
    New-AzStorageAccount -ResourceGroupName $rgNameStorage -Name $storageAccountName -SkuName $storageAccountSkuName -Location $region -Kind $storageAccountType `
    -AllowBlobPublicAccess $false -AllowSharedKeyAccess $false -MinimumTlsVersion $storageMinimumTlsVersion | Out-Null 
}

# Save variable tags in a new variable to add tags
$tagsStorageAccount = $tags

# Add Purpose tag to tags for the storage account
$tagsStorageAccount += @{$tagPurposeName = $tagPurposeValue}

# Add Sku tag to tags for the storage account
$tagsStorageAccount += @{$tagSkuName = $tagSkuValue}

# Set tags storage account
Set-AzStorageAccount -ResourceGroupName $rgNameStorage -Name $storageAccountName -Tag $tagsStorageAccount | Out-Null

Write-Host ($writeEmptyLine + "# Storage account $storageAccountName created" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Create an Azure file share if it does not exist. Also apply the necessary meta data to this file share

try {
    Get-AzRmStorageShare -ResourceGroupName $rgNameStorage -StorageAccountName $storageAccountName -Name $fileShareName -ErrorAction Stop | Out-Null 
} catch {
    New-AzRmStorageShare -ResourceGroupName $rgNameStorage -StorageAccountName $storageAccountName -Name $fileShareName -AccessTier $fileShareAccessTier `
    -QuotaGiB $fileShareQuotaGiB | Out-Null

    # Enable soft delete
    Update-AzStorageFileServiceProperty -ResourceGroupName $rgNameStorage -StorageAccountName $storageAccountName -EnableShareDeleteRetentionPolicy $true `
    -ShareRetentionDays $fileShareDeleteRetentionPolicy | Out-Null
}

# Save variable tags in a new variable to add tags
$tagsFileShare = $tags

# Add Purpose tag to the tags for the file share
$tagsFileShare += @{$tagPurposeName = $tagPurposeValue}

# Set Metadata file share
Update-AzRmStorageShare -ResourceGroupName $rgNameStorage -StorageAccountName $storageAccountName -Name $fileShareName -Metadata $tagsFileShare | Out-Null

Write-Host ($writeEmptyLine + "# Azure file share $fileShareName created" + $writeSeperatorSpaces + $currentTime)`
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

## Set the log and metrics settings for the file share if they don't exist

$fileShare = Get-AzRmStorageShare -ResourceGroupName $rgNameStorage -StorageAccountName $storageAccountName -Name $fileShareName

try {
    Get-AzDiagnosticSetting -Name $fileShareDiagnosticsName -ResourceId ($storageAccount.Id) -ErrorAction Stop | Out-Null
} catch { 
    $metric = @()
    $metric += New-AzDiagnosticSettingMetricSettingsObject -Enabled $true -Category AllMetrics
    $log = @()
    $log += New-AzDiagnosticSettingLogSettingsObject -Enabled $true -Category StorageRead
    $log += New-AzDiagnosticSettingLogSettingsObject -Enabled $true -Category StorageWrite
    $log += New-AzDiagnosticSettingLogSettingsObject -Enabled $true -Category StorageDelete
    New-AzDiagnosticSetting -Name $fileShareDiagnosticsName -ResourceId ($storageAccount.Id + "/fileServices/default")`
    -WorkspaceId ($workSpace.ResourceId) -Log $log -Metric $metric | Out-Null
    # "/blobServices/default" "/queueServices/default" "/tableServices/default"
}

Write-Host ($writeEmptyLine + "# File share $fileShareName diagnostic settings set" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Write script completed

Write-Host ($writeEmptyLine + "# Script completed" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor1 $writeEmptyLine 

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


