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

$packageChecksum = '2BA52477B898663B3D88594BAAB145725FB327644A5A95317A176BA2C4A0FCF946C082EAAFF094AFCB9BC049A8B4D7ED8A9317F79D5BF04A81778C55A5ADDE39'
$sigChecksum = '1966BA2ABB7C5D6E043FABF84439547FBF3232D9A9213486674CCB75EA99473BE3D38CA28BC1264F9B90C75A70BB57BAD2A72585C7A887F93ED73E9934AF710E'
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
