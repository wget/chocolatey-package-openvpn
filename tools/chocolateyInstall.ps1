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
$url = 'https://swupdate.openvpn.org/community/releases/openvpn-install-2.4.0-I601.exe'
$checksum = '22e5101f8d4de440359689b509cb2ca9318a96e3c8f0c2daa0c35f76d9b8608b1adc5f2fad97f63fcc63845c860ad735a70eee90d3f1551bb4c9eea12d69eb94'
$urlSig = 'https://swupdate.openvpn.org/community/releases/openvpn-install-2.4.0-I601.exe.asc'
$checksumSig = 'c88d6b96f572d466c53a61f58a9cd0a75859aa02aba8fc0d407df38b7f9ecc2c34ec81ab997ae0c4e2e9d42872c5b2b610259460aaa4c9c599b61981b4e71742'
$pgpKey = "samuli_public_key.asc"

# Load custom functions
. "$toolsDir\utils\utils.ps1"

Write-Host "Downloading package installer..."
$packageFileName = Get-ChocolateyWebFile `
    -PackageName $packageName `
    -FileFullPath $(Join-Path $(CreateTempDirPackageVersion) "$($packageName)Install.$fileType")`
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
    -FileFullPath $(Join-Path $(CreateTempDirPackageVersion) "$($packageName)Install.$fileType.asc")`
    -Url $urlSig `
    -Checksum $checksumSig `
    -ChecksumType 'sha512'

# If GPG has been just added, need to refresh to access to it from this session
Update-SessionEnvironment

CheckPGPSignature `
    -pgpKey "$toolsDir\$pgpKey" `
    -signatureFile "$sigFileName" `
    -file "$packageFileName"

Write-Host "Adding OpenVPN to the Trusted Publishers (needed to have a silent install of the TAP driver)..."
AddTrustedPublisherCertificate -file "$toolsDir\openvpn.cer"

Write-Host "Getting the state of the current OpenVPN service (if any)..."
# Needed to reset the state of the Interactive service if upgrading from a
# branch 2.4 or reinstalling a build from the branch 2.4
try {
    $previousInteractiveService = GetServiceProperties "OpenVPNServiceInteractive"
} catch {
    Write-Host "No previous OpenVPN interactive service detected."
}
# Needed for all cases 2.3 to 2.4 or 2.4 to 2.4.x and onwards
try {
    $previousService = GetServiceProperties "OpenVpnService"
} catch {
    Write-Host "No previous OpenVPN service detected."
}

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
