$packageName = 'openvpn'
$tools = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$installerType = 'EXE'
$url = '{{DownloadUrl}}'
$url64 = '{{DownloadUrlx64}}'
$silentArgs = '/S /SELECT_EASYRSA=1'
$validExitCodes = @(0)

Start-ChocolateyProcessAsAdmin "certutil -addstore 'TrustedPublisher' '$tools\openvpn.cer'"
Install-ChocolateyPackage "$packageName" "$installerType" "$silentArgs" "$url" "$url64"  -validExitCodes $validExitCodes
