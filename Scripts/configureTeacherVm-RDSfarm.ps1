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

    New-RDSessionDeployment @RdsParams

    #Configure Licensing
    $RdsLicParams = @{
        LicenseServer = $RdsLic;
        Mode = "PerUser";
        ConnectionBroker = $RdsBroker;
        Force = $true;
    }
    Set-RDLicenseConfiguration @RdsLicParams

    #Create collection
    $RdsCollParams = @{
        CollectionName = "ExamRoom";
        CollectionDescription = "Exam Room"
        SessionHost = $RdsHosts;
        ConnectionBroker = $RdsBroker;
    }
    New-RDSessionCollection @RdsCollParams
}

Invoke-Command -ComputerName $env:COMPUTERNAME -Credential $Credential -ScriptBlock $ScriptBlock -ArgumentList ($RdsHosts, $RdsBrokerSrv, $RdsLicenseSrv, $RdsWebAccessSrv)
