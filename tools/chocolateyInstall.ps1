$packageName = 'openvpn'
$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$fileType = 'exe'
$url = 'https://swupdate.openvpn.org/community/releases/openvpn-install-2.4.0-I601.exe'
# For a list of all silent arguments used
# https://github.com/OpenVPN/openvpn-build/blob/c92af79befec86f21b257b5defba0becb3d7641f/windows-nsis/openvpn.nsi#L551
# For their description
# https://github.com/OpenVPN/openvpn-build/blob/c92af79befec86f21b257b5defba0becb3d7641f/windows-nsis/openvpn.nsi#L107
$silentArgs = '/S /SELECT_EASYRSA=1'
$validExitCodes = @(0)
$checksum = '22e5101f8d4de440359689b509cb2ca9318a96e3c8f0c2daa0c35f76d9b8608b1adc5f2fad97f63fcc63845c860ad735a70eee90d3f1551bb4c9eea12d69eb94'
$pgpKey = "samuli_public_key.asc"
$urlSig = 'https://swupdate.openvpn.org/community/releases/openvpn-install-2.4.0-I601.exe.asc'
$checksumSig = 'c88d6b96f572d466c53a61f58a9cd0a75859aa02aba8fc0d407df38b7f9ecc2c34ec81ab997ae0c4e2e9d42872c5b2b610259460aaa4c9c599b61981b4e71742'
$certificateFingerprint = "5E66E0CA2367757E800E65B770629026E131A7DC"

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

function PrintWhenVerbose {
    param (
        [Parameter(Position=0)]
        [string]
        $pString
    )

    # Display the output of the executables if chocolatey is run either in debug
    # or in verbose mode.
    if ($env:ChocolateyEnvironmentDebug -eq 'true' -or
        $env:ChocolateyEnvironmentVerbose -eq 'true') {

        $string = New-Object System.IO.StringReader($pString)
        while (($line = $string.ReadLine()) -ne $null) {
           Write-Verbose $line
        }
	}
}

Write-Host "Downloading package installer..."
$packageFileName = Get-ChocolateyWebFile `
    -PackageName $packageName `
    -FileFullPath $(Join-Path $(GetTemporaryDirectory) "$($packageName)Install.$fileType")`
    -Url $url `
    -Checksum $checksum `
    -ChecksumType 'sha512'

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
    -Checksum $checksumSig `
    -ChecksumType 'sha512'

# If GPG has been just added, need to refresh to access to it from this session
Update-SessionEnvironment

if (!(Get-Command "gpg.exe" -ErrorAction SilentlyContinue)) {
    throw "Cannot find 'gpg.exe'. Unable to check signatures."
}

if (!(Test-Path "$toolsDir\$pgpKey")) {
    throw "Cannot find the PGP key '$pgpKey'. Unable to check signatures."
}

$psi = New-object System.Diagnostics.ProcessStartInfo
$psi.CreateNoWindow = $true
$psi.UseShellExecute = $false
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$process = New-Object System.Diagnostics.Process
$process.StartInfo = $psi

Write-Host "Importing '$pgpKey' in GPG trusted keyring..."
# Simply invoing the command gpg.exe and checking the value of $? was not
# enough. Using the following method worked and was indeed more reliable.
# src.: https://goo.gl/Ungugv
$psi.FileName = 'gpg.exe'
$psi.Arguments = @("--import $toolsDir\$pgpKey")
# The [void] casting is actually needed to avoid True or False to be displayed
# on stdout.
[void]$process.Start()
PrintWhenVerbose $process.StandardOutput.ReadToEnd()
PrintWhenVerbose $process.StandardError.ReadToEnd()
$process.WaitForExit()
if (!($process.ExitCode -eq 0)) {
    throw "Unable to import PGP key '$pgpKey'. Unable to check signatures."
}

Write-Host "Trusting '$pgpKey'..."
$psi.FileName = 'gpg.exe'
$psi.Arguments = @("--with-fingerprint --with-colons $toolsDir\$pgpKey")

# Get the full fingerprint of the key
[void]$process.Start()
# src.: http://stackoverflow.com/a/8762068/3514658
$pgpFingerprint = $process.StandardOutput.ReadToEnd()
$process.WaitForExit()

# Parse output
$pgpFingerprint = $pgpFingerprint -split ':'
$pgpFingerprint = $pgpFingerprint[18]

$psi.FileName = 'gpg.exe'
$psi.Arguments = @("--import-ownertrust")
[void]$process.Start()

# Specify the fingerprint and the trust level to stdin
# e.g.: ABCDEF01234567890ABCDEF01234567890ABCDEF:6:
$input = $process.StandardInput

# Even if the number 6 corresponds to the level 5 (ultimate trust) which is
# usually dedicated to our own keys. Using the number 5 corresponding to the
# level 4 (trully trust) is not enough for this case. Checking a signature
# requires an ultimate trust in the key.
$input.WriteLine($pgpFingerprint + ":6:")
# Not written until the stream is closed. If not closed, the process will still
# run and the software will hang.
# src.: https://goo.gl/5oYgk4
$input.Close()
$process.WaitForExit()

Write-Host "Checking PGP signatures..."
# Surrounding $sigFileName by 2 double quotes is needed, otherwise of the user
# folder has a space in it, the space is not taken into account and gpg cannot
# find the signed data to verify.
$psi.FileName = 'gpg.exe'
$psi.Arguments = @("--verify $sigFileName $packageFileName")
[void]$process.Start()
PrintWhenVerbose $process.StandardOutput.ReadToEnd()
PrintWhenVerbose $process.StandardError.ReadToEnd()
$process.WaitForExit()
if (!($process.ExitCode -eq 0)) {
    throw "The OpenVPN installer signature does not match. Installation aborted."
}

Write-Host "Untrusting and removing '$pgpKey'..."
$psi.FileName = 'gpg.exe'
$psi.Arguments = @("--batch --yes --delete-keys $pgpFingerprint")
[void]$process.Start()
PrintWhenVerbose $process.StandardOutput.ReadToEnd()
PrintWhenVerbose $process.StandardError.ReadToEnd()
$process.WaitForExit()
if (!($process.ExitCode -eq 0)) {
    Write-Warning "The OpenVPN installer signature cannot be removed after it has been trusted. Manual intervention required."
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
$psi.FileName = 'certutil'
$psi.Arguments = @("-addstore TrustedPublisher $toolsDir\openvpn.cer")
[void]$process.Start()
PrintWhenVerbose $process.StandardOutput.ReadToEnd()
PrintWhenVerbose $process.StandardError.ReadToEnd()
$process.WaitForExit()
if (!($process.ExitCode -eq 0)) {
    throw "The OpenVPN certificate cannot be added to the certificate store. Installation aborted."
}

Write-Host "Getting the state of the current OpenVPN service (if any)..."
# Get-Service returns a System.ServiceProcess.ServiceController. Get-WmiObject
# returns a Win32_Service (cf. __CLASS property of the returned object). The
# query in the like statement is case insensitive.
[array]$service = Get-WmiObject -Query "select * from win32_service where name like '%openvpn%'"
if ($service.Count -gt 1) {
    Write-Warning "$service.Count matches of the OpenVPN service found!"
    Write-Warning "Please alert package maintainer with configuration details,"
    Write-Warning "especially the output of services.msc related to OpenVPN."
    Write-Warning "The OpenVPN service configuration might fail and a manual"
    Write-Warning "intervention might be required."
}

$serviceNeedsRestart = $False
$serviceStartMode = "Manual"
if ($service) {
    if ($service[0].State -eq "Running") {
        $serviceNeedsRestart = $True
    }

    # The property StartType of the class ServiceController might not available
    # in the .NET Framework when used with PowerShell 2.0
    # (cf. https://goo.gl/5NDtZJ). This property has been made available since
    # .NET 4.6.1 (src.: https://goo.gl/ZSvO7B). Since we cannot rely on this
    # property, we have two solutions, either using a WMI object or parsing
    # the registry manually. Let's use WMI as it's available since a long time.
    $serviceStartMode = $service[0].StartMode

    # Convert Win32_service types to .NET types
    if ($serviceStartMode -eq "Auto") {
        # Using the following type does not work
        # [System.ServiceProcess.ServiceStartMode]::Automatic
        $serviceStartMode = "Automatic"
    } elseif ($serviceStartMode -eq "Manual") {
        $serviceStartMode = "Manual"
    } elseif ($serviceStartMode -eq "Disabled") {
        $serviceStartMode = "Disabled"
    }
}

Install-ChocolateyInstallPackage `
    -PackageName $packageName `
    -FileType $fileType `
    -SilentArgs $silentArgs `
    -File $packageFileName `
    -ValidExitCodes $validExitCodes

[array]$service = Get-Service | Where-Object {$_.Name -like "*OpenVPN*"}
if ($service.Count -eq 0) {
    Write-Error "The OpenVPN server cannot be found."
    Write-Error "Please alert the package maintainer."
} elseif ($service.Count -gt 1) {
    Write-Warning "$service.Count matches of the OpenVPN service found!"
    Write-Warning "Please alert package maintainer with configuration details,"
    Write-Warning "especially the output of services.msc related to OpenVPN."
    Write-Warning "The OpenVPN service configuration might fail and a manual"
    Write-Warning "intervention might be required."
}

if ($serviceNeedsRestart) {
    try {
        Write-Host "OpenVPN service was previously started. Trying to restart it..."
        Restart-Service $service[0].Name
        Write-Host "OpenVPN service restarted with successful."
    } catch {
        # Do not use Write-Error, otherwise chocolatey will think the installation has failed.
        Write-Warning "OpenVPN service failed to be restarted. Manual intervention required."
    }
}

if ($serviceStartMode -ne 'Manual') {
    try {
        Write-Host "Trying to reset the OpenVPN service to ""$serviceStartMode""..."
        Set-Service $service[0].Name -StartupType $serviceStartMode
        Write-Host "OpenVPN service reset to ""$serviceStartMode"" with successful."
    } catch {
        Write-Warning "OpenVPN service failed to be reset to ""$serviceStartMode"". Manual intervention required."
    }
}

# Let's remove the certificate we inserted
[array]$cert = Get-ChildItem -Path Cert:\LocalMachine\TrustedPublisher | `
    Where-Object {$_.Thumbprint -eq $certificateFingerprint}

if ($key.Count -eq 0) {
    Write-Warning "The OpenVPN certificate has been already removed by other means."
    Write-Warning "This shouldn't have happened, please alert the package maintainer."
} else {
    Write-Host "Removing OpenVPN driver signing certificate added by this installer..."
    # We still need to use certutil to remove the certificate because the Remove-Item
    # cmdlet is only available from PowerShell 3.0 and we need Posh 2.0 compatibility.
    $psi.FileName = 'certutil'
    $psi.Arguments = @("-delstore TrustedPublisher $certificateFingerprint")
    [void]$process.Start()
    PrintWhenVerbose $process.StandardOutput.ReadToEnd()
    PrintWhenVerbose $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    if (!($process.ExitCode -eq 0)) {
        Write-Warning "The OpenVPN certificate cannot be removed from the certificate store."
        Write-Warning "Manual intervention required."
    }
}

# The installer changes the PATH, apply these changes in the current PowerShell
# session (limited to this script).
Update-SessionEnvironment
