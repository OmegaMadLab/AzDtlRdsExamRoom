param (
    [string] $DomainName,
    [string] $StudentVmPrefix,
    [int] $StudentVmNumber    
)

Import-Module RemoteDesktop

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

#Test
Invoke-Command -ComputerName 'VMTestSJ00' -ScriptBlock { hostname }

#Create a basic RDS deployment
$RdsParams = @{
    ConnectionBroker = $RdsBrokerSrv;
    WebAccessServer = $RdsWebAccessSrv;
    SessionHost = $RdsHosts;
}

New-SessionDeployment @RdsParams

#Configure Licensing
$RdsLicParams = @{
    LicenseServer = $RdsLicenseSrv;
    Mode = "PerUser";
    ConnectionBroker = $RdsBrokerSrv;
    Force = $true;
}
Set-RDLicenseConfiguration @RdsLicParams

#Create collection
$RdsCollParams = @{
    CollectionName = "ExamRoom";
    CollectionDescription = "Exam Room"
    SessionHost = $RdsHosts;
    ConnectionBroker = $RdsBrokerSrv
}
New-RDSessionCollection @RdsCollParams

###Configure Server Manager
#.\SetServerManager.ps1 -DomainName $env:USERDNSDOMAIN -RdsVm $env:COMPUTERNAME -StudentVmPrefix $StudentVmPrefix -StudentVmNumber $StudentVmNumber