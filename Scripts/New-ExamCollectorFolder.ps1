Install-Module AzureAD -SkipPublisherCheck -Force -Confirm:$false

$credential = Get-Credential -UserName m.obinu@softjam.it -Message "Insert pwd"
Connect-AzureAD -TenantId 59cd34ab-6571-4047-a606-761355fe6d92 -Credential $credential

Get-AzureADGroupMember -ObjectId 26839339-943c-454f-be9e-180cbc68ca6a | fl

Get-AzureADUserMembership -ObjectId 26839339-943c-454f-be9e-180cbc68ca6a 



$users = @()
$users += 'student1@sj.local'
$users += 'student2@sj.local'
$users += 'student3@sj.local'
$users += 'student4@sj.local'


#$folder = New-Item 'Cartella' -ItemType Directory
$folder = Get-Item "Cartella"

Install-PackageProvider -Name NuGet -Force -MinimumVersion 2.8.5.201
Install-Module -Name NTFSSecurity -Force -Confirm:$false



foreach($user in $users) {
    $subfolder = New-Item -Path "$($folder.FullName)\$user" -ItemType Directory
    $subfolder | Disable-NTFSAccessInheritance
    Add-NTFSAccess $subfolder -Account $user -AccessRights Modify
    Get-NTFSAccess $subfolder -Account "SJ\UsersSJ" | Remove-NTFSAccess
}
