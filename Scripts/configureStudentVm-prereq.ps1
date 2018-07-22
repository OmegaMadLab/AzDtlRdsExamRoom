[CmdletBinding()]

param (
    [string]$TeacherVmIp,

    [Parameter(Mandatory)]
    [string] $DomainAdminName
)

Import-Module ServerManager

# Configure AADDS Admin as local admin
Add-LocalGroupMember -Group "Administrators" -Member $DomainAdminName

#Add entry for ExamRoom = Teacher VM IP in hosts
$Hosts = Get-Item "$env:SYSTEMROOT\system32\Drivers\etc\hosts"
$Hosts | Add-Content -value "`nExamRoom`t$TeacherVmIp"


#Install RDS Features
Install-WindowsFeature -Name 'RDS-RD-Server' -IncludeAllSubFeature -IncludeManagementTools -Restart