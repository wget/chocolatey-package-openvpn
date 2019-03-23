import-module au

$releases = "https://build.openvpn.net/downloads/releases/"
$openvpnInstallerUrl = 'https://build.openvpn.net/downloads/releases/latest/openvpn-install-latest-stable.exe'
$openvpnInstallerPgpSignatureUrl = 'https://build.openvpn.net/downloads/releases/latest/openvpn-install-latest-stable.exe.asc'

function global:au_SearchReplace {
   @{
        ".\tools\chocolateyInstall.ps1" = @{
            "(^[$]openvpnInstallerHash\s*=\s*)('.*')"    = "`$1'$($Latest.openvpnInstallerHash)'"
            "(^[$]openvpnInstallerPgpSignatureHash\s*=\s*)('.*')" = "`$1'$($Latest.openvpnInstallerPgpSignatureHash)'"
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

    $filePath = "$toolsPath/openvpn_installer.exe"
    Write-Host "Downloading installer to '$filePath'..."
    $client.DownloadFile($openvpnInstallerUrl, $filePath)
    $Latest.openvpnInstallerHash = Get-FileHash $filePath -Algorithm sha512 | % Hash

    $filePath = "$toolsPath/openvpn_installer.exe.asc"
    Write-Host "Downloading installer signature to '$filePath'..."
    $client.DownloadFile($openvpnInstallerPgpSignatureUrl, $filePath)
    $Latest.openvpnInstallerPgpSignatureHash = Get-FileHash $filePath -Algorithm sha512 | % Hash
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