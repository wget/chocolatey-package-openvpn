import-module au

$releases = "https://build.openvpn.net/downloads/releases/"

function global:au_SearchReplace {
   @{
        ".\tools\chocolateyInstall.ps1" = @{
            "(^[$]url\s*=\s*)('.*')"         = "`$1'$($Latest.url)'"
            "(^[$]checksum\s*=\s*)('.*')"    = "`$1'$($Latest.checksum)'"
            "(^[$]urlSig\s*=\s*)('.*')"      = "`$1'$($Latest.urlSig)'"
            "(^[$]checksumSig\s*=\s*)('.*')" = "`$1'$($Latest.checksumSig)'"
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
    $client.DownloadFile($Latest.url, $filePath)
    $Latest.checksum = Get-FileHash $filePath -Algorithm sha512 | % Hash

    $filePath = "$toolsPath/openvpnInstall.exe.asc"
    Write-Host "Downloading installer signature to '$filePath'..."
    $client.DownloadFile($Latest.urlSig, $filePath)
    $Latest.checksumSig = Get-FileHash $filePath -Algorithm sha512 | % Hash
}

function global:au_GetLatest {
    $versionPage = $releases + "latest/LATEST.txt"
    $versionPage = Invoke-WebRequest -UseBasicParsing -Uri $versionPage
    $version = $versionPage.Content -match "(?<=OpenVPN stable version: )[0-9.]+"
    $version = $matches[0]

    $versionInstaller = $versionPage.Content -match "(?<=OpenVPN stable installer version: ).+"
    $versionInstaller = $matches[0]

    $url = $releases + "openvpn-install-" + $versionInstaller + ".exe"
    $urlSig = $url + ".asc"

    @{
        version = $version
        url     = $url
        urlSig  = $urlSig
    }
}

update -ChecksumFor none
