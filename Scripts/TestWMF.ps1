Install-Module AzureAD -SkipPublisherCheck -Force -Confirm:$false
Install-PackageProvider -Name NuGet -Force -MinimumVersion 2.8.5.201
Install-Module -Name NTFSSecurity -Force -Confirm:$false