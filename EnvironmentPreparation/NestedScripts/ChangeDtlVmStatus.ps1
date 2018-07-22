workflow ChangeDtlVmStatus
{

    param (

        [string]$ResourceGroupName,
        [String]$Action

    )



    $connectionName = "AzureRunAsConnection"
    try
    {
        # Get the connection "AzureRunAsConnection "
        $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         

        Write-Verbose "Logging in to Azure..."
        Add-AzureRmAccount `
            -ServicePrincipal `
            -TenantId $servicePrincipalConnection.TenantId `
            -ApplicationId $servicePrincipalConnection.ApplicationId `
            -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
    }
    catch {
        if (!$servicePrincipalConnection)
        {
            $ErrorMessage = "Connection $connectionName not found."
            throw $ErrorMessage
        } else{
            Write-Error -Message $_.Exception
            throw $_.Exception
        }
    }

    #Get Students' VM and start them
    if ($(Get-Module -Name AzureRM.Resources).Version.Major -eq 6) {
        $dtlVms = Get-AzureRmResource -ResourceType 'Microsoft.DevTestLab/labs/virtualMachines' -ResourceGroupName $ResourceGroupName
    } else {
        $dtlVms = Find-AzureRmResource -ResourceType 'Microsoft.DevTestLab/labs/virtualMachines' -ResourceGroupName $ResourceGroupName
    }

    Write-Verbose $dtlVms

    $returnStatus = @()

    foreach -parallel ($dtlVm in $dtlVms) {

        $ret = inlineScript {
            Import-Module AzureRm.Resources

            Invoke-AzureRmResourceAction `
                -ResourceId $USING:dtlVm.ResourceId `
                -Action $USING:Action `
                -Force
        }

        Write-Verbose $ret

        $WORKFLOW:returnStatus += [ordered]@{
            'Name' = $($dtlVm.Name);
            'Action' = $action;
            'Status' = $($ret.Status);
        }
    }

    $returnStatus
}