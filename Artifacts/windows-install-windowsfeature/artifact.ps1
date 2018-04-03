[CmdletBinding()]       
param
(
    [Parameter(Mandatory = $true)]
    [string] $windowsFeatureList,

    [Parameter(Mandatory = $true)]
    [bool] $includeSubFeatures,

    [Parameter(Mandatory = $true)]
    [bool] $includeManagementTools
)

##############################
# Install Windows Features
function install-WinFeature ()
{
    param
    (
        [Parameter(Mandatory = $true)]
        [string] $windowsFeatureList,
    
        [Parameter(Mandatory = $true)]
        [bool] $includeSubFeatures,
    
        [Parameter(Mandatory = $true)]
        [bool] $includeManagementTools
    )

    $RequiredFeatures = $WindowsFeatureList.split(',')

    foreach($RequiredFeature in $RequiredFeatures) {
        try {
            Install-WindowsFeature -Name $RequiredFeature -IncludeAllSubFeature:$includeSubFeatures -IncludeManagementTools:$includeManagementTools
        }
        catch {
            Write-Error $_.Exception
            Write-Error "Result: Failed to install required feature $RequiredFeature."
        }
    }

}

##############################
# Main function

if ($PSVersionTable.PSVersion.Major -lt 3)
{
    Write-Error "The current version of PowerShell is $($PSVersionTable.PSVersion.Major). Prior to running this artifact, ensure you have PowerShell 3 or higher installed."
}

else
{
    Write-Output "Attempting to install required features..."
    install-WinFeature -windowsFeatureList $windowsFeatureList -includeSubFeatures $includeSubFeatures -includeManagementTools $includeManagementTools
}


