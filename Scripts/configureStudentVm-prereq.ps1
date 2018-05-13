[CmdletBinding()]

param (
    [string]$TeacherVmIp
)

Import-Module ServerManager

#Add entry for ExamRoom = Teacher VM IP in hosts
$Hosts = Get-Item "$env:SYSTEMROOT\system32\Drivers\etc\hosts"
$Hosts | Add-Content -value "`nExamRoom`t$TeacherVmIp"


#Install RDS Features
Install-WindowsFeature -Name 'RDS-RD-Server' -IncludeAllSubFeature -IncludeManagementTools -Restart