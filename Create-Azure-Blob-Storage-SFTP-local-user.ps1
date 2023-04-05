<#
.SYNOPSIS

A script used to create an Azure Blob Storage with SSH File Transfer Protocol (SFTP) enabled.

.DESCRIPTION

A script used to create an Azure Blob Storage with SSH File Transfer Protocol (SFTP) enabled.
This script will do all of the following:

Remove the breaking change warning messages.
Create the C:\Temp folder if it does not already exist
Change the current context to the specified subscription.
Create the local user.
Export SSH Password to txt file in C:\Temp folder.

.NOTES

Filename:       Create-Azure-Blob-Storage-SFTP-local-user.ps1
Created:        04/04/2023
Last modified:  04/04/2023
Author:         Wim Matthyssen
Version:        1.0
PowerShell:     Azure PowerShell and Azure Cloud Shell
Requires:       PowerShell Az (v9.4.0)
Action:         Change variables were needed to fit your needs. 
Disclaimer:     This script is provided "as is" with no warranties.

.EXAMPLE

Connect-AzAccount
Get-AzTenant (if not using the default tenant)
Set-AzContext -tenantID "xxxxxxxx-xxxx-xxxx-xxxxxxxxxxxx" (if not using the default tenant)
.\Create-Azure-Blob-Storage-SFTP -SubscriptionName <"your Azure subscription name here"> -UserName <"your local user name here"> -ContainerName <"your storage acocunt container name here">

-> .\Create-Azure-Blob-Storage-SFTP-local-user.ps1 -SubscriptionName sub-prd-myh-corp-01 -ContainerName file-upload -userName wmsftp01

.LINK


#>

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Parameters

param(
    # $subscriptionName -> Name of the Azure Subscription
    [parameter(Mandatory =$true)][ValidateNotNullOrEmpty()] [string] $subscriptionName,
    # $containerName -> Name of the container
    [parameter(Mandatory =$true)][ValidateNotNullOrEmpty()] [string] $containerName,
    # $userName -> Name of the user
    [parameter(Mandatory =$true)][ValidateNotNullOrEmpty()] [string] $userName
)

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Variables

$tempFolderName = "Temp"
$tempFolder = "C:\" + $tempFolderName +"\"
$itemType = "Directory"

$rgNameStorage = #<your storage account resource group name here> The name of the Azure resource group in which your new or existing storage account is deployed. Example: "rg-hub-myh-storage-01"
$storageAccountName = #<your storage account name here> The name of your new storage account. Example: "stprdmyhsftp01"

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

## Create the C:\Temp folder if it does not already exist

If(!(test-path $tempFolder))
{
New-Item -Path "C:\" -Name $tempFolderName -ItemType $itemType -Force | Out-Null
}

Write-Host ($writeEmptyLine + "# $tempFolderName folder available" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Change the current context to the specified subscription

$subName = Get-AzSubscription | Where-Object {$_.Name -like $subscriptionName}

Set-AzContext -SubscriptionId $subName.SubscriptionId | Out-Null 

Write-Host ($writeEmptyLine + "# Specified subscription in current tenant selected" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Create the local user

$permissionScope1 = New-AzStorageLocalUserPermissionScope -Permission wl -Service blob -ResourceName $containerName 

Set-AzStorageLocalUser -ResourceGroupName $rgNameStorage -AccountName $storageAccountName -UserName $userName -HasSshPassword $true `
-HomeDirectory $containerName -PermissionScope $permissionScope1 | Out-Null 

# Regenerate the SSH password of the specified local user
$sshPassword = New-AzStorageLocalUserSshPassword -ResourceGroupName $rgNameStorage -AccountName $storageAccountName -UserName $userName

Write-Host ($writeEmptyLine + "# Local user $userName created with SSH Password and required container permissions" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine 

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Export the SSH Password to txt file in C:\Temp folder

$sshPassword | Out-File C:\Temp\$userName.txt

Write-Host ($writeEmptyLine + "# SSH Password exported to $userName.txt in the C:\Temp folder" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine 

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Write script completed

Write-Host ($writeEmptyLine + "# Script completed" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor1 $writeEmptyLine 

## --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- 