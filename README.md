ESXi-Customizer is a user-friendly script that automates the process
of customizing the ESXi install ISO with drivers that are not originally
included. Unlike other scripts and manuals that are available for this
purpose ESXi-Customizer runs entirely on Windows and does not require any
knowledge of or access to Linux.

Requirements
- The script runs on Windows XP or newer (both 32-bit and 64-bit).
- For customizing ESXi 4.1 Windows 7 (32-bit or 64-bit) or Windows Server
  2008 R2 and administrative privileges are required.
- You need to have a copy of the original VMware install ISO. It is available
  at VMware [http://www.vmware.com/go/esxi] (free registration required to
  download). The script currently supports ESXi version 4.1, 5.0, 5.1 and 5.5.
- For ESXi 4.1 you need to have a OEM.tgz file with a custom driver
- For ESXi 5.x you need to have a OEM.tgz, a VIB file or an Offline Bundle
  ZIP file
- A good source for ESXi 4.1 and 5.x community drivers is Dave Mishchenko's
  vm-help.com site.
  See the ESXi 4.1 Whitebox HCL [http://www.vm-help.com/Whitebox_HCL.php]
  and the forums there [http://www.vm-help.com/forums]

Notes on customizing ESXi 5.x
- For technical background information read my blog post about
  "The anatomy of the ESXi 5.0 installation CD - and how to customize it" at
  [http://www.v-front.de/2011/08/anatomy-of-esxi-50-installation-cd-and.html]
  Please note that you need an ESXi 5.x compatible OEM.tgz file for this,
  files made for earlier ESXi versions will not work!
- Since version 2.5 you can also add VIB files and Offline bundles to an
  ESXi 5.x ISO. Commercially distributed driver packages are often distributed
  in one of these formats.
  For more information on VIB files and Offline bundles read my blog post
  "VIB files, Offline bundles and ESXi-Customizer 2.5" at
  [http://www.v-front.de/2011/09/vib-files-offline-bundles-and-esxi.html]
- Since version 2.7 adding TGZ files to ESXi 5.x is *deprecated*. TGZ files
  for ESXi 5.x should be converted into VIB files or Offline bundles using
  the "ESXi5 Community Packaging Tools" [http://esxi5-cpt.v-front.de]

Instructions
- Run ESXi-Customizer.cmd from the installation directory.
- A GUI will show up that lets you select the original VMware install-ISO,
  the OEM.tgz, VIB file or Offline bundle and a working directory for the
  script. Please note that the working directory needs to be on a local hard
  drive. Network shares will not be accepted.
- For TGZ files you can choose a repacking option: The default is "Force repacking",
  because this is how older versions behaved, other choices are "Do not touch"
  and "Force repacking and pause for advanced editing". Hover your mouse over
  these options to get tooltips displayed with information on their purposes.
- Please use the update check feature if possible to be informed about
  updates of this script. Press the Run!-button to start the customization
  process.
- The script will auto-detect the ESXi version.
- If you try to customize an ESXi 4.1 media and you do not have administrative
  privileges or have UAC (User account control) enabled in Windows you will
  be prompted to allow the script to run with administrative access. Enter the
  credentials of an administrative user if needed and select Yes to continue.
- The customized ISO file that is produced by the script will be stored in
  the working directory, together with a detailed log file (that is necessary
  for troubleshooting in case something goes wrong).

Licensing
- ESXi-Customizer is licensed under the GNU GPL version 3 (see the included
  file COPYING.txt).
- It is distributed with and makes use of several tools that are freely
  available, but are partly under different licenses (see the included file
  tools\README.txt for details.)

Support
- If you have trouble using the script then please send an email to
  ESXi-Customizer@v-front.de. Be sure to include the log file of the script.
  Otherwise I might just ignore your message.
