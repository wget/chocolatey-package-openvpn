$packageName = 'openvpn'
# By default: C:\ProgramData\chocolatey\lib\openvpn\tools
$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$fileType = 'exe'
# For a list of all silent arguments used
# https://github.com/OpenVPN/openvpn-build/blob/c92af79befec86f21b257b5defba0becb3d7641f/windows-nsis/openvpn.nsi#L551
# For their description
# https://github.com/OpenVPN/openvpn-build/blob/c92af79befec86f21b257b5defba0becb3d7641f/windows-nsis/openvpn.nsi#L107
$openvpnInstallerSilentArgs = '/S /SELECT_EASYRSA=1 /SELECT_TAP=0'
$tapDriverInstallerSilentArgs = '/S /SELECT_EASYRSA=1'
$validExitCodes = @(0)

$openvpnInstaller = "$toolsDir\openvpn_installer.exe"
$openvpnInstallerHash = ''
$openvpnInstallerPgpSignature = "$toolsDir\openvpn_installer.exe.asc"
$openvpnInstallerPgpSignatureHash = ''

$pgpPublicKeyNew = "$toolsDir\openvpn_public_key_new.asc"
$pgpPublicKeyNewHash = '3ed149e5b7bf35103ba65bd019f4285d28e1b15a013cb61fcbad5c03a643cbe9aa1501072b284ef7f809cec5b4b70fcde34447a5bf033e250bea65bd5f2f7d71'
$pgpPublicKeyOld = "$toolsDir\openvpn_public_key_old.asc"
$pgpPublicKeyOldHash = 'cd4b8eacf5667d335aa89f9860bbb3debad53f877d03609dfcdf578edc27f62131dfeaf678900a2ac0a753d9883046817cf6be5979117ab261d7ce5fc1dec9e0'

$trustedPublisherCertificateOld = "$toolsDir\openvpn_trusted_publisher_old.cer"
$trustedPublisherCertificateOldHash = '8f53adb36f1c61c50e11b8bdbef8d0ffb9b26665a69d81246551a0b455e72ec0b26a34dc9b65cb3750baf5d8a6d19896c3b4a31b578b15ab7086377955509fad'
$trustedPublisherCertificateNew = "$toolsDir\openvpn_trusted_publisher_new.cer"
$trustedPublisherCertificateNewHash = '3eea1c00fd27fb75bd254fb948bb5672714ef662832af475f567db3330a5c3db697d4e9d89c587f4c7ea9d97ac7445eeae6bb2d8de7edec63fceb213512be3c4'

$tapDriverInstallerOld = "$toolsDir\tap_driver_installer_old.exe"
$tapDriverInstallerOldHash = ''
$tapDriverInstallerOldPgpSignatureHash = ''
$tapDriverInstallerNew = "$toolsDir\tap_driver_installer_new.exe"
$tapDriverInstallerNewHash = ''
$tapDriverInstallerNewPgpSignatureHash = ''

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
Write-Host "Checking old OpenVPN Inc PGP public key hash..."
Get-ChecksumValid `
    -File "$pgpPublicKeyOld" `
    -Checksum "$pgpPublicKeyOldHash" `
    -ChecksumType 'sha512'
Write-Host "Checking new OpenVPN Inc PGP public key hash..."
Get-ChecksumValid `
    -File "$pgpPublicKeyNew" `
    -Checksum "$pgpPublicKeyNewHash" `
    -ChecksumType 'sha512'
Write-Host "Checking old OpenVPN Inc Trusted Publisher certificate hash..."
Get-ChecksumValid `
    -File "$trustedPublisherCertificateOld" `
    -Checksum "$trustedPublisherCertificateOldHash" `
    -ChecksumType 'sha512'
Write-Host "Checking new OpenVPN Inc Trusted Publisher certificate hash..."
Get-ChecksumValid `
    -File "$trustedPublisherCertificateNew" `
    -Checksum "$trustedPublisherCertificateNewHash" `
    -ChecksumType 'sha512'

# The GPG signature needs to have the same filename as the file checked but
# with the .asc suffix, otherwise gpg reports it cannot verify the file with
# the following message:
# gpg: no signed data
# gpg: can't hash datafile: No data
CheckPGPSignature `
    -pgpKey "$pgpPublicKeyNew" `
    -signatureFile "$openvpnInstallerPgpSignature" `
    -file "$openvpnInstaller"
CheckPGPSignature `
    -pgpKey "$pgpPublicKeyOld" `
    -signatureFile "$tapDriverInstallerOld.asc" `
    -file "$tapDriverInstallerOld"
CheckPGPSignature `
    -pgpKey "$pgpPublicKeyNew" `
    -signatureFile "$tapDriverInstallerNew.asc" `
    -file "$tapDriverInstallerNew"

# Due to this bug https://github.com/OpenVPN/tap-windows6/issues/63, the
# following step is not working any more because the OpenVPN installer
# is overridding our certificate by an outdated (incorrect one).
#Write-Host "Adding OpenVPN to the Trusted Publishers (needed to have a silent install of the TAP driver)..."
#AddTrustedPublisherCertificate -file "$certFileName"

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
    -PackageName "OpenVPN" `
    -FileType $fileType `
    -SilentArgs $openvpnInstallerSilentArgs `
    -File $openvpnInstaller `
    -ValidExitCodes $validExitCodes
    
# Install latest TAP which contains security fixes when possible, otherwise
# fall back to previously working installer when secure boot is enabled or
# when on Windows Server (which has stricter signing policies compared to
# standard Windows editions).
$Assem = (
	"System",
	"System.Runtime.InteropServices")
$Source = @"
using System;
using System.Runtime.InteropServices;

public class OS {
    public static bool IsWindowsServer() {
        return OS.IsOS(OS.OS_ANYSERVER);
    }

    const int OS_ANYSERVER = 29;

    [DllImport("shlwapi.dll", SetLastError=true, EntryPoint="#437")]
    private static extern bool IsOS(int os);
}
"@
Add-Type -ReferencedAssemblies $Assem -TypeDefinition $Source -Language CSharp
$isWindowsServer = [OS]::IsWindowsServer()

$isSecureBootEnabled = $false
try {
    $secureBoot = Get-ItemProperty -Path  'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\State\' -Name UEFISecureBootEnabled -ErrorAction SilentlyContinue
    if ($secureBoot.UEFISecureBootEnabled) {
        $isSecureBootEnabled = $true
    }
} catch {
}

# Needed to fix the aforementioned installer bug.
Write-Host "Adding OpenVPN to the Trusted Publishers (needed to have a silent install of the TAP driver)..."
if ($isWindowsServer -or $isSecureBootEnabled) {
    Write-Host "You are running Windows Server or have Secure Boot enabled. Installing previous TAP driver instead..."
    AddTrustedPublisherCertificate -file "$trustedPublisherCertificateOld"
    Install-ChocolateyInstallPackage `
        -PackageName "OpenVPN TAP driver" `
        -FileType $fileType `
        -SilentArgs $tapDriverInstallerSilentArgs `
        -File $tapDriverInstallerOld `
        -ValidExitCodes $validExitCodes
} else {
    AddTrustedPublisherCertificate -file "$trustedPublisherCertificateNew"
    Install-ChocolateyInstallPackage `
        -PackageName "OpenVPN TAP driver" `
        -FileType $fileType `
        -SilentArgs $tapDriverInstallerSilentArgs `
        -File $tapDriverInstallerNew `
        -ValidExitCodes $validExitCodes
}

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
if ($isWindowsServer -or $isSecureBootEnabled) {
    RemoveTrustedPublisherCertificate -file "$trustedPublisherCertificateOld"
} else {
    RemoveTrustedPublisherCertificate -file "$trustedPublisherCertificateNew"
}
