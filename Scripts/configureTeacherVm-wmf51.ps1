if(Test-Path "C:\Program Files (x86)") {
    if ($PSVersionTable.PSVersion.Major -lt 5 -and $PSVersionTable.PSVersion.Minor -lt 1) {
        Write-Output "Attempting to install required features..."
        .\Win8.1AndW2K12R2-KB3191564-x64.msu /quiet /norestart
        Write-Output "WMF 5.1 installed. Restarting system..."
        Restart-Computer -Force -Confirm:$false
    } else {
        Write-Output "The current version of PowerShell is newer or equal to 5.1."
    }
} else {
    Write-Output "32 bit operating system detected. Unable to proceed."
}
