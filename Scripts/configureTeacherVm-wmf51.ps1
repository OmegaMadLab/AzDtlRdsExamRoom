if(Test-Path "C:\Program Files (x86)") {
    if ($PSVersionTable.PSVersion.Major -lt 5 -and $PSVersionTable.PSVersion.Minor -lt 1) {
        Write-Output "Attempting to install required features..."
        
        $process=".\Win8.1AndW2K12R2-KB3191564-x64.msu"
        $args="/quiet /norestart"
 
        Start-Process $process -ArgumentList $args -Wait

        Do {
            try {
                Get-Hotfix -id kb3191564 -ErrorAction Stop
                $found = $true
            }
            catch {
                $found = $false
            }
        } Until ($found)

        Write-Output "Setup completed. Restarting system..."
        Restart-Computer -Force -Confirm:$false
    } else {
        Write-Output "The current version of PowerShell is newer or equal to 5.1."
    }
} else {
    Write-Output "32 bit operating system detected. Unable to proceed."
}
