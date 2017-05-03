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
    $Latest.checksum    = Get-RemoteChecksum -a sha512 $Latest.url
    $Latest.checksumSig = Get-RemoteChecksum -a sha512 $Latest.urlSig
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
