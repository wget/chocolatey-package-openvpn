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

$packageFileName = "$toolsDir\$($packageName)Install.$fileType"
$sigFileName = "$toolsDir\$($packageName)Install.$fileType.asc"
$pgpKeyFileName = "$toolsDir\openvpn_public_key.asc"
$certFileName = "$toolsDir\openvpn.cer"

$packageChecksum = 'A0DA5281A38C2445AF1C89F3153BE6CED9D419B2E2C94C0326CD0821C6DAD682808ADA2BBA5643754C5C9971B84940F4020163AF4053D83FF13E605748CB13F0'
$sigChecksum = 'CF44F472D7F12F35C20F1E8197170D5DE79CDAE03AB5C37E77D664983CEF78D66372C4B1408B537E79B2218170F7589EE41BF07BD16C0D7015C26B5C05EF95D3'
$pgpKeyChecksum = '7205EB2A23DF08313255FA4A75CF1E8D00F8777BEDEC48FE3B31FFD9EC297AB683193DA585AF3FA9E35D9F17390A3E2C0BBD30AAB0524F44F0EFC69EDE02A6F3'
$certChecksum = '8F53ADB36F1C61C50E11B8BDBEF8D0FFB9B26665A69D81246551A0B455E72EC0B26A34DC9B65CB3750BAF5D8A6D19896C3B4A31B578B15AB7086377955509FAD'

# Load custom functions
. "$toolsDir\utils\utils.ps1"

# If GPG has been just added, need to refresh to access to it from this session
Update-SessionEnvironment

Get-ChecksumValid `
    -File "$packageFileName" `
    -Checksum "$packageChecksum" `
    -ChecksumType 'sha512'
Get-ChecksumValid `
    -File "$sigFileName" `
    -Checksum "$sigChecksum" `
    -ChecksumType 'sha512'
Get-ChecksumValid `
    -File "$pgpKeyFileName" `
    -Checksum "$pgpKeyChecksum" `
    -ChecksumType 'sha512'
Get-ChecksumValid `
    -File "$certFileName" `
    -Checksum "$certChecksum" `
    -ChecksumType 'sha512'

# The GPG signature needs to have the same filename as the file checked but
# with the .asc suffix, otherwise gpg reports it cannot verify the file with
# the following message:
# gpg: no signed data
# gpg: can't hash datafile: No data
CheckPGPSignature `
    -pgpKey "$pgpKeyFileName" `
    -signatureFile "$sigFileName" `
    -file "$packageFileName"

Write-Host "Adding OpenVPN to the Trusted Publishers (needed to have a silent install of the TAP driver)..."
AddTrustedPublisherCertificate -file "$certFileName"

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
RemoveTrustedPublisherCertificate -file "$certFileName"
