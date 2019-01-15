# OpenVPN
[![Build status](https://ci.appveyor.com/api/projects/status/ljn8uk100etk8dcc?svg=true)](https://ci.appveyor.com/project/wget/chocolatey-package-openvpn)

OpenVPN provides flexible VPN solutions to secure your data communications, whether it's for Internet privacy, remote access for employees, securing IoT, or for networking Cloud data centers.

## Notes

* This package installs OpenVPN and, contrary to the upstream installer, chooses the right TAP driver to install depending on the version of Windows used.

  Technical explanation of the upstream bug:
  * Upstream installer I601 included tap-windows6 driver 9.22.1 which had one security fix and dropped Windows Vista support.
  * Upstream installer I602 reverted back to tap-windows 9.21.2 due to driver being rejected on freshly installed Windows 10 rev 1607 and later when Secure Boot was enabled. The failure was due to the new, more strict driver signing requirements required by Microsoft.

  To solve the issue, this Chocolatey package installer:
  * installs the old tap driver (9.22.1) when Windows Server or Secure Boot is detected
  * installs the new driver in other cases

* This Chocolatey package can be configured in the following ways. [Upstream parameters](https://github.com/OpenVPN/openvpn-build/blob/c92af79befec86f21b257b5defba0becb3d7641f/windows-nsis/openvpn.nsi#L551) are taken into account and passed to the underlying installers.

  * `/SELECT_OPENVPN`: Install OpenVPN user-space components, including openvpn.exe.
  * `/SELECT_OPENVPNGUI`: Install OpenVPN GUI by Mathias Sundman.
  * `/SELECT_TAP`: Install/upgrade the TAP virtual device driver.
  * `/SELECT_EASYRSA`: Install OpenVPN RSA scripts for X509 certificate management. Due to popular demand and contrary to the upstream installer, this Chocolatey package is installing them by default.
  * `/SELECT_OPENSSLDLLS`: Install OpenSSL DLLs locally (may be omitted if DLLs are already installed globally).
  * `/SELECT_LZODLLS`: Install LZO DLLs locally (may be omitted if DLLs are already installed globally).
  * `/SELECT_PKCS11DLLS`: Install PKCS#11 helper DLLs locally (may be omitted if DLLs are already installed globally).
  * `/SELECT_SERVICE`: Install the OpenVPN service wrappers. Contrary to the upstream installer, this Chocolatey package will restore the services to the states they were before upgrading OpenVPN. This means the services may be restarted if they were previously started when you tried to upgrade this Chocolatey package. This Chocolatey package takes into account an upgrade path from pre 2.4 OpenVPN where the number of services and the way they behaved were different.
  * `/SELECT_OPENSSL_UTILITIES`: Install the OpenSSL Utilities (used for generating public/private key pairs).
  * `/SELECT_PATH`: Add OpenVPN executable directory to the current user's PATH.
  * `/SELECT_SHORTCUTS`: Add OpenVPN shortcuts to the current user's desktop and start menu.
  * `/SELECT_ASSOCIATIONS`: Register OpenVPN config file association (*.ovpn).
  * `/SELECT_LAUNCH`: Launch OpenVPN GUI on user logon.

* All the aforementionned options are automatically set to `1` by the upstream installers/this Chocolatey package when they are not specified.

* If you are explicitly specifying options to `0` while they have been defined to `1` during the first installation, they won't be necessarily disabled/removed automatically. This hugely depends on the underling upstream installers. e.g. if you set `/SELECT_TAP=0` while the TAP driver has been already previously installed by other means, this doesn't mean the TAP driver won't be uninstalled automatically.

* To use these parameters, simply [install them like described in the Chocolatey docs](https://chocolatey.org/docs/how-to-parse-package-parameters-argument#installing-with-package-parameters). e.g. to prevent shortcuts and file associations from being created, use the following command:
  ```
  choco install openvpn --params "'/SELECT_SHORTCUTS=0 /SELECT_ASSOCIATIONS=0'"
  ```


This repository contains the sources of the [package OpenVPN](https://chocolatey.org/packages/openvpn/) for [Chocolatey, the package manager for Windows](https://chocolatey.org/).

[For more information, please refer to the instructions available in the parent repository](https://github.com/wget/chocolatey-packages).
