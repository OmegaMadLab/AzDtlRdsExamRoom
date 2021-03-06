param (
    [string] $DomainName,
    [string] $RdsVm,
    [string] $StudentVmPrefix,
    [int] $StudentVmNumber    
)

[xml]$xml = @"
<?xml version="1.0" encoding="utf-8"?><ServerList xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" localhostName="" xmlns="urn:serverpool-schema"><ServerInfo name="" status="1" lastUpdateTime="2018-03-16T08:28:03.581998+00:00" locale="en-US" /></ServerList>
"@

#local machine
$xml.ServerList.localhostName = $env:COMPUTERNAME + '.' + $DomainName
$xml.ServerList.ServerInfo.name = $env:COMPUTERNAME + '.' + $DomainName

#RDS machine
if($env:COMPUTERNAME -ne $RdsVm) {
    $rdsServer = $xml.ServerList.ServerInfo.Clone()
    $rdsServer.name = $RdsVm + '.' + $DomainName
    $rdsServer.status = "2"

    $xml.ServerList.AppendChild($rdsServer)
}

#Students machines
1..($StudentVmNumber) | % {
    if($env:COMPUTERNAME -ne $RdsVm) {
        $StudentServer = $xml.ServerList.ServerInfo[0].Clone()
    }
    else {
        $StudentServer = $xml.ServerList.ServerInfo.Clone()
    }
    $StudentServer = $xml.ServerList.ServerInfo[0].Clone()
    $StudentServer.name = $StudentVmPrefix + $_.ToString("D3") + "." + $DomainName
    $xml.ServerList.AppendChild($StudentServer) }

if(!(Test-path("C:\ServerManagerConfig"))) {
        New-Item -Path "C:\ServerManagerConfig" -ItemType Directory
}
$xml.Save("C:\ServerManagerConfig\ServerList.xml")

