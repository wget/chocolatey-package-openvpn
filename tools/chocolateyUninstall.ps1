$packageName = 'openvpn'
$fileType = 'exe'
$silentArgs = '/S'
$validExitCodes = @(0)

# If we specify to Uninstall-ChocolateyPackage a silent argument but without
# a path, the command throws an exception. We cannot thus rely on the
# Chocolatey Auto Uninstaller feature. We will need to do manually what the
# PowerShell command does i.e. looking for the right path in the registry
# manually.

$regUninstallDir = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\'
# No value in the 32 bits SysWoW64 subsystem on 64 bits. No string in that
# registry node.
#$regUninstallDirWow64 = 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\'

$uninstallPaths = $(Get-ChildItem $regUninstallDir).Name
$uninstallPath = $uninstallPaths -match "OpenVPN" | Select -First 1

$openvpnKey = ($uninstallPath.replace('HKEY_LOCAL_MACHINE\','HKLM:\'))

$file = (Get-ItemProperty -Path ($openvpnKey)).UninstallString 

Uninstall-ChocolateyPackage `
    -PackageName "$packageName" `
    -FileType "$fileType" `
    -SilentArgs "$silentArgs" `
    -ValidExitCodes "$validExitCodes" `
    -File "$file"
