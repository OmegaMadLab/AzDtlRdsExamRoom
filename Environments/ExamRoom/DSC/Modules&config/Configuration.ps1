configuration DomainJoin 
{ 
   param 
    ( 
        [Parameter(Mandatory)]
        [String]$domainName,

        [String]$ouPath,

        [Parameter(Mandatory)]
        [PSCredential]$adminCreds
    ) 
    
    Import-DscResource -ModuleName xActiveDirectory, xComputerManagement

    $username = $adminCreds.UserName -split '\\' | select -last 1
    $domainCreds = New-Object System.Management.Automation.PSCredential ("$($username)@$($domainName)", $adminCreds.Password)
           
    Node localhost
    {
        LocalConfigurationManager
        {
            RebootNodeIfNeeded = $true
        }

        WindowsFeature ADPowershell
        {
            Name = "RSAT-AD-PowerShell"
            Ensure = "Present"
        }

        if($ouPath) {

            xComputer DomainJoin
            {
                Name = $env:COMPUTERNAME
                DomainName = $domainName
                Credential = $domainCreds
                JoinOU = $ouPath
                DependsOn = "[WindowsFeature]ADPowershell"
            }
        }
        else {

            xComputer DomainJoin
            {
                Name = $env:COMPUTERNAME
                DomainName = $domainName
                Credential = $domainCreds
                DependsOn = "[WindowsFeature]ADPowershell"
            }

        }
   }
}

configuration ServerManagerConfig {

    param (
        [Parameter(Mandatory)]
        [PSCredential]$adminCreds
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xActiveDirectory, xComputerManagement

    $username = $adminCreds.UserName -split '\\' | select -last 1
    $domainCreds = New-Object System.Management.Automation.PSCredential ("$($username)@$($domainName)", $adminCreds.Password)

    $PsScript = @"
if(-not (Test-Path "`$env:APPDATA\Microsoft\Windows\ServerManager")) {
    New-Item -Path "`$env:APPDATA\Microsoft\Windows\ServerManager" -ItemType Directory
}
Copy-Item "C:\ServerManagerConfig\ServerList.xml" -Destination "`$env:APPDATA\Microsoft\Windows\ServerManager\ServerList.xml" -Force -Confirm:`$false
"@

    File PsScript
    {
        Ensure = "Present"
        DestinationPath = "C:\ServerManagerConfig\ServerManagerConfigLoad.ps1"
        Contents = $PsScript
        Force = $true
    }   

    xScheduledTask ServerManagerConfigLoad
    {
        DependsOn = "[File]PsScript"
        Ensure = "Present"
        TaskName = "ServerManagerConfigLoad"
        ScheduleType = "AtLogOn"
        Enable = $true
        ExecuteAsCredential = $domainCreds
        ActionExecutable   = "C:\windows\system32\WindowsPowerShell\v1.0\powershell.exe"
        ActionArguments = "-ExecutionPolicy Unrestricted -File C:\ServerManagerConfig\ServerManagerConfigLoad.ps1"
    }
}

configuration SessionHost
{
   param 
    ( 
        [Parameter(Mandatory)]
        [String]$domainName,

        [String]$ouPath,

        [Parameter(Mandatory)]
        [PSCredential]$adminCreds
    ) 

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xActiveDirectory, xComputerManagement

    Node localhost
    {
        LocalConfigurationManager
        {
            RebootNodeIfNeeded = $true
            ConfigurationMode = "ApplyOnly"
        }

        DomainJoin DomainJoin
        {
            domainName = $domainName
            ouPath = $ouPath
            adminCreds = $adminCreds 
        }

        WindowsFeature RDS-RD-Server
        {
            Ensure = "Present"
            Name = "RDS-RD-Server"
        }
    }
}

configuration RDSConsole
{
   param 
    ( 
        [Parameter(Mandatory)]
        [String]$domainName,

        [String]$ouPath,

        [Parameter(Mandatory)]
        [PSCredential]$adminCreds
    ) 

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xActiveDirectory, xComputerManagement

    Node localhost
    {
        LocalConfigurationManager
        {
            RebootNodeIfNeeded = $true
            ConfigurationMode = "ApplyOnly"
        }

        DomainJoin DomainJoin
        {
            domainName = $domainName
            ouPath = $ouPath
            adminCreds = $adminCreds 
        }

        WindowsFeature RSAT-RDS-Tools
        {
            Ensure = "Present"
            Name = "RSAT-RDS-Tools"
            IncludeAllSubFeature = $true
        }

        ServerManagerConfig LoadConfig {
            adminCreds = $adminCreds
        }
        
    }
}

configuration RDSDeployment
{
   param 
    ( 
        [Parameter(Mandatory)]
        [String]$domainName,

        [String]$ouPath,

        [Parameter(Mandatory)]
        [PSCredential]$adminCreds,

        # Connection Broker Node name
        [String]$connectionBroker,
        
        # Web Access Node name
        [String]$webAccessServer,

        # Gateway external FQDN
        [String]$externalFqdn,
        
        # RD Session Host count and naming prefix
        [Int]$numberOfRdshInstances = 1,
        [String]$sessionHostNamingPrefix = "SessionHost-",

        # Collection Name
        [String]$collectionName,

        # Connection Description
        [String]$collectionDescription

    ) 

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xActiveDirectory, xComputerManagement, xRemoteDesktopSessionHost
   
    $localhost = [System.Net.Dns]::GetHostByName((hostname)).HostName

    $username = $adminCreds.UserName -split '\\' | select -last 1
    $domainCreds = New-Object System.Management.Automation.PSCredential ("$($username)@$($domainName)", $adminCreds.Password)

    if (-not $connectionBroker)   { $connectionBroker = $localhost }
    if (-not $webAccessServer)    { $webAccessServer  = $localhost }

    if ($sessionHostNamingPrefix)
    { 
        $sessionHosts = @( 1..($numberOfRdshInstances) | % { $sessionHostNamingPrefix + $_.ToString("D3") + "." + $domainname } )
    }
    else
    {
        $sessionHosts = @( $localhost )
    }

    if (-not $collectionName)         { $collectionName = "Desktop Collection" }
    if (-not $collectionDescription)  { $collectionDescription = "A sample RD Session collection up in cloud." }


    Node localhost
    {
        LocalConfigurationManager
        {
            RebootNodeIfNeeded = $true
            ConfigurationMode = "ApplyOnly"
        }

        DomainJoin DomainJoin
        {
            domainName = $domainName
            ouPath = $ouPath
            adminCreds = $adminCreds 
        }

        WindowsFeature RSAT-RDS-Tools
        {
            Ensure = "Present"
            Name = "RSAT-RDS-Tools"
            IncludeAllSubFeature = $true
        }

        WindowsFeature RDS-Gateway
        {
            Ensure = "Present"
            Name = "RDS-Gateway"
        }

        WindowsFeature RDS-Web-Access
        {
            Ensure = "Present"
            Name = "RDS-Web-Access"
        }

        Registry RdmsEnableUILog
        {
            Ensure = "Present"
            Key = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\RDMS"
            ValueName = "EnableUILog"
            ValueType = "Dword"
            ValueData = "1"
        }
 
        Registry EnableDeploymentUILog
        {
            Ensure = "Present"
            Key = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\RDMS"
            ValueName = "EnableDeploymentUILog"
            ValueType = "Dword"
            ValueData = "1"
        }
 
        Registry EnableTraceLog
        {
            Ensure = "Present"
            Key = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\RDMS"
            ValueName = "EnableTraceLog"
            ValueType = "Dword"
            ValueData = "1"
        }
 
        Registry EnableTraceToFile
        {
            Ensure = "Present"
            Key = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\RDMS"
            ValueName = "EnableTraceToFile"
            ValueType = "Dword"
            ValueData = "1"
        }

        WindowsFeature RDS-Licensing
        {
            Ensure = "Present"
            Name = "RDS-Licensing"
        }

        xRDSessionDeployment Deployment
        {
            DependsOn = "[DomainJoin]DomainJoin", "[WindowsFeature]RDS-Web-Access", "[WindowsFeature]RDS-Gateway"

            ConnectionBroker = $connectionBroker
            WebAccessServer  = $webAccessServer

            SessionHosts     = $sessionHosts

            PsDscRunAsCredential = $domainCreds
        }

        <#
        xRDServer AddLicenseServer
        {
            DependsOn = "[xRDSessionDeployment]Deployment"
            
            Role    = 'RDS-Licensing'
            Server  = $connectionBroker

            PsDscRunAsCredential = $domainCreds
        }
        #>

        xRDLicenseConfiguration LicenseConfiguration
        {
            #DependsOn = "[xRDServer]AddLicenseServer"
            DependsOn = "[xRDSessionDeployment]Deployment"

            ConnectionBroker = $connectionBroker
            LicenseServers   = @( $connectionBroker )

            LicenseMode = 'PerUser'

            PsDscRunAsCredential = $domainCreds
        }

        <#
        xRDServer AddGatewayServer
        {
            DependsOn = "[xRDLicenseConfiguration]LicenseConfiguration"
            
            Role    = 'RDS-Gateway'
            Server  = $webAccessServer

            GatewayExternalFqdn = $externalFqdn

            PsDscRunAsCredential = $domainCreds
        }
        #>

        xRDGatewayConfiguration GatewayConfiguration
        {
            #DependsOn = "[xRDServer]AddGatewayServer"
            DependsOn = "[xRDSessionDeployment]Deployment"

            ConnectionBroker = $connectionBroker
            GatewayServer    = $webAccessServer

            ExternalFqdn = $externalFqdn

            GatewayMode = 'DoNotUse'
            LogonMethod = 'Password'

            UseCachedCredentials = $true
            BypassLocal = $false

            PsDscRunAsCredential = $domainCreds
        } 
        

        xRDSessionCollection Collection
        {
            DependsOn = "[xRDGatewayConfiguration]GatewayConfiguration"

            ConnectionBroker = $connectionBroker

            CollectionName = $collectionName
            CollectionDescription = $collectionDescription
            
            SessionHosts = $sessionHosts

            PsDscRunAsCredential = $domainCreds
        }

        Registry DefaultCollection
        {
            DependsOn = "[xRDSessionCollection]Collection"
            Ensure = "Present"
            Key = "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server\ClusterSettings"
            ValueName = "DefaultTsvUrl"
            ValueType = "String"
            ValueData = "tsv://MS Terminal Services Plugin.1.$($CollectionName)"
        }

        ServerManagerConfig LoadConfig {
            adminCreds = $adminCreds
        }

    }
}