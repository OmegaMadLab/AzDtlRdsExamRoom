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
    
    Write-Output "RDSHosts:" $RdsHosts
    Write-Output "RDSBroker:" $RdsBroker
    Write-Output "RdsLic:" $RdsLic
    Write-Output "RdsWA:" $RdsWA

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

#Invoke-Command -Credential $Credential -ScriptBlock $ScriptBlock -ArgumentList ($RdsHosts, $RdsBrokerSrv, $RdsLicenseSrv, $RdsWebAccessSrv) -Verbose

$job = Start-Job -Credential $Credential -scriptblock $ScriptBlock -ArgumentList ($RdsHosts, $RdsBrokerSrv, $RdsLicenseSrv, $RdsWebAccessSrv) -Verbose

Receive-Job $job -Wait