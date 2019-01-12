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
$openvpnInstallerHash = '89E02F55CD34238AAC7CA6983FF54AD1B4CF23101DE82BE08F4C960DA7A41514663FD44B9AB5386815A2A2C97457DF595A369F552F1D8F7837F2D3F9ED0D7268'
$openvpnInstallerPgpSignature = "$toolsDir\openvpn_installer.exe.asc"
$openvpnInstallerPgpSignatureHash = '7BA86B05D9A9AAF82A4F3F9D7D612E12107FEE00803484D32217A89EAF94B5A865468C0279B4709B09AF1A4B6F79C5303E4E32F7BA7E141187137A7D79F59D12'

$pgpPublicKeyOld = "$toolsDir\openvpn_public_key_old.asc"
$pgpPublicKeyOldHash = 'cd4b8eacf5667d335aa89f9860bbb3debad53f877d03609dfcdf578edc27f62131dfeaf678900a2ac0a753d9883046817cf6be5979117ab261d7ce5fc1dec9e0'
$pgpPublicKeyNew = "$toolsDir\openvpn_public_key_new.asc"
$pgpPublicKeyNewHash = '3ed149e5b7bf35103ba65bd019f4285d28e1b15a013cb61fcbad5c03a643cbe9aa1501072b284ef7f809cec5b4b70fcde34447a5bf033e250bea65bd5f2f7d71'

$trustedPublisherCertificateOld = "$toolsDir\openvpn_trusted_publisher_old.cer"
$trustedPublisherCertificateOldHash = '4d04bc2956171ae42a7baba030ca6ddd7a713e3752874c947b9745d58d12758a56bc47880e6f9d9b5db93558d6de17473018882c30f3bdf03ada46aae9d37d8a'
$trustedPublisherCertificateNew = "$toolsDir\openvpn_trusted_publisher_new.cer"
$trustedPublisherCertificateNewHash = 'e4bea4b8a1af6937565685bd83058ec32a138c193520f616b1c9f72dffa5fb2fbe9dc665baf3d0ff96b1479a82b21f59dc8df8f29a9610e83ae62c91ce3b83ea'

$tapDriverInstallerOld = "$toolsDir\tap_driver_installer_old.exe"
$tapDriverInstallerOldHash = '514F0DD1B7D8C4AAD5CC06882A96BE2096E57EB4228DF1D78F2BCC60003AF8EBC057CCE5EEDDA9B8A2DC851A52895C0A4B07556B4535271767817D9EA45E0713'
$tapDriverInstallerOldPgpSignatureHash = '76FC4AB3854A13032FEE735460CCCA6B03DDA570E81913BD576D6DF952654B811CA1D5FC7674D7DBF308E5927780D608C00FA1ADD709E6BC35644D6B699ADCD2'
$tapDriverInstallerNew = "$toolsDir\tap_driver_installer_new.exe"
$tapDriverInstallerNewHash = '13D8E365ED985FC3C510287D977E33205F41B3569B888E745157ECC774DA20AF4D58A98CDC582646A9BB7FD84AAD2A55E9AAD895F12A9A2E125E7A0C88B1726D'
$tapDriverInstallerNewPgpSignatureHash = 'C16CD8B470A92BBC89226DD1B0720E994022F940C1D81F26E2BB27B39B840A21373A3F2848AFD55031DCF1610D0D56C91791AEBD74BE3638B1FF9DF94A1998C7'

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
# In order to avoid infecting the default AppDomain with our class OS, we are
# creating a sub process
# src.: https://stackoverflow.com/a/3374673/3514658
$job = Start-Job -ScriptBlock {
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
    [OS]::IsWindowsServer()
}
Wait-Job $job | Out-Null
$isWindowsServer = Receive-Job $job

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
