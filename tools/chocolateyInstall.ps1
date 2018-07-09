$packageName = 'openvpn'
# By default: C:\ProgramData\chocolatey\lib\openvpn\tools
$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$fileType = 'exe'
# For a list of all silent arguments used
# https://github.com/OpenVPN/openvpn-build/blob/c92af79befec86f21b257b5defba0becb3d7641f/windows-nsis/openvpn.nsi#L551
# For their description
# https://github.com/OpenVPN/openvpn-build/blob/c92af79befec86f21b257b5defba0becb3d7641f/windows-nsis/openvpn.nsi#L107
$silentArgs = '/S /SELECT_EASYRSA=1 /SELECT_TAP=0'
$silentArgsTap = '/S /SELECT_EASYRSA=1'
$validExitCodes = @(0)

$packageFileName = "$toolsDir\$($packageName)Install.$fileType"
$sigFileName = "$toolsDir\$($packageName)Install.$fileType.asc"
$pgpKeyFileName = "$toolsDir\openvpn_public_key.asc"
$oldPgpKeyFilename = "$toolsDir\old_openvpn_public_key.asc"

$oldCertFileName = "$toolsDir\old_openvpn_trusted_publisher.cer"
$newCertFileName = "$toolsDir\new_openvpn_trusted_publisher.cer"
$oldTapInstaller = "$toolsDir\oldTapInstaller.exe"
$newTapInstaller = "$toolsDir\newTapInstaller.exe"

$packageChecksum = '89E02F55CD34238AAC7CA6983FF54AD1B4CF23101DE82BE08F4C960DA7A41514663FD44B9AB5386815A2A2C97457DF595A369F552F1D8F7837F2D3F9ED0D7268'
$sigChecksum = '7BA86B05D9A9AAF82A4F3F9D7D612E12107FEE00803484D32217A89EAF94B5A865468C0279B4709B09AF1A4B6F79C5303E4E32F7BA7E141187137A7D79F59D12'
$pgpKeyChecksum = '3ED149E5B7BF35103BA65BD019F4285D28E1B15A013CB61FCBAD5C03A643CBE9AA1501072B284EF7F809CEC5B4B70FCDE34447A5BF033E250BEA65BD5F2F7D71'
$oldPgpKeyChecksum = 'CD4B8EACF5667D335AA89F9860BBB3DEBAD53F877D03609DFCDF578EDC27F62131DFEAF678900A2AC0A753D9883046817CF6BE5979117AB261D7CE5FC1DEC9E0'
$oldCertChecksum = '8F53ADB36F1C61C50E11B8BDBEF8D0FFB9B26665A69D81246551A0B455E72EC0B26A34DC9B65CB3750BAF5D8A6D19896C3B4A31B578B15AB7086377955509FAD'
$newCertChecksum = '3EEA1C00FD27FB75BD254FB948BB5672714EF662832AF475F567DB3330A5C3DB697D4E9D89C587F4C7EA9D97AC7445EEAE6BB2D8DE7EDEC63FCEB213512BE3C4'

$oldTapChecksum = ''
$oldTapSigChecksum = ''
$newTapChecksum = ''
$newTapSigChecksum = ''

# Load custom functions
. "$toolsDir\utils\utils.ps1"

# If GPG has been just added, need to refresh to access to it from this session
Update-SessionEnvironment

Write-Host "Checking OpenVPN installer hash..."
Get-ChecksumValid `
    -File "$packageFileName" `
    -Checksum "$packageChecksum" `
    -ChecksumType 'sha512'
Write-Host "Checking OpenVPN installer signature hash..."
Get-ChecksumValid `
    -File "$sigFileName" `
    -Checksum "$sigChecksum" `
    -ChecksumType 'sha512'
Write-Host "Checking old OpenVPN Inc PGP public key hash..."
Get-ChecksumValid `
    -File "$oldPgpKeyFileName" `
    -Checksum "$oldPgpKeyChecksum" `
    -ChecksumType 'sha512'
Write-Host "Checking new OpenVPN Inc PGP public key hash..."
Get-ChecksumValid `
    -File "$pgpKeyFileName" `
    -Checksum "$pgpKeyChecksum" `
    -ChecksumType 'sha512'
Write-Host "Checking old OpenVPN Inc Trusted Publisher certificate hash..."
Get-ChecksumValid `
    -File "$oldCertFileName" `
    -Checksum "$oldCertChecksum" `
    -ChecksumType 'sha512'
Write-Host "Checking new OpenVPN Inc Trusted Publisher certificate hash..."
Get-ChecksumValid `
    -File "$newCertFileName" `
    -Checksum "$newCertChecksum" `
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
CheckPGPSignature `
    -pgpKey "$oldPgpKeyFileName" `
    -signatureFile "$oldTapInstaller.asc" `
    -file "$oldTapInstaller"
CheckPGPSignature `
    -pgpKey "$pgpKeyFileName" `
    -signatureFile "$newTapInstaller.asc" `
    -file "$newTapInstaller"

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
    -SilentArgs $silentArgs `
    -File $packageFileName `
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
    AddTrustedPublisherCertificate -file "$oldCertFileName"
    Install-ChocolateyInstallPackage `
        -PackageName "OpenVPN TAP driver" `
        -FileType $fileType `
        -SilentArgs $silentArgsTap `
        -File $oldTapInstaller `
        -ValidExitCodes $validExitCodes
} else {
    AddTrustedPublisherCertificate -file "$newCertFileName"
    Install-ChocolateyInstallPackage `
        -PackageName "OpenVPN TAP driver" `
        -FileType $fileType `
        -SilentArgs $silentArgsTap `
        -File $newTapInstaller `
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
    RemoveTrustedPublisherCertificate -file "$oldCertFileName"
} else {
    RemoveTrustedPublisherCertificate -file "$newCertFileName"
}
