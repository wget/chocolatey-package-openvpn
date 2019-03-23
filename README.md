# OpenVPN
[![Build status](https://ci.appveyor.com/api/projects/status/ljn8uk100etk8dcc?svg=true)](https://ci.appveyor.com/project/wget/chocolatey-package-openvpn)

OpenVPN provides flexible VPN solutions to secure your data communications, whether it's for Internet privacy, remote access for employees, securing IoT, or for networking Cloud data centers.

## Notes

* This Chocolatey package:
  * installs the old tap driver (9.22.1) when Windows Server or Secure Boot is detected
  * installs the new driver in other cases

  These steps were needed in order to fix the following upstream bug:
  * Upstream installer I601 included tap-windows6 driver 9.22.1 which had one security fix and dropped Windows Vista support.
  * Upstream installer I602 reverted back to tap-windows 9.21.2 due to driver being rejected on freshly installed Windows 10 rev 1607 and later when Secure Boot was enabled. The failure was due to the new, more strict driver signing requirements required by Microsoft.

* This Chocolatey package considers the following [upstream parameters](https://github.com/OpenVPN/openvpn-build/blob/c92af79befec86f21b257b5defba0becb3d7641f/windows-nsis/openvpn.nsi#L551). By default, when not specified, they are considered as being set to `1`.

  * `/SELECT_OPENVPN`: Install OpenVPN user-space components, including openvpn.exe.
  * `/SELECT_OPENVPNGUI`: Install OpenVPN GUI by Mathias Sundman.
  * `/SELECT_TAP`: Install/upgrade the TAP virtual device driver.
  * `/SELECT_EASYRSA`: Install OpenVPN RSA scripts for X509 certificate management. Due to popular demand and contrary to the upstream installer, this Chocolatey package is installing them by default.
  * `/SELECT_OPENSSLDLLS`: Install OpenSSL DLLs locally (may be omitted if DLLs are already installed globally).
  * `/SELECT_LZODLLS`: Install LZO DLLs locally (may be omitted if DLLs are already installed globally).
  * `/SELECT_PKCS11DLLS`: Install PKCS#11 helper DLLs locally (may be omitted if DLLs are already installed globally).
  * `/SELECT_SERVICE`: Install the OpenVPN service wrappers.
  * `/SELECT_OPENSSL_UTILITIES`: Install the OpenSSL Utilities (used for generating public/private key pairs).
  * `/SELECT_PATH`: Add OpenVPN executable directory to the current user's PATH.
  * `/SELECT_SHORTCUTS`: Add OpenVPN shortcuts to the current user's desktop and start menu.
  * `/SELECT_ASSOCIATIONS`: Register OpenVPN config file association (*.ovpn).
  * `/SELECT_LAUNCH`: Launch OpenVPN GUI on user logon.

* Setting options to `0` while previous installations defined them to `1` won't necessarily disable/remove the feature. This hugely depends on the underling upstream installer. e.g. if you set `/SELECT_TAP=0` while the TAP driver has been previously installed by other means, this doesn't automatically uninstall the TAP driver.

* Using these parameters is done [like described in the Chocolatey docs](https://chocolatey.org/docs/how-to-parse-package-parameters-argument#installing-with-package-parameters). e.g. to prevent desktop and start menu shortcuts and file associations from being created, use the following command:
  ```
  choco install openvpn --params "'/SELECT_SHORTCUTS=0 /SELECT_ASSOCIATIONS=0'"
  ```

## Contributions

* This repository contains the sources of the [package OpenVPN](https://chocolatey.org/packages/openvpn/) for [Chocolatey, the package manager for Windows](https://chocolatey.org/).

* Please report [here](https://github.com/wget/chocolatey-package-openvpn/issues) any issue you may encounter with this Chocolatey package.