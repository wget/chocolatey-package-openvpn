$packageName = 'openvpn'
# By default: C:\ProgramData\chocolatey\lib\openvpn\tools
$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$fileType = 'exe'
# For a list of all silent arguments used
# https://github.com/OpenVPN/openvpn-build/blob/c92af79befec86f21b257b5defba0becb3d7641f/windows-nsis/openvpn.nsi#L551
# For their description
# https://github.com/OpenVPN/openvpn-build/blob/c92af79befec86f21b257b5defba0becb3d7641f/windows-nsis/openvpn.nsi#L107
$silentArgs = '/S /SELECT_EASYRSA=1'
$validExitCodes = @(0)
$url = 'https://build.openvpn.net/downloads/releases/openvpn-install-2.4.1-I601.exe'
$checksum = '83ac5500f9fc15c65bf8f2ca90f04c3043b7431fef763408c29746a7385b5a3ea313e11cf4fd274559c8cd9ba811cc6df49d2a84b94330f738fa31724edca4ba'
$urlSig = 'https://build.openvpn.net/downloads/releases/openvpn-install-2.4.1-I601.exe.asc'
$checksumSig = '8a250f7d77b96de64aa113bb9468f3d26d41f231ab3cb894bfacb8c809631db4227e8c5662d84512ae4fad2facf57ed8cb3e2ac3e6ed719f4d5b195fe43fa225'
$pgpKey = "samuli_public_key.asc"
$packageFileName = "$($packageName)Install.$fileType"
$sigFileName = "$($packageFileName).asc"

# Load custom functions
. "$toolsDir\utils\utils.ps1"

# If GPG has been just added, need to refresh to access to it from this session
Update-SessionEnvironment

Get-ChecksumValid `
    -File "$toolsDir\$sigFileName" `
    -Checksum "$checksumSig" `
    -ChecksumType 'sha512'

# The GPG signature needs to have the same filename as the file checked but
# with the .asc suffix, otherwise gpg reports it cannot verify the file with
# the following message:
# gpg: no signed data
# gpg: can't hash datafile: No data
CheckPGPSignature `
    -pgpKey "$toolsDir\$pgpKey" `
    -signatureFile "$sigFileName" `
    -file "$packageFileName"

Write-Host "Adding OpenVPN to the Trusted Publishers (needed to have a silent install of the TAP driver)..."
AddTrustedPublisherCertificate -file "$toolsDir\openvpn.cer"

Write-Host "Getting the state of the current OpenVPN service (if any)..."
# Needed to reset the state of the Interactive service if upgrading from a
# branch 2.4 and onwards or reinstalling a build from the branch 2.4
try {
    $previousInteractiveService = GetServiceProperties "OpenVPNServiceInteractive"
} catch {
    Write-Host "No previous OpenVPN interactive service detected."
}
# Even if 2.4.1 fixes reset of services. This is still needed for all cases 2.3
# to 2.4 or 2.4 to 2.4.x and onwards.
try {
    $previousService = GetServiceProperties "OpenVpnService"
} catch {
    Write-Host "No previous OpenVPN service detected."
}

Get-ChecksumValid `
    -File "$toolsDir\$packageFileName" `
    -Checksum "$checksum" `
    -ChecksumType 'sha512'

Install-ChocolateyInstallPackage `
    -PackageName $packageName `
    -FileType $fileType `
    -SilentArgs $silentArgs `
    -File $packageFileName `
    -ValidExitCodes $validExitCodes

if ($previousInteractiveService) {
    Write-Host "Resetting previous OpenVPN interactive service to " `
        "'$($previousInteractiveService.status)' and " `
        "'$($previousInteractiveService.startupType)'..."
    SetServiceProperties `
        -name "OpenVPNServiceInteractive" `
        -status "$($previousInteractiveService.status)" `
        -startupType "$($previousInteractiveService.startupType)"
}

if ($previousService) {
    Write-Host "Resetting previous OpenVPN service to " `
        "'$($previousService.status)' and "  `
        "'$($previousService.startupType)'..."
    SetServiceProperties `
        -name "OpenVPNService" `
        -status "$($previousService.status)" `
        -startupType "$($previousService.startupType)"
}

Write-Host "Removing OpenVPN from the Trusted Publishers..."
RemoveTrustedPublisherCertificate -file "$toolsDir\openvpn.cer"
