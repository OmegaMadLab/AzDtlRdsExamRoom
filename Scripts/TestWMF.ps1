Install-PackageProvider -Name NuGet -Force -Verbose
Install-Module AzureAD -SkipPublisherCheck -Force -Confirm:$false -Verbose
Install-Module -Name NTFSSecurity -Force -Confirm:$false -Verbose