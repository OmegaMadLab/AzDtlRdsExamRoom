[CmdLetBinding()]

param (
    [Parameter(Mandatory)]
    [string] $DomainName,

    [Parameter(Mandatory)]
    [string] $DomainAdminName,

    [Parameter(Mandatory)]
    [string] $DomainAdminPassword,

    [Parameter(Mandatory)]
    [string] $NumberOfExamRooms
)

#Create PSCredential
$securePass = ConvertTo-SecureString $DomainAdminPassword -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential ($DomainAdminName, $securePass)

$RestrictedGroupScriptBlock = {

    param(
        [string]$ExamRoomId,
        [string]$OuDN
    )

    #Set variables used for GPO
    $gPCMachineExtensionNamesGpoRestrictedGroups = "[{827D319E-6EAC-11D2-A4EA-00C04F79F83A}{803E14A0-B4FB-11D0-A0D0-00A0C90F574B}]"

    $GptTmpl = @'
[Unicode]
Unicode=yes
[Version]
signature="$CHICAGO$"
Revision=1
[Group Membership]
*S-1-5-32-555__Memberof =
*S-1-5-32-555__Members = *{0}
'@

    $GptIni = @"
[General]
Version=2
displayName=New Group Policy Object
"@

    Import-Module GroupPolicy

    #Create a Restricted Groups GPO for current ExamRoom
    $Gpo = New-GPO -Name "ExamRoom$ExamRoomId-Students-Permissions"

    #Get GPO object previously created
    $DomainNamingContext = ([adsi]"LDAP://RootDSE").rootDomainNamingContext
    $Searcher = New-Object -TypeName DirectoryServices.DirectorySearcher -Property @{
        Filter = "(displayname=$($Gpo.DisplayName))"
        SearchRoot = "LDAP://CN=Policies,CN=System,$DomainNamingContext"
    }
    $GpoObj = ($Searcher.FindOne()).GetDirectoryEntry()
    
    $GPCFileSysPath = $GpoObj.Properties.gpcfilesyspath -join ''
    
    #Create GptTmpl.inf to manage Restricted Groups
    $GptTmplPath = Join-Path -Path $GPCFileSysPath -ChildPath 'Machine\Microsoft\Windows NT\SecEdit'

    New-Item $GptTmplPath -ItemType Directory | Out-Null
    $SecFile = New-Item "$GptTmplPath\GptTmpl.inf" -ItemType File
    
    $objUser = New-Object System.Security.Principal.NTAccount($DomainName, "ExamRoom$ExamRoomId-Students")
    $strSID = $objUser.Translate([System.Security.Principal.SecurityIdentifier]) 
    
    $SecFileContent = $GptTmpl -f $strSID

    $SecFileContent | Out-File $SecFile -Encoding unicode
    $SecFile.Attributes = 'Hidden'

    #Update Gpt.ini
    $GptIni | Out-File (Join-Path -Path $GPCFileSysPath -ChildPath '\gpt.ini') -Encoding utf8

    #Set GPO MachineExtensionNames and version
    $GpoObj.Properties["gPCMachineExtensionNames"].Value = $gPCMachineExtensionNamesGpoRestrictedGroups
    $GpoObj.Properties["versionNumber"].Value = "2"
    $GpoObj.CommitChanges()

    #Wait and create GPO Link
    Start-Sleep 30
    New-GPLink -Guid $Gpo.Id -Target $OuDN -LinkEnabled Yes
}

$OtherGPOsScriptBlock = {

    Import-Module GroupPolicy, ActiveDirectory

    #Set variables used for GPOs
    $gPCUserExtensionNamesGppDrives = "[{827D319E-6EAC-11D2-A4EA-00C04F79F83A}{803E14A0-B4FB-11D0-A0D0-00A0C90F574B}]"

    $DrivesXml = @'
<?xml version="1.0" encoding="utf-8"?>
<Drives clsid="{8FDDCC1A-0C3C-43cd-A6B4-71A6DF20DA8C}">
    <Drive clsid="{935D1B74-9CB8-4e3c-9914-7DD559B7A417}" 
        name="Z:" 
        status="Z:" 
        image="0" 
        changed="2018-04-16 16:29:27" 
        uid="{EC980E45-C178-4B9D-B5BF-7BFD379EBD74}" 
        bypassErrors="1">
        <Properties action="C" 
            thisDrive="NOCHANGE" 
            allDrives="NOCHANGE" 
            userName="" 
            path="\\ExamRoom\ExamResults"
            label="Exam Results"
            persistent="1"
            useLetter="1"
            letter="Z"/>
    </Drive>
</Drives>
'@

    $GptIni = @"
[General]
Version=2
displayName=New Group Policy Object
"@

    #RDS Settings
    $GpoRds = New-Gpo -Name "ExamRoomAll-Students-RDS-settings"

    Set-GPRegistryValue -Guid $GpoRds.id -key "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -ValueName "fDisableAutoReconnect" -Type DWORD -value 0
    Set-GPRegistryValue -Guid $GpoRds.id -key "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -ValueName "fDisableForcibleLogoff" -Type DWORD -value 1
    Set-GPRegistryValue -Guid $GpoRds.id -key "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -ValueName "MaxInstanceCount" -Type DWORD -value 1
    Set-GPRegistryValue -Guid $GpoRds.id -key "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -ValueName "Shadow" -Type DWORD -value 4
    Set-GPRegistryValue -Guid $GpoRds.id -key "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -ValueName "fSingleSessionPerUser" -Type DWORD -value 1
    Set-GPRegistryValue -Guid $GpoRds.id -key "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -ValueName "fDisableCam" -Type DWORD -value 0
    Set-GPRegistryValue -Guid $GpoRds.id -key "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -ValueName "fDisableAudioCapture" -Type DWORD -value 0
    Set-GPRegistryValue -Guid $GpoRds.id -key "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -ValueName "fDisableClip" -Type DWORD -value 1
    Set-GPRegistryValue -Guid $GpoRds.id -key "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -ValueName "fDisableCcm" -Type DWORD -value 1
    Set-GPRegistryValue -Guid $GpoRds.id -key "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -ValueName "fDisableCdm" -Type DWORD -value 1
    Set-GPRegistryValue -Guid $GpoRds.id -key "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -ValueName "fDisableLPT" -Type DWORD -value 1
    Set-GPRegistryValue -Guid $GpoRds.id -key "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -ValueName "fDisablePNPRedir" -Type DWORD -value 1
    Set-GPRegistryValue -Guid $GpoRds.id -key "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -ValueName "fEnableSmartCard" -Type DWORD -value 0
    Set-GPRegistryValue -Guid $GpoRds.id -key "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -ValueName "fDisableTerminalServerTooltip" -Type DWORD -value 1
    Set-GPRegistryValue -Guid $GpoRds.id -key "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -ValueName "LicensingMode" -Type DWORD -value 2
    Set-GPRegistryValue -Guid $GpoRds.id -key "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -ValueName "fDisableCpm" -Type DWORD -value 1
    Set-GPRegistryValue -Guid $GpoRds.id -key "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\Client" -ValueName "**del.fUsbRedirectionEnableMode" -Type ExpandString -Value ""

    #Z drive mapping for exam results
    $GpoDrive = New-GPO -Name "ExamRoomAll-Students-Drive-settings"

    #Get GPO object previously created
    $DomainNamingContext = ([adsi]"LDAP://RootDSE").rootDomainNamingContext
    $Searcher = New-Object -TypeName DirectoryServices.DirectorySearcher -Property @{
        Filter = "(displayname=$($GpoDrive.DisplayName))"
        SearchRoot = "LDAP://CN=Policies,CN=System,$DomainNamingContext"
    }
    $GpoDriveObj = ($Searcher.FindOne()).GetDirectoryEntry()
        
    $GPCFileSysPath = $GpoDriveObj.Properties.gpcfilesyspath -join ''
        
    #Create GptTmpl.inf to manage Restricted Groups
    $DriveXmlPath = Join-Path -Path $GPCFileSysPath -ChildPath 'User\Preferences\Drives'

    New-Item $DriveXmlPath -ItemType Directory | Out-Null
    $XmlFile = New-Item "$DriveXmlPath\Drives.xml" -ItemType File
        
    $DrivesXml | Out-File $XmlFile -Encoding utf8

    #Update Gpt.ini
    $GptIni | Out-File (Join-Path -Path $GPCFileSysPath -ChildPath '\gpt.ini') -Encoding utf8

    #Set GPO MachineExtensionNames and version
    $GpoObj.Properties["gPCUserExtensionNames"].Value = $gPCUserExtensionNamesGppDrives
    $GpoObj.Properties["versionNumber"].Value = "2"
    $GpoObj.CommitChanges()

    #Wait and create GPO Link
    Start-Sleep 30
    $StudentsOU = Get-ADOrganizationalUnit -filter "Name -eq 'Students'"
    $StudentsOU | % { 
        New-GPLink -Guid $GpoRds.Id -Target $_.DistinguishedName -LinkEnabled Yes
        New-GPLink -Guid $GpoDrive.Id -Target $_.DistinguishedName -LinkEnabled Yes
    }

}


Import-Module ActiveDirectory, ServerManager

Write-Output "Enabling CredSSP..."
Enable-WSManCredSSP -Role Client -DelegateComputer "*.$DomainName" -Force
Enable-WSManCredSSP -Role Server -Force

Write-Output "Enabling PSRemoting..."
Enable-PSRemoting -Force -verbose

Write-Output "Opening session with domain credential..."
$PsSession = New-PSSession -ComputerName $env:COMPUTERNAME -Credential $Credential -Authentication Credssp

#Exam Room OU and GPOs management
Write-Output "Creating OU structure..."
for ($i = 1; $i -le $NumberOfExamRooms; $i++)
{ 
    $ExamRoomId = $i.ToString().PadLeft(2,'0')

    #Prepare OU structure for current ExamRoom
    $ExamRoomOU = Get-ADOrganizationalUnit -filter "Name -eq 'ExamRoom$ExamRoomId'" -Credential $credential
    if(!$ExamRoomOU) {
        $ExamRoomOU = New-ADOrganizationalUnit -Credential $credential -Name "ExamRoom$ExamRoomId" -PassThru
    }

    $TeachersOU = Get-ADOrganizationalUnit -filter "Name -eq 'Teachers'" -Credential $credential -SearchBase $ExamRoomOU.DistinguishedName
    if(!$TeachersOU) {
        $TeachersOU = New-ADOrganizationalUnit -Credential $credential -Name "Teachers" -PassThru -Path $ExamRoomOU.DistinguishedName
    }

    $StudentsOU = Get-ADOrganizationalUnit -filter "Name -eq 'Students'" -Credential $credential -SearchBase $ExamRoomOU.DistinguishedName
    if(!$StudentsOU) {
        $StudentsOU = New-ADOrganizationalUnit -Credential $credential -Name "Students" -PassThru -Path $ExamRoomOU.DistinguishedName
    }

    #Create Restricted Groups GPO
    Write-Output "Adding Restricted Groups GPO to each OU..."
    Invoke-Command -Session $PsSession -ScriptBlock $RestrictedGroupScriptBlock -ArgumentList ($ExamRoomId, $StudentsOU.DistinguishedName) -Verbose

}

#Create RDS Settings and Network Drive GPOs
Write-Output "Adding RDS Settings and Network Drive GPOs..."
Invoke-Command -Session $PsSession -ScriptBlock $OtherGPOsScriptBlock -Verbose
