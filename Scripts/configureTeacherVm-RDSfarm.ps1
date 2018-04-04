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

#Test
Invoke-Command -ComputerName 'VMTestSJ00' -ScriptBlock { hostname } -Credential $Credential

#Create a basic RDS deployment
$ScriptBlock = {
    
    Import-Module RemoteDesktop

    $RdsParams = @{
        ConnectionBroker = $using:RdsBrokerSrv;
        WebAccessServer = $using:RdsWebAccessSrv;
        SessionHost = $using:RdsHosts;
    }

    New-SessionDeployment @RdsParams

    #Configure Licensing
    $RdsLicParams = @{
        LicenseServer = $using:RdsLicenseSrv;
        Mode = "PerUser";
        ConnectionBroker = $using:RdsBrokerSrv;
        Force = $true;
    }
    Set-RDLicenseConfiguration @RdsLicParams

    #Create collection
    $RdsCollParams = @{
        CollectionName = "ExamRoom";
        CollectionDescription = "Exam Room"
        SessionHost = $using:RdsHosts;
        ConnectionBroker = $using:RdsBrokerSrv;
    }
    New-RDSessionCollection @RdsCollParams
}

Invoke-Command -ComputerName $env:COMPUTERNAME -Credential $Credential -ScriptBlock $ScriptBlock



###Configure Server Manager
#.\SetServerManager.ps1 -DomainName $env:USERDNSDOMAIN -RdsVm $env:COMPUTERNAME -StudentVmPrefix $StudentVmPrefix -StudentVmNumber $StudentVmNumber