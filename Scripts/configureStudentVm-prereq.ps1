Import-Module ServerManager

#Install RDS Features
Install-WindowsFeature -Name 'RDS-RD-Server' -IncludeAllSubFeature -IncludeManagementTools -Restart