$packageName = 'openvpn'
$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$fileType = 'exe'
$url = 'https://swupdate.openvpn.org/community/releases/openvpn-install-2.3.13-I601-i686.exe'
$url64 = 'https://swupdate.openvpn.org/community/releases/openvpn-install-2.3.13-I601-x86_64.exe'
# For a list of all silent arguments used
# https://github.com/OpenVPN/openvpn-build/blob/master/windows-nsis/openvpn.nsi#L431
# For their description
# https://github.com/OpenVPN/openvpn-build/blob/master/windows-nsis/openvpn.nsi#L102
$silentArgs = '/S /SELECT_EASYRSA=1'
$validExitCodes = @(0)
$checksum = '182c7d906a9fc081080dc3b4459e3ec867681e6cb645a75d2ebe04d1d06ed14605622c4f34ef4d352bbdf68d81b06e2de634bed75cdb7d939e7f2cdd7973d986'
$checksum64='9ad6cb9afc7932dc883835cf60b5efd94ee3f0914d1fb948982056abd04df9aeb8eca3554bd13acb356602ee85e202276397a3d0fab78e7f4d854406703e007e'

# The setup to install a driver for the virtual network device TAP asks us if
# we want to trust the certificate from OpenVPN Technologies, Inc. In order to
# have a complete silent install, we will add that certificate to the Windows
# keystore.
#
# In order to get that certificate, we had to
# - install the driver accepting the certificate,
# - tick the checkbox "Always trust software from "OpenVPN Technologies, Inc.""
#   which has the effect to consider OpenVPN as a trusted publisher
# - then run certmgr.msc,
# - expand "Certificates (Local Computer) –> Trusted Publishers –> Certificates",
# - right click the OpenVPN Technologies certificate
# - select "All Tasks –> Export..."
# - click Next
# - select Base64 encoded x.509 (.CER) and click Next
# - click Browse, navigate to the location you wish to save the certificate and click Next
# - click Finish
# - click OK
# The certificate is now in the location specified.
# src.: https://goo.gl/o3BVGJ
# Next time we install the software, even if we remove that certificate,
# Windows will not ask us to confirm the installation as the driver is cached
# in the Drivers Store (C:\Windows\Inf). To simulate a first install we need to
# remove the cached drivers as well.
# src.: https://goo.gl/Zbcs6T
Write-Host "Adding OpenVPN driver signing certificate to have a silent install..."
Start-ChocolateyProcessAsAdmin "certutil -addstore 'TrustedPublisher' '$toolsDir\openvpn.cer'"

Write-Host "Installing OpenVPN... The service will be set (reset) to 'Manual' and will not be started. Manual intervention required."
Install-ChocolateyPackage `
    -PackageName "$packageName" `
    -FileType "$fileType" `
    -SilentArgs "$silentArgs" `
    -Url "$url" `
    -Url64bit "$url64" `
    -ValidExitCodes "$validExitCodes" `
    -Checksum "$checksum" `
    -ChecksumType 'sha512' `
    -Checksum64 "$checksum64" `
    -ChecksumType64 'sha512'

# The installer changes the PATH, apply these changes in the current PowerShell
# session.
Update-SessionEnvironment
