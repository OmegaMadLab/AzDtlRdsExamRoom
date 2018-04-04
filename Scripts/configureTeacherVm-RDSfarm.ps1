param (
    [string] $DomainName,
    [string] $DomainAdminName,
    [string] $DomainAdminPassword,
    [string] $StudentVmPrefix,
    [int] $StudentVmNumber    
)

$securePass = ConvertTo-SecureString $DomainAdminPassword -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential ($DomainAdminName, $securePass)

###Configure RDS base deployment
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


#Create a basic RDS deployment
$ScriptBlock = {

    param(
        $RdsHosts,
        $RdsBroker,
        $RdsLic,
        $RdsWA
    )

    Import-Module RemoteDesktop

    $RdsParams = @{
        ConnectionBroker = $RdsBroker;
        WebAccessServer = $RdsWA;
        SessionHost = $RdsHosts;
    }

    New-RDSessionDeployment @RdsParams -Verbose

    #Configure Licensing
    $RdsLicParams = @{
        LicenseServer = $RdsLic;
        Mode = "PerUser";
        ConnectionBroker = $RdsBroker;
        Force = $true;
    }
    Set-RDLicenseConfiguration @RdsLicParams -Verbose

    #Create collection
    $RdsCollParams = @{
        CollectionName = "ExamRoom";
        CollectionDescription = "Exam Room"
        SessionHost = $RdsHosts;
        ConnectionBroker = $RdsBroker;
    }
    New-RDSessionCollection @RdsCollParams -Verbose
}

$PsSession = New-PSSession -ComputerName $env:COMPUTERNAME -Credential $Credential -Authentication Credssp

Invoke-Command -Session $PsSession -ScriptBlock $ScriptBlock -ArgumentList ($RdsHosts, $RdsBrokerSrv, $RdsLicenseSrv, $RdsWebAccessSrv) -Verbose

./New-ServerManagerConfig -DomainName $DomainName -RdsVm $env:COMPUTERNAME -StudentVmPrefix $StudentVmPrefix -StudentVmNumber $StudentVmNumber

Copy-Item "./Set-ServerManagerConfig.ps1" -Destination "C:\ServerManagerConfig\Set-ServerManagerConfig.ps1" -Force

$action = New-ScheduledTaskAction -Execute 'C:\windows\system32\WindowsPowerShell\v1.0\powershell.exe' `
    -Argument '-ExecutionPolicy Unrestricted -File C:\ServerManagerConfig\Set-ServerManagerConfig.ps1'
$trigger =  New-ScheduledTaskTrigger -AtLogOn
$principal = New-ScheduledTaskPrincipal -LogonType S4U -RunLevel Highest
Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "LoadServerManagerConfig" -Description "Update server manager config at logon" -Principal $principal