param (
    [Parameter(Mandatory)]
    [string] $DomainName,

    [Parameter(Mandatory)]
    [string] $DomainAdminName,

    [Parameter(Mandatory)]
    [string] $DomainAdminPassword,

    [Parameter(Mandatory)]
    [string] $StudentVmPrefix,
    
    [Parameter(Mandatory)]
    [int] $StudentVmNumber,

    [Parameter(Mandatory)]
    [int] $ExamRoomNumber
)

$securePass = ConvertTo-SecureString $DomainAdminPassword -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential ($DomainAdminName, $securePass)

# Configure AADDS Admin as local admin
Add-LocalGroupMember -Group "Administrators" -Member $DomainAdminName

### Configure RDS base deployment
#Compose Student VMs array
$RdsHosts = @()
for ($i = 0; $i -lt $StudentVmNumber; $i++) {
    $VmIndex = ($i.ToString()).PadLeft(2,"0")
    $RdsHosts += "$StudentVmPrefix$VmIndex.$DomainName"
}

#Define RDS Roles servername
$RdsBrokerSrv = "$env:COMPUTERNAME.$DomainName"
$RdsLicenseSrv = "$env:COMPUTERNAME.$DomainName"
$RdsWebAccessSrv ="$env:COMPUTERNAME.$DomainName"


# Create a basic RDS deployment
$ScriptBlock = {

    param(
        $RdsHosts,
        $RdsBroker,
        $RdsLic,
        $RdsWA
    )

    Import-Module RemoteDesktop

    Write-Output "Creating RDS deployment..." | Out-File -FilePath 'C:\WINDOWS\Temp\rds_deployment.log' -Append
    
    $RdsParams = @{
        ConnectionBroker = $RdsBroker;
        WebAccessServer = $RdsWA;
        SessionHost = $RdsHosts;
    }
    New-RDSessionDeployment @RdsParams -Verbose
    
    Write-Output "RDS created" | Out-File -FilePath 'C:\WINDOWS\Temp\rds_deployment.log' -Append

    # Configure Licensing
    Write-Output "Configuring RDS licensing..." | Out-File -FilePath 'C:\WINDOWS\Temp\rds_deployment.log' -Append

    $RdsLicParams = @{
        LicenseServer = $RdsLic;
        Mode = "PerUser";
        ConnectionBroker = $RdsBroker;
        Force = $true;
    }
    Set-RDLicenseConfiguration @RdsLicParams -Verbose

    Write-Output "RDS licensing configured" | Out-File -FilePath 'C:\WINDOWS\Temp\rds_deployment.log' -Append

    # Create collection

    Write-Output "Creating RDS collection..." | Out-File -FilePath 'C:\WINDOWS\Temp\rds_deployment.log' -Append
    
    $RdsCollParams = @{
        CollectionName = "ExamRoom";
        CollectionDescription = "Exam Room"
        SessionHost = $RdsHosts;
        ConnectionBroker = $RdsBroker;
    }
    New-RDSessionCollection @RdsCollParams -Verbose

    Write-Output "Creating RDS collection..." | Out-File -FilePath 'C:\WINDOWS\Temp\rds_deployment.log' -Append
}

# Execute RDS farm creation scriptblock with domain credentials
$PsSession = New-PSSession -ComputerName $env:COMPUTERNAME -Credential $Credential -Authentication Credssp

Invoke-Command -Session $PsSession -ScriptBlock $ScriptBlock -ArgumentList ($RdsHosts, $RdsBrokerSrv, $RdsLicenseSrv, $RdsWebAccessSrv) -Verbose

# Compose ServerManager xml file in a temp location
./New-ServerManagerConfig -DomainName $DomainName -RdsVm $env:COMPUTERNAME -StudentVmPrefix $StudentVmPrefix -StudentVmNumber $StudentVmNumber

Copy-Item "./Set-ServerManagerConfig.ps1" -Destination "C:\ServerManagerConfig\Set-ServerManagerConfig.ps1" -Force

# Create a scheduled task to copy ServerManager xml file from temp location to the user profile folder.
# This script will be executed for each connecting user at logon
$ScriptBlock = {

    param(
        [String]$UserName
    )

    Write-Output "Creating scheduled task to configure Server Manager..." | Out-File -FilePath 'C:\WINDOWS\Temp\rds_deployment.log' -Append

    $action = New-ScheduledTaskAction -Execute 'C:\windows\system32\WindowsPowerShell\v1.0\powershell.exe' `
        -Argument '-ExecutionPolicy Unrestricted -File C:\ServerManagerConfig\Set-ServerManagerConfig.ps1'
    $trigger =  New-ScheduledTaskTrigger -AtLogOn
    $principal = New-ScheduledTaskPrincipal -UserId $UserName -LogonType S4U -RunLevel Highest

    Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "LoadServerManagerConfig" -Description "Update server manager config at logon" -Principal $principal

    Write-Output "Creating scheduled task to configure Server Manager..." | Out-File -FilePath 'C:\WINDOWS\Temp\rds_deployment.log' -Append

}

Invoke-Command -Session $PsSession -ScriptBlock $ScriptBlock -ArgumentList ($DomainAdminName) -Verbose

# Installing PS Modules for AAD and NTFS permission management
Write-Output "Installing required PS Modules..." | Out-File -FilePath 'C:\WINDOWS\Temp\rds_deployment.log' -Append
Install-PackageProvider -Name NuGet -Force -MinimumVersion 2.8.5.201
Install-Module AzureAD -SkipPublisherCheck -Force -Confirm:$false
Install-Module -Name NTFSSecurity -Force -Confirm:$false
Write-Output "Required PS Modules installed" | Out-File -FilePath 'C:\WINDOWS\Temp\rds_deployment.log' -Append

# Connect to AAD and get ExamRoom students from group membership
# Getting this info from AAD since replication interval from AAD to AADS may lead to improper group membership results
Write-Output "Connecting to AzureAD..." | Out-File -FilePath 'C:\WINDOWS\Temp\rds_deployment.log' -Append
Connect-AzureAD -Credential $Credential
Write-Output "Connected to AzureAD" | Out-File -FilePath 'C:\WINDOWS\Temp\rds_deployment.log' -Append

$AADStudentsGroupName = "ExamRoom0$ExamRoomNumber-Students"
$AADTeachersGroupName = "ExamRoom-Teachers"

Write-Output "Getting ExamRoom students and creating ExamResults folder structure..." | Out-File -FilePath 'C:\WINDOWS\Temp\rds_deployment.log' -Append
$Users = Get-AzureADGroup -SearchString $AADStudentsGroupName | Get-AzureADGroupMember | Select-Object UserPrincipalName, Mail

# Create an ExamResults folder with one subfolder for each student.
# Teachers and Admins will have R/W on all directory structures.
# Students' subfolders will have broked inheritance and each student will be able to R/W only on his folder
# Kept list folder permission for local users

$Folder = New-Item "C:\ExamResults" -ItemType Directory
Add-NTFSAccess $Folder -Account $AADTeachersGroupName -AccessRights Modify

foreach($user in $users) {
    if($user.UserPrincipalName -like '*#EXT#*') {
        $UserName = $user.Mail
    } else {
        $UserName = $user.UserPrincipalName
    }
    $subfolder = New-Item -Path "$($folder.FullName)\$UserName" -ItemType Directory
    $subfolder | Disable-NTFSAccessInheritance
    Add-NTFSAccess $subfolder -Account $UserName -AccessRights Modify
    Get-NTFSAccess $subfolder -Account "BUILTIN\Users" | Remove-NTFSAccess
    Add-NTFSAccess $subfolder -Account "BUILTIN\Users" -AccessRights ListDirectory
}

New-SmbShare -Path $Folder -Name "ExamResults" -FullAccess "Domain Users", "Domain Computers"
Write-Output "ExamResults folder structure created" | Out-File -FilePath 'C:\WINDOWS\Temp\rds_deployment.log' -Append

# Disable CredSSP to restore security settings
# Write-Output "Disabling CredSSP..." | Out-File -FilePath 'C:\WINDOWS\Temp\rds_deployment.log' -Append
# Disable-WSManCredSSP -Role Client
# Disable-WSManCredSSP -Role Server
# Write-Output "CredSSP disabled" | Out-File -FilePath 'C:\WINDOWS\Temp\rds_deployment.log' -Append
