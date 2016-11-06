# OpenVPN Community

This repository contains the sources of the [package OpenVPN Community](https://chocolatey.org/packages/openvpn/) for [Chocolatey, the package manager for Windows](https://chocolatey.org/).

## Testing

Launch a PowerShell prompt as Administrator.

Build the `.nupkg` package from the `.nuspec` file with

    cpack

Test and install the `.nupkg` package with the following line.

* `-source` is used to specify where to find the sources. As our package uses gpg as a dependency to check the signatures, we need to specify from where to get it (here, from the Chocolatey website)
* The install must be forced (`-f`) if the same version is already installed (will remove and reinstall the package from the updated `.nupkg`)
* Test is performed in debug mode (`-d`)
* Being verbose (`-v`)
* Avoid asking for confirmation when installing the package (`--yes`)

More information is available in the [Chocolatey documentation](https://chocolatey.org/docs/create-packages#testing-your-package).

    choco install openvpn -fdv -source "'.;https://chocolatey.org/api/v2/'" --yes
    
Do not forget to test the uninstallation as well:

    choco uninstall openvpn -dv --yes

## Deploy to Chocolatey

Get your API key on your [Chocolatey account page](https://chocolatey.org/account). The command you will need to type is like this one:

    choco apiKey -k 12345678-90ab-cdef-1234-567890abcdef -source https://chocolatey.org/

Push your package to moderation review:

    choco push .\openvpn.2.3.13.nupkg -s https://chocolatey.org/

About 30 minutes later, you should receive an email revealing if the automatic tests have passed. [If all tests have succeeded](https://github.com/chocolatey/package-validator/wiki#requirements), the package will be ready for review and will be approved manually within 48 hours by a Chocolatey admin. For urgent releases like CVE fixes, ping [Rob Reynolds](https://github.com/ferventcoder), Chocolatey founder, on [Gitter](https://gitter.im/chocolatey/choco).

## Contribute

If you have comments to make or push requests to submit, feel free to contribute to this repository.

## License

[As Apache 2 software can be included in GPLv3 projects, but GPLv3 software cannot be included in Apache projects](https://www.apache.org/licenses/GPL-compatibility.html) and in order to comply with [NuGet](https://www.nuget.org/policies/About) and Chocolatey licenses, this software is licensed under the terms of the Apache License 2.0. 
