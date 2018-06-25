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

$packageChecksum = '613941791DA88123F10D0CAE9CF3AABA1B82FF4332E2E2A21DA1B0D1BD1FCBBDB9AC77CE9354369DF9640BBFDCD82DE0E1AC27E7A9B9E7964C9A53791ABFDD97'
$sigChecksum = '1E6402E416F2989854B1DE6D61AD64A0EB73FE893D3FD3A9B08E6C78BD489D29394B07E560C44E2D6732E9329E35BAA0DFFD570F5BA1852420E69C469D5B966D'
$pgpKeyChecksum = '3ED149E5B7BF35103BA65BD019F4285D28E1B15A013CB61FCBAD5C03A643CBE9AA1501072B284EF7F809CEC5B4B70FCDE34447A5BF033E250BEA65BD5F2F7D71'
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
