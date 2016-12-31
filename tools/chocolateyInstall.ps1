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

# To test function outside of chocolatey, just copy them to another file and
# run the following command:
# powershell -ExecutionPolicy Unrestricted -File .\yourFile.ps1

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

<#
.DESCRIPTION
Get service properties
.OUTPUTS
An object made of the following fields:
- name (string)
- status (string)
- startupType (string)
- delayedStart (bool)
#>
function GetServiceProperties {
	param (
		[Parameter(Mandatory=$true)][string]$name
	)

	# Lets return our own object.
	# src.: http://stackoverflow.com/a/12621314
	$properties = "" | Select-Object -Property name,status,startupType,delayedStart

	# The Get-Service Cmdlet returns a System.ServiceProcess.ServiceController
    # Get-Service throws an exception when the exact case insensitive service
    # is not found. Therefore, there is no need to make any further checks.
	$service = Get-Service $name -ErrorAction Stop

    # Correct to the exact service name
    if ($name -cnotmatch $service.Name) {
        Write-Warning "The case sensitive service name is '$($service.Name)' not '$name'"
    }
    $properties.name = $service.Name

	# Get the service status. The Status property returns an enumeration
	# ServiceControllerStatus src.: https://goo.gl/oq8Bbx
	# This cannot be tested directly from CLI as the .NET assembly is not
	# loaded, we get an exception
	[array]$statusAvailable = [enum]::GetValues([System.ServiceProcess.ServiceControllerStatus])
	if ($statusAvailable -notcontains "$($service.Status)") {
        $errorString = "The status '$service.status' must be '"
		$errorString += $statusAvailable -join "', '"
		$errorString += "'"
		throw "$errorString"
	}

    $properties.status = $service.Status

	# The property StartType of the class System.ServiceProcess.ServiceController
	# might not available in the .NET Framework when used with PowerShell 2.0
    # (cf. https://goo.gl/5NDtZJ). This property has been made available since
    # .NET 4.6.1 (src.: https://goo.gl/ZSvO7B).
	# Since we cannot rely on this property, we need to find another solution.
	# While WMI is widely available and working, let's parse the registry;
	# later we will need an info exclusively storred in it.

	# To list all the properties of an object:
	# $services[0] | Get-ItemProperty
	$service = Get-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\$name
	if (!$service) {
		throw "The service '$name' was not found using the registry"
	}

	# The values are the ones defined in
	# [enum]::GetValues([System.ServiceProcess.ServiceStartMode])
	switch ($service.Start) {
		2 { $properties.startupType = "Automatic" }
		3 { $properties.startupType = "Manual" }
		4 { $properties.startupType = "Disabled" }
		default { throw "The startup type is invalid" }
	}

	# If the delayed flag is not set, there is no record DelayedAutoStart to the
	# object.
	if ($service.DelayedAutoStart) {
		$properties.delayedStart = $true
	} else {
		$properties.delayedStart = $false
	}

	return $properties
}

<#
.DESCRIPTION
Set service properties supporting delayed services
.PARAMETER name
The service name
.PARAMETER status
One of the following service status:
- 'Stopped'
- 'StartPending'
- 'StopPending'
- 'Running'
- 'ContinuePending'
- 'PausePending'
- 'Paused'.
.PARAMETER startupType
One of the following service startup type:
- 'Automatic (Delayed Start)'
- 'Automatic'
- 'Manual'
- 'Disabled'
#>
function SetServiceProperties {
	param (
		# By default parameter are positional, this means the parameter name
		# can be omitted, but needs to repect the order in which the arguments
		# are declared, except if the PositionalBinding is set to false.
		# src.: https://goo.gl/UpOU62
		[Parameter(Mandatory=$true)][string]$name,
		[Parameter(Mandatory=$true)][string]$status,
		[Parameter(Mandatory=$true)][string]$startupType
	)

	try {
		$service = GetServiceProperties $name
	} catch {
		throw "The service '$name' cannot be found"
	}

	if ($env:ChocolateyEnvironmentDebug -eq 'true' -or
        $env:ChocolateyEnvironmentVerbose -eq 'true') {
		Write-Verbose "Before SetServicesProperties:"
		if ($service.delayedStart) {
			Write-Verbose "Service '$($service.name)' now '$($service.status)', with '$($service.startupType)' startup type and delayed"
		} else {
			Write-Verbose "Service '$($service.name)' now '$($service.status)', with '$($service.startupType)' startup type"
		}
	}

	# src.: https://goo.gl/oq8Bbx
	[array]$statusAvailable = [enum]::GetValues([System.ServiceProcess.ServiceControllerStatus])
	if ($statusAvailable -notcontains "$status") {
		$errorString = "The status '$status' must be '"
		$errorString += $statusAvailable -join "', '"
		$errorString += "'"
		throw "$errorString"
	}

	if ($startupType -ne "Automatic (Delayed Start)" -and
		$startupType -ne "Automatic" -and
		$startupType -ne "Manual" -and
		$startupType -ne "Disabled") {
		throw "The startupType '$startupType' must either be 'Automatic (Delayed Start)', 'Automatic', 'Manual' or 'Disabled'"
	}

	# Set delayed auto start
	if ($startupType -eq "Automatic (Delayed Start)") {

		# (src.: https://goo.gl/edhCxm and https://goo.gl/NyVXxM)
		# Modifying the registry does not change the value in services.msc,
		# using sc.exe does. sc.exe uses the Windows NT internal functions
		# OpenServiceW and ChangeServiceConfigW. We could use it in PowerShell,
		# but it would requires a C++ wrapper imported in C# code with
		# DllImport, the same C# code imported in PowerShell. While this is
		# doable, this is way slower than calling the sc utility directly.
		# Set-ItemProperty -Path "Registry::HKLM\System\CurrentControlSet\Services\$($service.Name)" -Name DelayedAutostart -Value 1 -Type DWORD
		# An .exe can be called directly but ensuring the exit code and
		# stdout/stderr are properly redirected can only be checked with
		# this code.
		$psi = New-object System.Diagnostics.ProcessStartInfo
		$psi.CreateNoWindow = $true
		$psi.UseShellExecute = $false
		$psi.RedirectStandardInput = $true
		$psi.RedirectStandardOutput = $true
		$psi.RedirectStandardError = $true
		$process = New-Object System.Diagnostics.Process
		$process.StartInfo = $psi
		$psi.FileName = 'sc.exe'
		$psi.Arguments = @("Config $($service.Name) Start= Delayed-Auto")
		# The [void] casting is actually needed to avoid True or False to be displayed
		# on stdout.
		[void]$process.Start()
		#PrintWhenVerbose $process.StandardOutput.ReadToEnd()
		#PrintWhenVerbose $process.StandardError.ReadToEnd()
		$process.WaitForExit()
		if (!($process.ExitCode -eq 0)) {
			throw "Unable to set the service '$($service.Name)' to a delayed autostart."
		}
	} else {
		# Make sure the property DelayedAutostart is reset otherwise
		# GetServiceProperties could report a service as Manual and delayed
		# which is not possible.
		Set-ItemProperty `
		-Path "Registry::HKLM\System\CurrentControlSet\Services\$($service.Name)" `
		-Name DelayedAutostart -Value 1 -Type DWORD -ErrorAction Stop
	}

	# Cast "Automatic (Delayed Start)" to "Automatic" to have a valid name
	if ($startupType -match "Automatic") {
		$startupType = "Automatic"
	}

	# Set-Service cannot stop services properly and complains the service is
	# dependent on other services, which seems to be wrong.
	# src.: http://stackoverflow.com/a/39811972/3514658
	if ($status -eq "Stopped") {
		Stop-Service $service.Name -ErrorAction Stop
	}

	Set-Service -Name $service.Name -StartupType $startupType -Status $status -ErrorAction Stop

	if ($env:ChocolateyEnvironmentDebug -eq 'true' -or
        $env:ChocolateyEnvironmentVerbose -eq 'true') {
		$service = GetServiceProperties $name
		Write-Verbose "After SetServicesProperties:"
		if ($service.delayedStart) {
			Write-Verbose "Service '$($service.name)' now '$($service.status)', with '$($service.startupType)' startup type and delayed"
		} else {
			Write-Verbose "Service '$($service.name)' now '$($service.status)', with '$($service.startupType)' startup type"
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
# - Install the driver accepting the certificate
# - Tick the checkbox "Always trust software from "OpenVPN Technologies, Inc.""
#   which has the effect to consider OpenVPN as a trusted publisher
# - As by default, only certificates of the local users are displayed in the
#   certificate manager, we need to add the view for the whole computer first.
#   For that, we need to run the Microsoft Management Console, run mmc.exe
# - Then go to "File -> Add/Remove Snap-in..."
# - Select "Certificates" from the left list view then run certmgr.msc,
# - Click the "Add >" button at the center of the window
# - Select the "Computer account" radio button
# - Click the "Next >" button
# - Click the "Finish" button
# - Click the "OK" button
# - Expand "Certificates (Local Computer) -> Trusted Publishers -> Certificates"
# - Right click the "OpenVPN Technologies, Inc." certificate
# - Select "All Tasks -> Export..."
# - Click the "Next >" button
# - Select the "Base64 encoded x.509 (.CER)" radio button
# - Click the "Next" button
# - Select a destination and a filename you wish to save the certificate
# - Click the "Next >" button
# - Click the "Finish" button
# - Click the "OK" button from the confirmation dialog box
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
