$packageName = 'openvpn'
$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$fileType = 'exe'
$url = 'https://swupdate.openvpn.org/community/releases/openvpn-install-2.3.13-I601-i686.exe'
$url64 = 'https://swupdate.openvpn.org/community/releases/openvpn-install-2.3.13-I601-x86_64.exe'
# For a list of all silent arguments used
# https://github.com/OpenVPN/openvpn-build/blob/master/windows-nsis/openvpn.nsi#L431
# For their description
# https://github.com/OpenVPN/openvpn-build/blob/master/windows-nsis/openvpn.nsi#L102
$silentArgs = '/S /SELECT_EASYRSA=1'
$validExitCodes = @(0)
$checksum = '182c7d906a9fc081080dc3b4459e3ec867681e6cb645a75d2ebe04d1d06ed14605622c4f34ef4d352bbdf68d81b06e2de634bed75cdb7d939e7f2cdd7973d986'
$checksum64='9ad6cb9afc7932dc883835cf60b5efd94ee3f0914d1fb948982056abd04df9aeb8eca3554bd13acb356602ee85e202276397a3d0fab78e7f4d854406703e007e'
$pgpKey = "samuli_public_key.asc"
$urlSig = 'https://swupdate.openvpn.org/community/releases/openvpn-install-2.3.13-I601-i686.exe.asc'
$urlSig64 = 'https://swupdate.openvpn.org/community/releases/openvpn-install-2.3.13-I601-x86_64.exe.asc'
$checksumSig = '8857ea92983a69cd31e2df6342e01231b3e934129056d33564e3cef0ddd3c2dc35bd0ecb52dfe4649a2df2421ad68b1d437eb7a21ad1a800993ae598b2f1372a'
$checksumSig64 = 'dc4ec34b30d8924dfd51975f72f12ee36d7b2bdb3c80a8b8916045d63823ac6ad5833b1f543096296b2d07c4c659ff28811a2328936d11aa1b072856975465bf'

if ($PSVersionTable.PSVersion.Major -lt 3) {
    throw "You need at least PowerShell 3.0 as this script relies on Cmdlets introduced with that version."
}

# This function is based on part of the code of the command
# Install-ChocolateyPackage
# src.: https://goo.gl/jUpwOQ
function GetTemporaryDirectory {

    $chocTempDir = $env:TEMP
    $tempDir = Join-Path $chocTempDir "$($env:chocolateyPackageName)"
    if ($env:chocolateyPackageVersion -ne $null) {
        $tempDir = Join-Path $tempDir "$($env:chocolateyPackageVersion)"
    }
    $tempDir = $tempDir -replace '\\chocolatey\\chocolatey\\', '\chocolatey\'

    if (![System.IO.Directory]::Exists($tempDir)) {
        [System.IO.Directory]::CreateDirectory($tempDir) | Out-Null
    }

    return $tempDir
}

Write-Host "Downloading package installer..."
$packageFileName = Get-ChocolateyWebFile `
    -PackageName $packageName `
    -FileFullPath $(Join-Path $(GetTemporaryDirectory) "$($packageName)Install.$fileType")`
    -Url $url `
    -Url64bit $url64 `
    -Checksum $checksum `
    -ChecksumType 'sha512' `
    -Checksum64 $checksum64 `
    -ChecksumType64 'sha512'

# Download signature and saving it as the original name
# The GPG signature needs to have the same filename as the file checked but
# with the .asc suffix, otherwise gpg reports it cannot verify the file with
# the following message:
# gpg: no signed data
# gpg: can't hash datafile: No data
Write-Host "Downloading package signature..."
$sigFileName = Get-ChocolateyWebFile `
    -PackageName $packageName `
    -FileFullPath $(Join-Path $(GetTemporaryDirectory) "$($packageName)Install.$fileType.asc")`
    -Url $urlSig `
    -Url64bit $urlSig64 `
    -Checksum $checksumSig `
    -ChecksumType 'sha512' `
    -Checksum64 $checksumSig64 `
    -ChecksumType64 'sha512'

# If GPG has been just added, need to refresh to access to it from this session
Update-SessionEnvironment

if (!(Get-Command "gpg.exe" -ErrorAction SilentlyContinue)) {
    throw "Cannot find 'gpg.exe'. Unable to check signatures."
}

if (!(Test-Path "$toolsDir\$pgpKey")) {
    throw "Cannot find the PGP key '$pgpKey'. Unable to check signatures."
}

Write-Host "Importing '$pgpKey' in GPG trusted keyring..."
# Simply invoing the command gpg.exe and checking the value of $? was not
# enough. Using the following method worked and was indeed more reliable.
# src.: https://goo.gl/Ungugv
$ReturnFromEXE = Start-Process `
    -FilePath "gpg.exe" `
    -ArgumentList "--import $toolsDir\$pgpKey" `
    -NoNewWindow -Wait -Passthru
if (!($ReturnFromEXE.ExitCode -eq 0)) {
    throw "Unable to import PGP key '$pgpKey'. Unable to check signatures."
}

Write-Host "Trusting '$pgpKey'..."
# src.: http://stackoverflow.com/a/8762068/3514658
$psi = New-object System.Diagnostics.ProcessStartInfo
$psi.CreateNoWindow = $true
$psi.UseShellExecute = $false
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.FileName = 'gpg.exe'
$psi.Arguments = @("--with-fingerprint --with-colons $toolsDir\$pgpKey")
$process = New-Object System.Diagnostics.Process
$process.StartInfo = $psi
# The [void] casting is actually needed to avoid True or False to be displayed
# on stdout.
[void]$process.Start()
# Get the full fingerprint of the key
$output = $process.StandardOutput.ReadToEnd()
$process.WaitForExit()

# Parse output
$output = $output -split ':'
# Even if the number 6 corresponds to the level 5 (ultimate trust) which is
# usually dedicated to our own keys. Using the number 5 corresponding to the
# level 4 (trully trust) is not enough for this case. Checking a signature
# requires an ultimate trust in the key.
$output = $output[18] + ":6:"

$psi = New-object System.Diagnostics.ProcessStartInfo
$psi.CreateNoWindow = $true
$psi.UseShellExecute = $false
$psi.RedirectStandardInput = $true
$psi.FileName = 'gpg.exe'
$psi.Arguments = @("--import-ownertrust")
$process = New-Object System.Diagnostics.Process
$process.StartInfo = $psi
[void]$process.Start()

# Specify the fingerprint and the trust level to stdin
# e.g.: ABCDEF01234567890ABCDEF01234567890ABCDEF:6:
$input = $process.StandardInput
$input.WriteLine($output)
# Not written until the stream is closed. If not closed, the process will still
# run and the software will hang.
# src.: https://goo.gl/5oYgk4
$input.Close()
$process.WaitForExit()

Write-Host "Checking PGP signatures..."
$ReturnFromEXE = Start-Process `
    -FilePath "gpg.exe" `
    -ArgumentList "--verify $sigFileName" `
    -NoNewWindow -Wait -Passthru
if (!($ReturnFromEXE.ExitCode -eq 0)) {
    throw "The OpenVPN installer signature does not match. Installation aborted."
}

# The setup to install a driver for the virtual network device TAP asks us if
# we want to trust the certificate from OpenVPN Technologies, Inc. In order to
# have a complete silent install, we will add that certificate to the Windows
# keystore.
#
# In order to get that certificate, we had to
# - install the driver accepting the certificate,
# - tick the checkbox "Always trust software from "OpenVPN Technologies, Inc.""
#   which has the effect to consider OpenVPN as a trusted publisher
# - then run certmgr.msc,
# - expand "Certificates (Local Computer) –> Trusted Publishers –> Certificates",
# - right click the OpenVPN Technologies certificate
# - select "All Tasks –> Export..."
# - click Next
# - select Base64 encoded x.509 (.CER) and click Next
# - click Browse, navigate to the location you wish to save the certificate and click Next
# - click Finish
# - click OK
# The certificate is now in the location specified.
# src.: https://goo.gl/o3BVGJ
# Next time we install the software, even if we remove that certificate,
# Windows will not ask us to confirm the installation as the driver is cached
# in the Drivers Store (C:\Windows\Inf). To simulate a first install we need to
# remove the cached drivers as well.
# src.: https://goo.gl/Zbcs6T
Write-Host "Adding OpenVPN certificate to have a silent install of the OpenVPN TAP driver..."
Start-ChocolateyProcessAsAdmin "certutil -addstore 'TrustedPublisher' '$toolsDir\openvpn.cer'"

$service = Get-Service | Where-Object {$_.Name -like "*OpenVPN*"}
$serviceNeedsRestart = $False
$serviceStartMode = [System.ServiceProcess.ServiceStartMode]::Manual
if ($service) {
    if ($service.Status -eq "Running") {
        $serviceNeedsRestart = $True
    }

    $serviceStartMode = $service.StartType
}

Write-Host "Installing OpenVPN..."
Install-ChocolateyInstallPackage `
    -PackageName $packageName `
    -FileType $fileType `
    -SilentArgs $silentArgs `
    -File $packageFileName `
    -ValidExitCodes $validExitCodes

$service = Get-Service | Where-Object {$_.Name -like "*OpenVPN*"}
if (!$service) {
    throw "The OpenVN should have been installed, but the latter was not found."
}
if ($serviceNeedsRestart) {
    try {
        Write-Host "OpenVPN service was previously started. Trying to restarting it..."
        Restart-Service $service.Name
        Write-Host "OpenVPN service restarted with successful."
    } catch {
        # Do not use Write-Error, otherwise chocolatey will think the instalation has failed.
        Write-Host "OpenVPN service failed to be restarted. Manual intervention required."
    }
}
if ($serviceStartMode.ToString() -ne 'Manual') {
    try {
        Write-Host "Trying to reset the OpenVPN service to ""$serviceStartMode.ToString()""..."
        Set-Service $service.Name -startuptype $serviceStartMode
        Write-Host "OpenVPN service set to ""$serviceStartMode"" with successful."
    } catch {
        Write-Host "OpenVPN service failed to be reset to ""$serviceStartMode"". Manual intervention required."
    }
}

# The installer changes the PATH, apply these changes in the current PowerShell
# session (limited to this script).
Update-SessionEnvironment
