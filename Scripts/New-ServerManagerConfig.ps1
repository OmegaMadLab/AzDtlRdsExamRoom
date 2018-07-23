param (
    [string] $DomainName,
    [string] $RdsVm,
    [string] $StudentVmPrefix,
    [int] $StudentVmNumber
)

[xml]$xml = @"
<?xml version="1.0" encoding="utf-8"?><ServerList xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" localhostName="" xmlns="urn:serverpool-schema"><ServerInfo name="" status="2" lastUpdateTime="0001-01-01T00:00:00" locale="en-US" /></ServerList>
"@

#local machine
$xml.ServerList.localhostName = $env:COMPUTERNAME + '.' + $DomainName
$xml.ServerList.ServerInfo.name = $env:COMPUTERNAME + '.' + $DomainName

#RDS machine
if($env:COMPUTERNAME -ne $RdsVm) {
    $rdsServer = $xml.ServerList.ServerInfo.Clone()
    $rdsServer.name = $RdsVm + '.' + $DomainName
    $rdsServer.status = "1"

    $xml.ServerList.AppendChild($rdsServer)
}

#Students machines
for ($i = 0; $i -lt $StudentVmNumber; $i++)
{ 
    if($i -gt 0) {
        $StudentServer = $xml.ServerList.ServerInfo[0].Clone()
    }
    else {
        $StudentServer = $xml.ServerList.ServerInfo.Clone()
    }
    $StudentServer.name = $StudentVmPrefix + '-Stdn' + $i.ToString("D2") + "." + $DomainName
    $xml.ServerList.AppendChild($StudentServer)
}

if(!(Test-path("C:\ServerManagerConfig"))) {
        New-Item -Path "C:\ServerManagerConfig" -ItemType Directory
}
$xml.Save("C:\ServerManagerConfig\ServerList.xml")

