$packageName = 'openvpn'
$fileType = 'exe'
$silentArgs = '/S'
$validExitCodes = @(0)

# If we specify to Uninstall-ChocolateyPackage a silent argument but without
# a path, the command throws an exception. We cannot thus rely on the
# Chocolatey Auto Uninstaller feature. We will need to do manually what the
# PowerShell command does i.e. looking for the right path in the registry
# manually.

# Let's remove the certificate we inserted
Write-Host "Removing OpenVPN driver signing certificate added by this installer..."
Start-ChocolateyProcessAsAdmin "certutil -delstore 'TrustedPublisher' 'OpenVPN Technologies, Inc.'"

[array]$key = Get-UninstallRegistryKey -SoftwareName "OpenVPN*"
$file = $key.UninstallString
if (!$file) {
    throw "OpenVPN uninstaller not found"
}

Write-Host "Removing OpenVPN... The OpenVPN service will be automatically stopped and removed."
Uninstall-ChocolateyPackage `
    -PackageName "$packageName" `
    -FileType "$fileType" `
    -SilentArgs "$silentArgs" `
    -ValidExitCodes "$validExitCodes" `
    -File "$file"

# After the uninstall has performed, choco checks if there are uninstall
# registry keys left and decides to launch or not its auto uninstaller feature.
# However, here, we have a race condition. When choco checks if the following
# registry key is still present, it's already gone.
# SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\OpenVPN
# A fix for this issue is already present in choco 0.10.4
# https://github.com/chocolatey/choco/issues/1035
if ($Env:CHOCOLATEY_VERSION -lt "0.10.4") {
    # Let's sleep. 2 secs is not enough. 5 is too long.
    Start-Sleep -s 3
}

# The uninstaller changes the PATH, apply these changes in the current PowerShell
# session (limited to this script).
Update-SessionEnvironment
