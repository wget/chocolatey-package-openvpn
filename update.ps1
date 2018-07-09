import-module au

$releases = "https://build.openvpn.net/downloads/releases/"
$url = 'https://build.openvpn.net/downloads/releases/latest/openvpn-install-latest-stable.exe'
$urlSig = 'https://build.openvpn.net/downloads/releases/latest/openvpn-install-latest-stable.exe.asc'

$oldTapInstallerUrl = 'http://build.openvpn.net/downloads/releases/tap-windows-9.21.2.exe'
$oldTapInstallerUrlSig = 'http://build.openvpn.net/downloads/releases/tap-windows-9.21.2.exe.asc'
$newTapInstallerUrl = 'http://build.openvpn.net/downloads/releases/tap-windows-9.22.1-I601.exe'
$newTapInstallerUrlSig = 'http://build.openvpn.net/downloads/releases/tap-windows-9.22.1-I601.exe.asc'

function global:au_SearchReplace {
   @{
        ".\tools\chocolateyInstall.ps1" = @{
            "(^[$]packageChecksum\s*=\s*)('.*')"    = "`$1'$($Latest.packageChecksum)'"
            "(^[$]sigChecksum\s*=\s*)('.*')" = "`$1'$($Latest.sigChecksum)'"
            "(^[$]oldTapChecksum\s*=\s*)('.*')" = "`$1'$($Latest.oldTapChecksum)'"
            "(^[$]oldTapSigChecksum\s*=\s*)('.*')" = "`$1'$($Latest.oldTapSigChecksum)'"
            "(^[$]newTapChecksum\s*=\s*)('.*')" = "`$1'$($Latest.newTapChecksum)'"
            "(^[$]newTapSigChecksum\s*=\s*)('.*')" = "`$1'$($Latest.newTapSigChecksum)'"
        }
    }
}

function au_BeforeUpdate {
    # We can't rely on Get-RemoteChecksum as we want to have the files locally
    # as well and this function will download a local copy of the file, just to
    # compute its hashes, then drop it. We can't rely completely on
    # Get-RemoteFiles either as that function is only taking Latest URLs (x64
    # and x32) into account. The signatures are not supported.
    # src.: https://github.com/majkinetor/au/tree/master/AU/Public
    $client = New-Object System.Net.WebClient
    $toolsPath = Resolve-Path tools

    $filePath = "$toolsPath/openvpnInstall.exe"
    Write-Host "Downloading installer to '$filePath'..."
    $client.DownloadFile($url, $filePath)
    $Latest.packageChecksum = Get-FileHash $filePath -Algorithm sha512 | % Hash

    $filePath = "$toolsPath/openvpnInstall.exe.asc"
    Write-Host "Downloading installer signature to '$filePath'..."
    $client.DownloadFile($urlSig, $filePath)
    $Latest.sigChecksum = Get-FileHash $filePath -Algorithm sha512 | % Hash

    $filePath = "$toolsPath/oldTapInstaller.exe"
    Write-Host "Downloading old TAP installer to '$filePath'..."
    $client.DownloadFile($oldTapInstallerUrl, $filePath)
    $Latest.oldTapChecksum = Get-FileHash $filePath -Algorithm sha512 | % Hash

    $filePath = "$toolsPath/oldTapInstaller.exe.asc"
    Write-Host "Downloading old TAP installer signature to '$filePath'..."
    $client.DownloadFile($oldTapInstallerUrlSig, $filePath)
    $Latest.oldTapSigChecksum = Get-FileHash $filePath -Algorithm sha512 | % Hash

    $filePath = "$toolsPath/newTapInstaller.exe"
    Write-Host "Downloading new TAP installer to '$filePath'..."
    $client.DownloadFile($newTapInstallerUrl, $filePath)
    $Latest.newTapChecksum = Get-FileHash $filePath -Algorithm sha512 | % Hash

    $filePath = "$toolsPath/newTapInstaller.exe.asc"
    Write-Host "Downloading new TAP installer signature to '$filePath'..."
    $client.DownloadFile($newTapInstallerUrlSig, $filePath)
    $Latest.newTapSigChecksum = Get-FileHash $filePath -Algorithm sha512 | % Hash
}

function global:au_GetLatest {
    $versionPage = $releases + "latest/LATEST.txt"
    $versionPage = Invoke-WebRequest -UseBasicParsing -Uri $versionPage
    $version = $versionPage.Content -match "(?<=OpenVPN stable version: )[0-9.]+"
    $version = $matches[0]

    @{
        version = $version
    }
}

update -ChecksumFor none
