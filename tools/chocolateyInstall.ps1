$packageName = 'openvpn'
# By default: C:\ProgramData\chocolatey\lib\openvpn\tools
$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$fileType = 'exe'

# For a list of all silent arguments used
# https://github.com/OpenVPN/openvpn-build/blob/c92af79befec86f21b257b5defba0becb3d7641f/windows-nsis/openvpn.nsi#L551
# For their description
# https://github.com/OpenVPN/openvpn-build/blob/c92af79befec86f21b257b5defba0becb3d7641f/windows-nsis/openvpn.nsi#L107
$packageParams = Get-PackageParameters
if (!$packageParams['SELECT_SHORTCUTS']) { $packageParams['SELECT_SHORTCUTS'] = '1' }
if (!$packageParams['SELECT_OPENVPN']) { $packageParams['SELECT_OPENVPN'] = '1' }
if (!$packageParams['SELECT_SERVICE']) { $packageParams['SELECT_SERVICE'] = '1' }
if ($packageParams['SELECT_SERVICE'] -eq '1') {
    $serviceWanted = $true
} else {
    $serviceWanted = $false
}
if (!$packageParams['SELECT_TAP']) { $packageParams['SELECT_TAP'] = '1' }
if ($packageParams['SELECT_TAP'] -eq '1') {
    $tapDriverWanted = $true
} else {
    $tapDriverWanted = $false
}
if (!$packageParams['SELECT_OPENVPNGUI']) { $packageParams['SELECT_OPENVPNGUI'] = '1' }
if (!$packageParams['SELECT_ASSOCIATIONS']) { $packageParams['SELECT_ASSOCIATIONS'] = '1' }
if (!$packageParams['SELECT_OPENSSL_UTILITIES']) { $packageParams['SELECT_OPENSSL_UTILITIES'] = '1' }
# Contrary to the default installer we are installing easyrsa by default
if (!$packageParams['SELECT_EASYRSA']) { $packageParams['SELECT_EASYRSA'] = '1' }
if (!$packageParams['SELECT_PATH']) { $packageParams['SELECT_PATH'] = '1' }
if (!$packageParams['SELECT_LAUNCH']) { $packageParams['SELECT_LAUNCH'] = '1' }
if (!$packageParams['SELECT_OPENSSLDLLS']) { $packageParams['SELECT_OPENSSLDLLS'] = '1' }
if (!$packageParams['SELECT_LZODLLS']) { $packageParams['SELECT_LZODLLS'] = '1' }
if (!$packageParams['SELECT_PKCS11DLLS']) { $packageParams['SELECT_PKCS11DLLS'] = '1' }

$openvpnInstallerSilentArgs = '/S '
# Entries will be added to the string in random order since this is a dictionary.
foreach ($i in $packageParams.Keys) {
    $openvpnInstallerSilentArgs += "/$i=$($packageParams[$i]) "
}
$tapDriverInstallerSilentArgs = "/S /SELECT_EASYRSA=$($packageParams['SELECT_EASYRSA'])"

$validExitCodes = @(0)

$openvpnInstaller = "$toolsDir\openvpn_installer.exe"
$openvpnInstallerHash = '89E02F55CD34238AAC7CA6983FF54AD1B4CF23101DE82BE08F4C960DA7A41514663FD44B9AB5386815A2A2C97457DF595A369F552F1D8F7837F2D3F9ED0D7268'
$openvpnInstallerPgpSignature = "$toolsDir\openvpn_installer.exe.asc"
$openvpnInstallerPgpSignatureHash = '7BA86B05D9A9AAF82A4F3F9D7D612E12107FEE00803484D32217A89EAF94B5A865468C0279B4709B09AF1A4B6F79C5303E4E32F7BA7E141187137A7D79F59D12'

$pgpPublicKey = "$toolsDir\openvpn_public_key.asc"
$pgpPublicKeyHash = 'c7ee3cb0c7be11198cf39fb6a7bb4ab1217a9212676ae6743c0f434aad7e167e5f53d782e61513b746ba492ab2f07e747916c150a1acd555019f8468d2cee2e8'

$trustedPublisherCertificate = "$toolsDir\openvpn_trusted_publisher.cer"
$trustedPublisherCertificateHash = '8f53adb36f1c61c50e11b8bdbef8d0ffb9b26665a69d81246551a0b455e72ec0b26a34dc9b65cb3750baf5d8a6d19896c3b4a31b578b15ab7086377955509fad'

# Load custom functions
. "$toolsDir\utils\utils.ps1"

# If GPG has been just added, need to refresh to access to it from this session
Update-SessionEnvironment

Write-Host "Checking OpenVPN installer hash..."
Get-ChecksumValid `
    -File "$openvpnInstaller" `
    -Checksum "$openvpnInstallerHash" `
    -ChecksumType 'sha512'
Write-Host "Checking OpenVPN installer signature hash..."
Get-ChecksumValid `
    -File "$openvpnInstallerPgpSignature" `
    -Checksum "$openvpnInstallerPgpSignatureHash" `
    -ChecksumType 'sha512'
Write-Host "Checking OpenVPN Inc PGP public key hash..."
Get-ChecksumValid `
    -File "$pgpPublicKey" `
    -Checksum "$pgpPublicKeyHash" `
    -ChecksumType 'sha512'

# The GPG signature needs to have the same filename as the file checked but
# with the .asc suffix, otherwise gpg reports it cannot verify the file with
# the following message:
# gpg: no signed data
# gpg: can't hash datafile: No data
CheckPGPSignature `
    -pgpKey "$pgpPublicKey" `
    -signatureFile "$openvpnInstallerPgpSignature" `
    -file "$openvpnInstaller"

# Due to this bug https://github.com/OpenVPN/tap-windows6/issues/63, the
# following step is not working any more because the OpenVPN installer
# is overridding our certificate by an outdated (incorrect one).
#Write-Host "Adding OpenVPN to the Trusted Publishers (needed to have a silent install of the TAP driver)..."
#AddTrustedPublisherCertificate -file "$certFileName"

if ($serviceWanted) {
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
}

if ($tapDriverWanted) {
    Write-Host "Adding OpenVPN to the Trusted Publishers (needed to have a silent install of the TAP driver)..."
    AddTrustedPublisherCertificate -file "$trustedPublisherCertificate"
}

Install-ChocolateyInstallPackage `
    -PackageName "OpenVPN" `
    -FileType $fileType `
    -SilentArgs $openvpnInstallerSilentArgs `
    -File $openvpnInstaller `
    -ValidExitCodes $validExitCodes

if ($serviceWanted) {
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
}

Write-Host "Removing OpenVPN from the Trusted Publishers..."
RemoveTrustedPublisherCertificate -file "$trustedPublisherCertificate"