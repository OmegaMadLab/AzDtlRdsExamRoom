configuration prepareADconsole
{
    param
    (
        [Parameter(Mandatory)]
        [String]$DomainName,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Admincreds,

        [String]$DomainNetbiosName=(Get-NetBIOSName -DomainName $DomainName),

        [Int]$RetryCount=20,
        [Int]$RetryIntervalSec=30
    )

    Import-DscResource -ModuleName xComputerManagement, xActiveDirectory, PSDesiredStateConfiguration
    [System.Management.Automation.PSCredential]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($Admincreds.UserName)", $Admincreds.Password)
    [System.Management.Automation.PSCredential]$DomainFQDNCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Admincreds.UserName)", $Admincreds.Password)

    $RebootVirtualMachine = $false

    if ($DomainName)
    {
        $RebootVirtualMachine = $true
    }

    Node localhost
    {
        WindowsFeature ADTools
        {
            Name = "RSAT-AD-Tools"
            Ensure = "Present"
        }

        WindowsFeature GPOConsole
        {
            Name = "GPMC"
            Ensure = "Present"
        }

        xWaitForADDomain DscForestWait 
        { 
            DomainName = $DomainName 
            DomainUserCredential= $DomainCreds
            RetryCount = $RetryCount 
            RetryIntervalSec = $RetryIntervalSec 
	        DependsOn = "[WindowsFeature]ADTools"
        }
        
        xComputer DomainJoin
        {
            Name = $env:COMPUTERNAME
            DomainName = $DomainName
            Credential = $DomainCreds
	        DependsOn = "[xWaitForADDomain]DscForestWait"
        }

        Registry CredSSP1 {
            Ensure = "Present"
            Key = "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation"
            ValueName = "AllowFreshCredentials"
            ValueData = "1"
            ValueType = "Dword"
        }

        Registry CredSSP2 {
            Ensure = "Present"
            Key = "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentials"
            ValueName = "1"
            ValueData = "WSMAN/*.$DomainName"
            ValueType = "String"
            DependsOn = "[Registry]CredSSP1"
        }

        LocalConfigurationManager 
        {
            RebootNodeIfNeeded = $true
        }

    }
}
function Get-NetBIOSName
{ 
    [OutputType([string])]
    param(
        [string]$DomainName
    )

    if ($DomainName.Contains('.')) {
        $length=$DomainName.IndexOf('.')
        if ( $length -ge 16) {
            $length=15
        }
        return $DomainName.Substring(0,$length)
    }
    else {
        if ($DomainName.Length -gt 15) {
            return $DomainName.Substring(0,15)
        }
        else {
            return $DomainName
        }
    }
}
