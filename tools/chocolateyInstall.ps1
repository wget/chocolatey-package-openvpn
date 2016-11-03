﻿$packageName = 'openvpn'
$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$fileType = 'exe'
$url = 'https://swupdate.openvpn.org/community/releases/openvpn-install-2.3.12-I602-i686.exe'
$url64 = 'https://swupdate.openvpn.org/community/releases/openvpn-install-2.3.12-I602-x86_64.exe'
# For a list of all silent arguments used
# https://github.com/OpenVPN/openvpn-build/blob/master/windows-nsis/openvpn.nsi#L431
# For their description
# https://github.com/OpenVPN/openvpn-build/blob/master/windows-nsis/openvpn.nsi#L102
$silentArgs = '/S /SELECT_EASYRSA=1'
$validExitCodes = @(0)
$checksum = "0d6503300d2b9c9a1cb3b4e0af24528227c6b1d0e72c7b99ef070177fcfa1b1711a2a718df615e5be89d20376fe955481232c39848c5434fd63cd591f9d9711c"
$checksum64="988870a8e8277282b5fb064379594a5fd618456676ad06d1be74311754cb270c62e411aba78db6b7be08a9d31ea4e66b313373a9a461894d57f99efe870f94ca"

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
Start-ChocolateyProcessAsAdmin "certutil -addstore 'TrustedPublisher' '$toolsDir\openvpn.cer'"

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
