function AddAclsForUser
{
    Param(
     [parameter(Mandatory=$true)]
     $FolderPath,
     [parameter(Mandatory=$true)]
     $UserName
    )

    Write-Host "FolderPath: $FolderPath"
    Write-Host "UserName: $UserName"
    $permission = $UserName,"FullControl","Allow"
    $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule $permission

    Write-Host "Setting ACL on $FolderPath"
    $acl = Get-Acl $FolderPath
    $acl.SetAccessRule($accessRule)
    $acl | Set-Acl -Path $FolderPath

    Write-Host "Setting ACL for each folder under $FolderPath"
    Get-ChildItem -Recurse -Path $FolderPath -Directory | % {
        if(Get-Member -InputObject $_ -Name "IsReadOnly" -Membertype Properties)
        {
            $_.IsReadOnly = $false
            $_.FullName
        }

        $acl = Get-Acl $_.FullName
        $acl.AddAccessRule($accessRule)
        Set-Acl -Path $_.FullName -AclObject $acl
        #$acl | Format-List
    }

    Write-Host "Setting ACL for each file under $FolderPath"
    Get-ChildItem -Recurse -Path $FolderPath | % {
        if(Get-Member -InputObject $_ -Name "IsReadOnly" -Membertype Properties)
        {
            $_.IsReadOnly = $false
            $_.FullName
        }

        $acl = Get-Acl $_.FullName
        $acl.AddAccessRule($accessRule)
        Set-Acl -Path $_.FullName -AclObject $acl
        #$acl | Format-List
    }

    Write-Host "End AddAclsForUser"
}

Write-Host "Begin: rs3test"
$ErrorActionPreference = 'Continue'
$(docker system prune -a -f) | % { Write-Host "$_" }

$logs = gci -Path 'C:\dotnetbuild\logs'
$logs | % {
    Write-Host "Display contents of $($_.FullName)"
    $logContent = Get-Content $_.FullName -Raw
    Write-Host "$logContent"
}

$dockerProgramData = Join-Path "C:\ProgramData" "docker"
if (Test-Path -Path "$dockerProgramData" -PathType Container)
{
    AddAclsForUser -FolderPath 'C:\ProgramData\docker' -UserName $env:USERNAME
    #AddAclsForUser -FolderPath 'C:\Users' -UserName $env:USERNAME
    #AddAclsForUser -FolderPath 'C:\Program Files\Docker' -UserName $env:USERNAME
    #AddAclsForUser -FolderPath 'C:\Program Files\Linux Containers' -UserName $env:USERNAME
    #AddAclsForUser -FolderPath 'C:\' -UserName $env:USERNAME
    #AddAclsForUser -FolderPath 'D:\' -UserName $env:USERNAME

    Write-Host "Exclude C:\ProgramData\docker from Windows Defender scheduled and real-time scanning."
    Add-MpPreference -Force -ExclusionPath 'C:\ProgramData\docker'

    #Write-Host "Exclude C:\Users from Windows Defender scheduled and real-time scanning."
    #Add-MpPreference -Force -ExclusionPath 'C:\Users'

    #Write-Host "Exclude C:\Program Files from Windows Defender scheduled and real-time scanning."
    #Add-MpPreference -Force -ExclusionPath 'C:\Program Files'

    #Add-MpPreference -Force -ExclusionPath 'C:\'
    #Add-MpPreference -Force -ExclusionPath 'D:\'
    Uninstall-WindowsFeature -Name Windows-Defender
}
else
{
    Write-Warning "Unable to locate $dockerProgramData"
}

#Write-Host "File name containing the word Docker."
#gci -Path 'C:\' -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "docker" } | Select FullName
#Write-Host "Folder name containing the word Docker."
#gci -Path 'C:\' -Recurse -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "docker" } | Select FullName

Write-Host "Restart Docker service."
Restart-Service -Name Docker -Force -Verbose
sleep -Seconds 60
$(docker version) | % { Write-Host "$_" }

Write-Host "End: rs3test"