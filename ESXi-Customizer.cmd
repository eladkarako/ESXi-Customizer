@echo off

REM -------------------------------------------------------------------------------------------------------------------
REM
REM    ESXi-Customizer.cmd
REM
REM    Version
REM       2.7.2
REM
REM    Author:
REM       Andreas Peetz (ESXi-Customizer@v-front.de)
REM
REM    Purpose:
REM       A user-friendly script that automates the process of customizing the
REM       VMware ESXi install-ISO with drivers that are not originally included.
REM
REM    Instructions, requirements and support:
REM       Please see http://esxi-customizer.v-front.de
REM
REM    Licensing:
REM       ESXi-Customizer.cmd is licensed under the GNU GPL version 3
REM       (see the included file COPYING.txt).
REM       For licensing of the included tools see tools\README.txt!
REM
REM    Disclaimer:
REM       The author of this script expressly disclaims any warranty for it. The script and any related documentation
REM       is provided "as is" without warranty of any kind, either express or implied, including, without limitation,
REM       the implied warranties or merchantability, fitness for a particular purpose, or non-infringement. The entire
REM       risk arising out of use or performance of the script remains with you.
REM       In no event shall the author of this Software be liable for any damages whatsoever (including, without
REM       limitation, damages for loss of business profits, business interruption, loss of business information, or
REM       any other pecuniary loss) arising out of the use of or inability to use this product, even if the author of
REM       this script has been advised of the possibility of such damages.
REM 
REM -------------------------------------------------------------------------------------------------------------------

setlocal enabledelayedexpansion

REM If re-called with Admin rights ensured goto label passed on cmd-line
if /I "%1"=="-AlreadyAdmin" goto %2

call :init_constants
call :setup_screen
call :logCons This is %SCRIPTNAME% v%SCRIPTVERSION% ...
call :check_win_ver || exit /b 1
call :logCons Getting parameters ...
"%GETPARAMS%" "%PARAMSFILE%"
if not "%ERRORLEVEL%"=="0" call :logCons Script canceled. & exit /b 1
call :read_params
call :init_dynamic_env
call :reCreateLogFile || exit /b 1

call :logCons --- INFO: Logging verbose output to "%LOGFILE%" ...
call :logFile This is %SCRIPTNAME% v%SCRIPTVERSION% ...
call :logFile Called with parameters:
call :logFile ... sISO             = "%sISO%"
call :logFile ... fOEM             = "%fOEM%"
call :logFile ... wDir             = "%wDir%"
call :logFile ... repackOpt        = "%repackOpt%"
call :logFile ... enableUEFI       = "%enableUEFI%"
call :logFile ... updateCheck      = "%updateCheck%"

call :reCreateTMPDIR || exit /b 1

if "%updateCheck%"=="1" call :doUpdateCheck || exit /b 1

call :extractISO || exit /b 1

call :check_esxi_ver
if "!ESXIVER!"=="4.1" (
   set REQADMIN=1
   call :log --- INFO: This looks like an ESXi 4.1 installation media.
   if "!WinVer!" NEQ "6.1" call :fatal Windows 7 or Server 2008 R2 is required to customize ESXi 4.1 & exit /b 1
   call :log ---       Admin rights are required, will kindly ask for it if not available ...
   call :log ---       Re-launching this script in a new window to check and ensure privileges ...
   call :log ---       Please do not manually close THIS window!
) else if "!ESXIVER!"=="5.x" (
   set REQADMIN=0
   call :log --- INFO: This looks like an ESXi 5.x installation media.
   call :log ---       No admin rights needed to customize ESXi 5.x. Continuing ...
) else (
   call :fatal This ISO is neither an ESXi 4.1 nor an ESXi 5.x media. Cannot continue & exit /b 1
)

if "!REQADMIN!"=="0" goto :SkipReqAdmin

"%REQUIREADMIN%" "%~f0" -AlreadyAdmin :AdminReEntry
"%BUSYBOX%" sleep 2s
if exist "%wDIR%\Running-as-Admin" del /f /q "%wDIR%\Running-as-Admin" & exit /b
call :fatal Admin rights NOT granted. Cannot continue & exit /b 1

:AdminReEntry
call :init_constants
call :read_params
call :init_dynamic_env
echo Admin>"%wDIR%\Running-as-Admin"
call :setup_screen
call :check_win_ver silent
call :check_esxi_ver silent
call :log This is %SCRIPTNAME% v%SCRIPTVERSION% being re-called with Admin-rights ensured.
call :logCons --- INFO: Continuing verbose logging to "%LOGFILE%" ...

:SkipReqAdmin

set CUSTISO=%wDir%\ESXi-!ESXIVER!-Custom.iso
if exist "!CUSTISO!" (
   call :logWarning The custom ISO file "!CUSTISO!" already exists.
   call :log ---          It will be overwritten ...
)

call :cleanISORoot || exit /b 1

for %%f in ("%fOEM%") do set CUSTTYPE=%%~xf
call :logFile Selected customization type is !CUSTTYPE!.

if "!ESXIVER!"=="4.1" (
   if /I not "!CUSTTYPE!"==".tgz" call :fatal With ESXi 4.1 only OEM.tgz files are supported & exit /b 1
   call :PrepareESXi41 || exit /b 1
)

if "!ESXIVER!"=="5.x" ( 
   if /I "!CUSTTYPE!"==".tgz" (
      call :logRun "%MSGBOX%" 266548 "Please note: Adding a TGZ file to ESXi 5.x is *deprecated*.&n&nAsk the source of the file to provide a VIB file or Offline Bundle instead, or consider converting the file yourself using the 'ESXi5 Community Packaging Tools' (%CPTURL%).&n&nPress 'Yes' now to continue adding the TGZ file, or press 'No' to cancel this script and browse to the homepage of these tools.&n"
      if "!RC!"=="0" (
         call :logFile Cancel script and go to '%CPTURL%' ...
         start "" "%CPTURL%"
         goto :cleanup
      )
      call :logFile Continuing the script ... 
   )
   call :UnpackIMGDB || exit /b 1
   pushd "%IMGDBDIR%\var\db\esximg\profiles" 2>nul: || ( call :fatal Corrupt IMGDB.TGZ file. Cannot continue & exit /b 1)
      call :log Setting up the host profile ...
      set profileXML=ESXi-Customizer
      call :RenameHostProfile !profileXML! || exit /b 1
      call :UpdateHostProfile !profileXML! || exit /b 1
   popd
   if /I "!CUSTTYPE!"==".tgz" call :AddTGZ2ESXi50 || exit /b 1
   if /I "!CUSTTYPE!"==".vib" call :AddVIB2ESXi50 "%fOEM%" || exit /b 1
   if /I "!CUSTTYPE!"==".zip" call :AddZIP2ESXi50 "%fOEM%" || exit /b 1
)

if /I "!CUSTTYPE!"==".tgz" (
   call :UnpackOEMtgz || exit /b 1
   if "!ESXIVER!"=="5.x" call :check41oem || exit /b 1
   if "%repackOpt%"=="2" call :handleAdvEdit || exit /b 1
   if "%repackOpt%" GEQ "1" call :RepackOEMtgz || exit /b 1
)

if "!ESXIVER!"=="4.1" call :FinishESXi41 || exit /b 1

if "!ESXIVER!"=="5.x" (
   if /I "!CUSTTYPE!"==".tgz" call :CopyOEM2ISORoot %fOEMTarget% || exit /b 1
   call :ModISOLinuxCFG || exit /b 1
   call :FinishESXi50 || exit /b 1
)

call :createCustISO || exit /b 1

goto :cleanup

REM ============= sub routines for logging ==================

:logCons
   echo [%DATE% %TIME%] %*
goto :eof

:logFile
   echo [%DATE% %TIME%] %* >>"%LOGFILE%"
goto :eof

:log
   echo [%DATE% %TIME%] %*
   echo [%DATE% %TIME%] %* >>"%LOGFILE%"
goto :eof

:logWarning
   echo [%DATE% %TIME%] --- WARNING: %*
   echo [%DATE% %TIME%] --- WARNING: %* >>"%LOGFILE%"
goto :eof

:logRun
   set RC=0
   echo [%DATE% %TIME%] Run: %* >>"%LOGFILE%"
   %* >>"%LOGFILE%" 2>&1 || set RC=1
goto :eof

:logCRLF
   echo. >>"%LOGFILE%"
goto :eof

REM === sub routines for environment handling ====

:init_constants
   set TOOLS=%~dp0tools
   set ETC=%~dp0etc
   set REQUIREADMIN=%TOOLS%\RequireAdmin.exe
   set SEVENZIP=%TOOLS%\7zip\7z.exe
   set VHDTOOL=%TOOLS%\VhdTool.exe
   set MKISOFS=%TOOLS%\cygwin\mkisofs.exe
   set SED=%TOOLS%\unxutils\sed.exe
   set BUSYBOX=%TOOLS%\busybox.exe
   set GETPARAMS=%TOOLS%\GetParams.exe
   set MSGBOX=%TOOLS%\MsgBox.exe
   set DISKPART=%SystemRoot%\system32\diskpart.exe
   set EXPLORER=%SystemRoot%\explorer.exe
   set NOTEPAD=%SystemRoot%\notepad.exe
   set CYGWIN=nodosfilewarning
   set SCRIPTNAME=ESXi-Customizer
   set SCRIPTVERSION=2.7.2
   set SCRIPTURL=http://esxi-customizer.v-front.de
   set ESXI50FAQ_URL=http://www.v-front.de/2011/08/how-esxi-customizer-supports-esxi-50.html
   set updateCheckURL=http://vibsdepot.v-front.de/tools/ESXi-Customizer-CurrentVersion.cmd
   set CPTURL=http://esxi5-cpt.v-front.de
   set PARAMSFILE=%TEMP%\%SCRIPTNAME%-Params.cmd
goto :eof

:read_params
   REM set sISO=...        (source ISO file,  is set by GetParams.exe/stored in "%PARAMSFILE%")
   REM set fOEM=...        (OEM.tgz file,     is set by GetParams.exe/stored in "%PARAMSFILE%")
   REM set wDir=...        (Working dir,      is set by GetParams.exe/stored in "%PARAMSFILE%")
   REM set repackOpt=...   (Repacking flag,   is set by GetParams.exe/stored in "%PARAMSFILE%")
   REM set updateCheck=... (UpdateCheck flag, is set by GetParams.exe/stored in "%PARAMSFILE%")
   set enableUEFI=1
   call "%PARAMSFILE%"
   if "%wDIR:~-1%"=="\" set wDir=%wDIR:~0,-1%
goto :eof

:init_dynamic_env
   set LOGFILE=!wDIR!\%SCRIPTNAME%.log
   set TMPDIR=!wDIR!\esxicust.tmp
   set ISODIR=!TMPDIR!\iso
   set OEMDIR=!TMPDIR!\oem
   set IMGDBDIR=!TMPDIR!\imgdb
goto :eof

REM ===== common sub-routines ======

:setup_screen
   mode 120,50
   title %SCRIPTNAME% v%SCRIPTVERSION% - %SCRIPTURL%
goto :eof

:check_win_ver
   if /I not "%1"=="silent" call :logCons Checking Windows version ...
   for /F "tokens=3,4,5 delims=. " %%a in ('ver') do (
      set WinVer=%%b.%%c
      if "%%a"=="2000" set WinVer=5.0
      if "%%a"=="XP" set WinVer=5.1
   )
   if /I "%1"=="silent" goto :eof
   if "!WinVer!"=="5.0" call :logCons --- INFO: Running on Windows 2000. What?!
   if "!WinVer!"=="5.1" call :logCons --- INFO: Running on Windows XP.
   if "!WinVer!"=="5.2" call :logCons --- INFO: Running on Windows Server 2003.
   if "!WinVer!"=="6.0" call :logCons --- INFO: Running on Windows Vista or Server 2008.
   if "!WinVer!"=="6.1" call :logCons --- INFO: Running on Windows 7 or Server 2008 R2.
   if "!WinVer!"=="6.2" call :logCons --- INFO: Running on Windows 8 or Server 2012.
   if "!WinVer!"=="6.3" call :logCons --- INFO: Running on Windows 8.1 or Server 2012 R2.
   if "!WinVer!" GTR "6.3" call :logCons --- WARNING: Running on a Windows newer than 8.1 / 2012 R2. Don't know if this will work ...
   if "!WinVer!" LSS "5.1" call :earlyFatal Unsupported Windows Version: !WinVer!. At least Windows XP is required & exit /b 1
   if "!WinVer!" NEQ "6.1" call :logCons --- WARNING: Your Windows version is supported for customizing ESXi 5.x, but not ESXi 4.1.
goto :eof

:reCreateLogFile
   if exist "%LOGFILE%" (
      del /f /q "%LOGFILE%" >nul: 2>&1
      if exist "%LOGFILE%" call :earlyFatal Cannot delete old log file '%LOGFILE%' & exit /b 1
   )
   ( echo. >"%LOGFILE%" ) 2>nul:
   if not exist "%LOGFILE%" call :earlyFatal Cannot create log file '%LOGFILE%' & exit /b 1
goto :eof

:reCreateTMPDIR
   if exist "%TMPDIR%" (
      call :logFile The temp-directory "%TMPDIR%" already exists. Removing it ...
      call :logRun rmdir /s /q "%TMPDIR%"
      if exist "%TMPDIR%" ( call :fatal Cannot remove existing temp-directory '%TMPDIR%' & exit /b 1)
   )
   call :logFile Creating the temp-directory "%TMPDIR%" ...
   call :logRun mkdir "%TMPDIR%"
   if not exist "%TMPDIR%" ( call :fatal Cannot create temp-directory '%TMPDIR%' & exit /b 1)
goto :eof

:doUpdateCheck
   call :log Checking for updated version of this script ...
   call :logRun "%BUSYBOX%" wget --header "Pragma: no-cache" "%updateCheckURL%" -O "%TMPDIR%\CurrentVersion.cmd"
   call :logCRLF
   if exist "%TMPDIR%\CurrentVersion.cmd" (
      call :logFile [Debug] Contents of CurrentVersion.cmd:
      type "%TMPDIR%\CurrentVersion.cmd" >>"%LOGFILE%"
      call :logCRLF
      call :logFile [Debug] End of File
      call "%TMPDIR%\CurrentVersion.cmd"
      if "!SCRIPTVERSION!" LSS "!CurrentVersion!" (
         call :logFile --- INFO: A newer version !CurrentVersion! of ESXi-Customizer is available.
         call :logFile ---       Do you want to update now?
         call :logRun "%MSGBOX%" 266276 "A newer version !CurrentVersion! of ESXi-Customizer is available.&nDo you want to cancel the script now and visit &n   %SCRIPTURL%&nto update ESXi-Customizer?"
         if "!RC!"=="0" (
            call :logFile Do not update now. Continuing the script ...
         ) else (
            call :logFile Cancel script and go to '%SCRIPTURL%' ...
            start "" "%SCRIPTURL%"
            goto :cleanup
         )
      ) else (
         call :log --- INFO: There is no newer version available.
      )
   ) else (
      call :logWarning UpdateCheck failed, check your internet connection.
      call :logRun "%MSGBOX%" 266288 "UpdateCheck failed. Please check your internet connection.&nPress OK to continue." 5
   )
   title %SCRIPTNAME% v%SCRIPTVERSION% - %SCRIPTURL%
goto :eof

:extractISO
   call :log Extracting the source ISO ...
   call :logRun "%SEVENZIP%" x -y -o"%ISODIR%" "%sISO%"
   if not "!RC!"=="0" ( call :fatal Error extracting the original ISO file & exit /b 1)
goto :eof

:check_esxi_ver
   if /I not "%1"=="silent" call :log Checking media type ...
   set ESXIVER=unsupported
   if exist "%ISODIR%\sys.vgz" if exist "%ISODIR%\imagedd.bz2" if exist "%ISODIR%\isolinux.cfg" set ESXIVER=4.1
   if exist "%ISODIR%\S.V00" if exist "%ISODIR%\BOOT.CFG" if exist "%ISODIR%\WEASELIN.?00" set ESXIVER=5.x
goto :eof

:cleanISORoot
   if exist "%ISODIR%\boot.cat" (
      call :logFile Removing old boot.cat from ISO directory. It will be created by mksiofs ...
      call :logRun del /f /q "%ISODIR%\boot.cat"
      if not "!RC!"=="0" ( call :fatal Error removing old boot.cat from ISO files & exit /b 1)
   )
   if exist "%ISODIR%\[BOOT]" (
      call :logFile Removing [BOOT] directory from ISO directory ...
      call :logRun rmdir /s /q "%ISODIR%\[BOOT]"
      if not "!RC!"=="0" ( call :fatal Error removing [BOOT] directory from ISO files & exit /b 1)
   )
goto :eof

:UnpackOEMtgz
   call :logFile Unpacking the OEM.tgz file ...
   call :logRun "%SEVENZIP%" x -y -o"%OEMDIR%" "%fOEM%"
   if not "!RC!"=="0" ( call :fatal Error uncompressing OEM.tgz & exit /b 1)
   for %%O in ("%OEMDIR%\*.tar") do set fTAR=%%O
   call :logFile --- [DEBUG: Contents of the original TGZ file]
   "%BUSYBOX%" tar -tvf "!fTAR!" | "%BUSYBOX%" unix2dos -d >>"%LOGFILE%"
   call :logFile --- [End of file]
   call :logRun "%SEVENZIP%" x -y -o"%OEMDIR%" "!fTAR!"
   if not "!RC!"=="0" ( call :fatal Error un-taring OEM.tar & exit /b 1)
   call :logRun del /f /q "!fTAR!"
   if not "!RC!"=="0" ( call :fatal Error cleaning up OEM.tar & exit /b 1)
goto :eof

:RepackOEMtgz
   call :logFile Re-packing the OEM.tgz file ...
   pushd "%OEMDIR%"
      set fTAR=%TMPDIR%\oem.tar
      call :logRun "%BUSYBOX%" tar -cf ..\oem.tar *
      if not "!RC!"=="0" ( popd & call :fatal Error taring new OEM.tar & exit /b 1)
      call :logFile --- [DEBUG: Contents of the repacked/edited TGZ file]
      "%BUSYBOX%" tar -tvf "!fTAR!" | "%BUSYBOX%" unix2dos -d >>"%LOGFILE%"
      call :logFile --- [End of file]
   popd
   set fOEM=%TMPDIR%\oem.tgz
   call :logRun "%SEVENZIP%" a -tgzip -y "!fOEM!" "!fTAR!"
   if not "!RC!"=="0" ( call :fatal Error compressing new OEM.tar & exit /b 1)
goto :eof

:handleAdvEdit
   call :log Advanced editing enabled.
   call :log --- INFO: Pausing to allow manual editing of files ...
   call :logFile --- --- The ISO directory is:       [%ISODIR%]
   if "!ESXIVER!"=="4.1" call :logFile --- --- The dd-image is mounted at: [%TMPDIR%\Hypervisor1]
   if "!ESXIVER!"=="5.x" call :logFile --- --- The IMGDB directory is:     [%IMGDBDIR%]
   if /I "!CUSTTYPE!"==".tgz" call :logFile --- --- The OEM files are at:       [%OEMDIR%]
   call :logFile --- Launching explorer.exe ...
   "%EXPLORER%" "%TMPDIR%"
   if "!ESXIVER!"=="4.1" call :logRun "%MSGBOX%" 266304 "Pausing script to allow manual editing of files:&n&n--- The ISO directory is: [%ISODIR%]&n--- The dd-image is mounted at: [%TMPDIR%\Hypervisor1]&n--- The OEM files are at: [%OEMDIR%]&n&nWhen editing text files use an editor that preserves UNIX line feeds, like Notepad++. Press OK when you have finished editing."
   if "!ESXIVER!"=="5.x" (
      if /I "!CUSTTYPE!"==".tgz" (
         call :logRun "%MSGBOX%" 266304 "Pausing script to allow manual editing of files:&n&n--- The ISO directory is: [%ISODIR%]&n--- The IMGDB directory is: [%IMGDBDIR%]&n--- The OEM files are at: [%OEMDIR%]&n&nWhen editing text files use an editor that preserves UNIX line feeds, like Notepad++. Press OK when you have finished editing."
      ) else (
         call :logRun "%MSGBOX%" 266304 "Pausing script to allow manual editing of files:&n&n--- The ISO directory is: [%ISODIR%]&n--- The IMGDB directory is: [%IMGDBDIR%]&n&nWhen editing text files use an editor that preserves UNIX line feeds, like Notepad++. Press OK when you have finished editing."
      )
   )
   call :logFile Finished advanced edit mode.
goto :eof

:createCustISO
   call :log Creating the customized ISO file ...
   if "!ESXIVER!"=="4.1" (
      call :logrun "%MKISOFS%" -quiet -l -R -J -ucs-level 3 -sysid Linux -A "VMware ESXi Server 4" -V ESXi-!ESXIVER!.0-custom -p support@vmware.com,ESXi-Customizer@v-front.de -b isolinux.bin -c boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -input-charset utf-8 -o "!CUSTISO!" "%ISODIR%"
   )
   if "!ESXIVER!"=="5.x" (
      if "%enableUEFI%"=="1" (
         call :logRun "%MKISOFS%" -quiet -l -no-iso-translate -sysid "" -A "ESXIMAGE" -V ESXi-!ESXIVER!.0-custom -c BOOT.CAT -eltorito-platform "x86" -b ISOLINUX.BIN -no-emul-boot -boot-load-size 4 -boot-info-table -eltorito-alt-boot -eltorito-platform "efi" -b EFIBOOT.IMG -no-emul-boot -input-charset utf-8 -o "!CUSTISO!" "%ISODIR%"
      ) else (
         call :logrun "%MKISOFS%" -quiet -l -no-iso-translate -sysid "" -A "ESXIMAGE" -V ESXi-!ESXIVER!.0-custom -c BOOT.CAT -b ISOLINUX.BIN -no-emul-boot -boot-load-size 4 -boot-info-table -input-charset utf-8 -o "!CUSTISO!" "%ISODIR%"
      )
   )
   if not "!RC!"=="0" (
      call :logCRLF
      call :fatal Error creating the customized ISO file
      exit /b 1
   )
   call :logCRLF
   call :logFile ------------------------------------------------------------------------------------
   call :logFile --- INFO: All done - the custom ISO file was created as
   call :logFile ---       !CUSTISO!
   call :logFile ------------------------------------------------------------------------------------
   call :logRun "%MSGBOX%" 266304 "All done - the custom ISO file was created as&n   '!CUSTISO!'."
goto :eof

REM ===== sub-routines for ESXi 4.1 =====

:PrepareESXi41
   set fOEMTarget=oem.tgz
   if exist "%ISODIR%\oem.tgz" (
      call :logWarning An OEM.tgz file already exists in the ISO root.
      call :log ----         Merging is not yet implemented, file will be overwritten.
   )
   call :logFile Check for presence of oem.tgz in isolinux.cfg ...
   call :logrun findstr /I /C:oem.tgz "%ISODIR%\isolinux.cfg"
   if "!RC!"=="0" (
      call :logCRLF
      call :logFile Yes, it's there. No need to add it ...
   ) else (
      call :logFile Not found, adding it now ...
      call :logRun "%SED%" -e "s/--- install.vgz/--- install.vgz --- oem.tgz/gI" -i "%ISODIR%\isolinux.cfg"
      if not "!RC!"=="0" ( call :fatal Error editing isolinux.cfg & exit /b 1)
   )
   call :log Extracting the dd-image. This will take some time ...
   call :logRun "%SEVENZIP%" x -y -o"%TMPDIR%" "%ISODIR%\imagedd.bz2"
   if not "!RC!"=="0" ( call :fatal Error extracting the dd-image & exit /b 1)
   call :logFile Removing old dd-image archive ...
   call :logRun del /f /q "%ISODIR%\imagedd.bz2"
   if not "!RC!"=="0" ( call :fatal Error removing old dd-image archive & exit /b 1)
   call :logFile Converting the dd-image to VHD-format ...
   call :logRun "%VHDTOOL%" /convert "%TMPDIR%\imagedd"
   if not "!RC!"=="0" ( call :fatal Error converting the dd-image & exit /b 1)
   call :logFile Creating mount directory for dd-image ...
   call :logRun mkdir "%TMPDIR%\Hypervisor1"
   if not exist "%TMPDIR%\Hypervisor1" ( call :fatal Error creating the mount directory for dd-image & exit /b 1)
   call :logFile Creating parameter files for diskpart ...
   (echo select vdisk file="%TMPDIR%\imagedd"
   echo attach vdisk
   echo exit) >"%TMPDIR%\diskpart-attach.txt" || ( call :fatal Error creating diskpart-attach.txt & exit /b 1)
   (echo select vdisk file="%TMPDIR%\imagedd"
   echo list partition
   echo select partition 2
   echo list volume
   echo assign mount="%TMPDIR%\Hypervisor1"
   echo exit) >"%TMPDIR%\diskpart-mount.txt" || ( call :fatal Error creating diskpart-mount.txt & exit /b 1)
   (echo select vdisk file="%TMPDIR%\imagedd"
   echo detach vdisk
   echo exit) >"%TMPDIR%\diskpart-detach.txt" || ( call :fatal Error creating diskpart-detach.txt & exit /b 1)
   set IMGATT=0
   call :log Attaching the dd-image ...
   call :logRun "%DISKPART%" /s "%TMPDIR%\diskpart-attach.txt"
   if not "!RC!"=="0" ( call :fatal Error attaching the VHD-disk & exit /b 1)
   set IMGATT=1
   call :log Waiting 30 sec. for volumes to show up ...
   call :log --- INFO: Please ignore/close any AutoPlay pop-ups appearing now.
   call :logRun "%BUSYBOX%" sleep 30s
   call :log Mounting the Hypervisor1 partition ...
   call :logRun "%DISKPART%" /s "%TMPDIR%\diskpart-mount.txt"
   if not "!RC!"=="0" ( call :fatal Error mounting the Hypervisor1 partition & exit /b 1)
   if exist "%TMPDIR%\Hypervisor1\oem.tgz" (
      call :logWarning An OEM.tgz file already exists in the dd-image.
      call :log ---          Merging is not yet implemented, file will be overwritten.
   )
   call :logFile Check for presence of oem.tgz in boot.cfg ...
   call :logrun findstr /I /C:oem.tgz "%TMPDIR%\Hypervisor1\boot.cfg"
   if "!RC!"=="0" (
      call :logCRLF
      call :logFile Yes, it's there. No need to add it ...
   ) else (
      call :logFile Not found, adding it now ...
      call :logRun "%SED%" -e "s/--- license.tgz/--- oem.tgz --- license.tgz/gI" -i "%TMPDIR%\Hypervisor1\boot.cfg"
      if not "!RC!"=="0" ( call :fatal Error editing boot.cfg & exit /b 1)
   )
goto :eof

:FinishESXi41
   call :log Finishing customized ESXi 4.1 ISO ...
   call :logFile Copying "%fOEMTarget%" file to ISO root ...
   call :logRun copy /y "%fOEM%" "%ISODIR%\%fOEMTarget%"
   if not "!RC!"=="0" ( call :fatal Error copying '%fOEMTarget%' file to ISO root & exit /b 1)
   call :logFile Copying "%fOEMTarget%" file to dd-image ...
   call :logRun copy /y "%fOEM%" "%TMPDIR%\Hypervisor1\%fOEMTarget%"
   if not "!RC!"=="0" ( call :fatal Error copying '%fOEMTarget%' file to dd-image & exit /b 1)
   call :logFile Detach the VHD-disk using diskpart ...
   call :logRun "%DISKPART%" /s "%TMPDIR%\diskpart-detach.txt"
   if not "!RC!"=="0" ( call :fatal Error detaching the VHD-disk & exit /b 1)
   set IMGATT=0
   for %%F in ("%TMPDIR%\imagedd") do set /a DDFS=%%~zF-512
   call :log Preparing updated dd-image (%DDFS% bytes). This will take some time ...
   call :logFile Extracting new dd-image from VHD-disk (%DDFS% bytes) ...
   call :logRun "%BUSYBOX%" dd bs=%DDFS% count=1 if="%TMPDIR%\imagedd" of="%TMPDIR%\imagedd.tmp"
   if not "!RC!"=="0" ( call :fatal Error extracting new dd-image from VHD-disk & exit /b 1)
   call :logFile Deleting VHD-disk file ...
   call :logRun del /f /q "%TMPDIR%\imagedd"
   if not "!RC!"=="0" ( call :fatal Error deleting VHD-disk file & exit /b 1)
   call :logFile Compressing new dd-image ...
   call :logRun "%SEVENZIP%" a -tbzip2 -bd -y "%ISODIR%\imagedd.bz2" "%TMPDIR%\imagedd.tmp"
   if not "!RC!"=="0" ( call :fatal Error compressing new dd-image & exit /b 1)
   pushd "%ISODIR%"
   call :logFile Calculating new md5sum of imagedd.bz2 ...
   "%BUSYBOX%" md5sum imagedd.bz2 >"%TMPDIR%\imagedd.md5.tmp"
   if not "%ERRORLEVEL%"=="0" ( call :fatal Error calculating new md5sum of imagedd.bz2 & exit /b 1)
   for /F "tokens=1" %%c in ('type "%TMPDIR%\imagedd.md5.tmp"') do set CHKSUM=%%c
   call :logFile New md5sum is %CHKSUM%. Updating imagedd.md5 ...
   call :logRun "%SED%" -r -e "s/[a-fA-F0-9]+/%CHKSUM%/" -i "imagedd.md5"
   if not "!RC!"=="0" ( call :fatal Error updating imagedd.md5 & exit /b 1)
   popd
goto :eof


REM ===== sub-routines for ESXi 5 =====

:check41oem
   if not exist "%OEMDIR%\etc\vmware\simple.map" goto :eof
   call :logFile --- WARNING: It looks like you are trying to add an OEM.tgz file that was made for ESXi 4.x
   call :logFile ---          to an ESXi 5.x media. Please note that this is useless because ESXi 5.x cannot use
   call :logFile ---          drivers made for ESXi 4.x.
   call :logFile ---          Press 'Yes' to continue anyway or 'No' to cancel now and browse to a page
   call :logFile ---          with more information.
   call :logRun "%MSGBOX%" 266548 "Caution:&n&nIt looks like you are trying to add an OEM.tgz file that was made for ESXi 4.x to an ESXi 5.x media. Please note that this is useless because ESXi 5.x cannot use drivers made for ESXi 4.x.&n&nPress 'Yes' to continue anyway or 'No' to cancel now and browse to a page with more information.&n"
   if "!RC!"=="0" (
      call :logFile Cancel script and go to '%ESXI50FAQ_URL%' ...
      start "" "%ESXI50FAQ_URL%"
      goto :cleanup
   ) else (
      call :logFile Anyway continuing the script ...
   )
goto :eof

:Add2BootCFG
   call :logFile Adding "%1" to \BOOT.CFG ...
   call :logRun "%SED%" -e "s#--- /imgdb.tgz #--- /%1 --- /imgdb.tgz #I" -i "%ISODIR%\BOOT.CFG"
   if not "!RC!"=="0" ( call :fatal Error editing BOOT.CFG & exit /b 1)
   call :logFile Adding it to \EFI\BOOT\BOOT.CFG ...
   call :logRun "%SED%" -e "s#--- /imgdb.tgz #--- /%1 --- /imgdb.tgz #I" -i "%ISODIR%\EFI\BOOT\BOOT.CFG"
   if not "!RC!"=="0" ( call :fatal Error editing \EFI\BOOT\BOOT.CFG & exit /b 1)
goto :eof

:UnpackIMGDB
   call :log Unpacking the IMGDB.TGZ file ...
   call :logRun "%SEVENZIP%" x -y -o"%TMPDIR%" "%ISODIR%\IMGDB.TGZ"
   if not "!RC!"=="0" ( call :fatal Error uncompressing IMGDB.TGZ & exit /b 1)
   call :logRun "%SEVENZIP%" x -y -o"%IMGDBDIR%" "%TMPDIR%\IMGDB.tar"
   if not "!RC!"=="0" ( call :fatal Error un-taring IMGDB.tar & exit /b 1)
goto :eof

:RenameHostProfile
   for %%p in ("*.*") do set oldProfileXML=%%p
   call :logFile The original host profile XML file is "%oldProfileXML%" ...
   if /I not "%oldProfileXML%"=="%1" (
      call :logFile Renaming it to "%1".
      REM !!! QFE270001 !!! [Was:] call :logRun ren "%oldProfileXML%" "%1"
      set RC=0& ren "%oldProfileXML%" "%1" || set RC=1
      if not "!RC!"=="0" ( call :fatal Error renaming host profile XML & exit /b 1)
   )
goto :eof

:UpdateHostProfile
   call :logFile Updating the host profile XML file ...
   call :logRun "%SED%" -e "s#<name>.*</name>#<name>ESXi-Customizer</name>#I" -i "%1"
   if not "!RC!"=="0" ( call :fatal Error editing name tag in host profile XML & exit /b 1)
   call :logRun "%SED%" -e "s#<creator>.*</creator>#<creator>VMware, Inc. / ESXi-Customizer.v-front.de</creator>#I" -i "%1"
   if not "!RC!"=="0" ( call :fatal Error editing creator tag in host profile XML & exit /b 1)
   for /f %%d in ('"%BUSYBOX%" date -u +%%Y-%%m-%%dT%%H:%%M:%%S.000000+00:00') do set MODTIME=%%d
   call :logRun "%SED%" -e "s#<modifiedtime>.*</modifiedtime>#<modifiedtime>!MODTIME!</modifiedtime>#I" -i "%1"
   if not "!RC!"=="0" ( call :fatal Error editing modifiedtime tag in host profile XML & exit /b 1)
   call :logRun "%SED%" -e "s#<description>.*</description>#<description>This is a VMware ESXi 5.x build customized by %SCRIPTNAME% %SCRIPTVERSION%</description>#I" -i "%1"
   if not "!RC!"=="0" ( call :fatal Error editing description tag in host profile XML & exit /b 1)
   call :logRun "%SED%" -e "s#<acceptancelevel>.*</acceptancelevel>#<acceptancelevel>community</acceptancelevel>#I" -i "%1"
   if not "!RC!"=="0" ( call :fatal Error editing acceptancelevel tag in host profile XML & exit /b 1)
   REM TODOs: edit <profileID>?
goto :eof

:ParseVibXML
   call :logFile Parsing %1 ...
   findstr /I /L "<type>" %1 | "%SED%" -e "s#.*<type>#set %2Type=#I;s#</type>.*##I" >%3
   echo.>>%3
   findstr /I /L "<name>" %1 | "%SED%" -e "s#.*<name>#set %2Name=#I;s#</name>.*##I" >>%3
   echo.>>%3
   findstr /I /L "<version>" %1 | "%SED%" -e "s#.*<version>#set %2Version=#I;s#</version>.*##I" >>%3
   echo.>>%3
   findstr /I /L "<vendor>" %1 | "%SED%" -e "s#.*<vendor>#set %2Vendor=#I;s#</vendor>.*##I" >>%3
   echo.>>%3
   findstr /I /L "<payload" %1 | "%SED%" -e "s#.*<payload name=\"#set %2PayloadName=#I;s#\".*##I" >>%3
   echo.>>%3
   findstr /I /L "<payload" %1 | "%SED%" -e "s#.*<payload .* type=\"#set %2PayloadType=#I;s#\".*##I" >>%3
   echo.>>%3
   type %3 >>"%LOGFILE%" 2>&1
   call %3
goto :eof

:CountPayloads
   call :logFile Counting payloads in %1 of %2 ...
   "%BUSYBOX%" grep -i -o "<payload name=" %1 | "%BUSYBOX%" wc -l >"%TMPDIR%\preCheckVib.tmp"
   for /f %%c in ('type "%TMPDIR%\preCheckVib.tmp"') do set payLoadCount=%%c
   if "!payLoadCount!"=="0" (
      call :logFile Cannot find any payloads in %1 ...
      call :logRun "%MSGBOX%" 266288 "Cannot apply VIB-file %2, it does not contain any payloads."
   ) else if "!payLoadCount!"=="1" (
      call :logFile Exactly 1 payload found in %1. Good ...
      set RC=0
   ) else (
      call :logFile Found !payLoadCount! payloads in %1. Too many ...
      call :logRun "%MSGBOX%" 266288 "Cannot apply VIB-file %2, it does contain more than one payload."
   )
   if not "!payLoadCount!"=="1" (
      set RC=1
      if /I "!CUSTTYPE!"==".vib" goto :cleanup
   )
goto :eof

:AddTGZ2ESXi50
   call :log Adding an OEM.TGZ style file ...
   call :logFile Determining OEM.TGZ target name ...
   set i=0
   :oloop
      if "!i!" EQU "100" ( call :fatal There are already 100 OEM.tgz files merged into this CD. Cannot do more ... & exit /b 1)
      set istr=0!i!
      set istr=!istr:~-2!
   if exist "%ISODIR%\OEM-!istr!.t00" set /a i=!i!+1 & goto :oloop
   set fOEMTarget=OEM-!istr!.t00
   call :logFile OEM.TGZ target name is "%fOEMTarget%" ...
   call :Add2BootCFG %fOEMTarget% || exit /b 1
   call :logFile Adding vib-entry for "%fOEMTarget%" to host profile ...
   call :logRun "%SED%" -e "s#</viblist>#<vib><vib-id>OEM_bootbank_%fOEMTarget:~0,6%_1.0</vib-id><payloads><payload payload-name=\"%fOEMTarget:~0,6%\">%fOEMTarget%</payload></payloads></vib></viblist>#I" -i "%IMGDBDIR%\var\db\esximg\profiles\!profileXML!"
   if not "!RC!"=="0" ( call :fatal Error adding OEM-vib entry in host profile XML & exit /b 1)
   pushd "%IMGDBDIR%\var\db\esximg\vibs" 2>nul: || ( call :fatal Corrupt IMGDB.TGZ file. Cannot continue & exit /b 1)
      set VIBXML=%fOEMTarget:~0,6%-99999999%fOEMTarget:~4,2%.xml
      call :logFile Creating the OEM-VIB.xml file ...
      call :logRun copy /Y "%ETC%\oem-vib.xml" "%VIBXML%"
      if not "!RC!"=="0" ( call :fatal Error creating '%VIBXML%' & exit /b 1)
      for %%f in ("%fOEM%") do set fOEMShort=%%~nxf
      call :logRun "%SED%" -e "s/#fOEMShort#/%fOEMShort%/gI" -i "%VIBXML%"
      if not "!RC!"=="0" ( call :fatal Error editing #fOEMShort# in OEM-VIB.XML & exit /b 1)
      call :logRun "%SED%" -e "s/#fOEMTarget#/%fOEMTarget:~0,6%/gI" -i "%VIBXML%"
      if not "!RC!"=="0" ( call :fatal Error editing #fOEMTarget# in OEM-VIB.XML & exit /b 1)
      REM TODOs: edit release-date tag in VIBXML
   popd
goto :eof

:AddVIB2ESXi50
   call :log Checking vib file "%~nx1" ...
   call :logFile Unpacking VIB-file ...
   call :logRun "%SEVENZIP%" x -y -o"%TMPDIR%\vib" %1
   if not "!RC!"=="0" ( call :fatal Error unpacking the VIB file & exit /b 1)
   if not exist "%TMPDIR%\vib\descriptor.xml" call :fatal Corrupt VIB file. Descriptor.xml not found & exit /b 1
   call :ParseVibXML "%TMPDIR%\vib\descriptor.xml" vib "%TMPDIR%\parsevib.tmp.cmd"
   call :CountPayloads "%TMPDIR%\vib\descriptor.xml" "%~nx1" || exit /b 1
   if not "!RC!"=="0" call :log Cannot apply VIB !vibName!, it contains a wrong number of payloads. & goto :skipvib
   if /I not "!vibPayloadType!"=="vgz" if /I not "!vibPayloadType!"=="tgz" (
      call :logRun "%MSGBOX%" 266288 "Cannot apply VIB !vibName!, it contains a payload file of unknown type '!vibPayloadType!'."
      if /I "!CUSTTYPE!"==".vib" goto :cleanup
      goto :skipvib
   )
   call :logFile Check if we are updating an existing vib ...
   pushd "%IMGDBDIR%\var\db\esximg\vibs" 2>nul: || ( call :fatal Corrupt IMGDB.TGZ file. Cannot continue & exit /b 1)
      set vibUpdate=0
      if exist "!vibName!-*.xml" set vibUpdate=1
      if "!vibUpdate!"=="1" (
         call :logFile Yes, the vib !vibName! does already exist on the CD ...
         for %%o in ("!vibName!-*.xml") do set oldVibXML=%%o
         call :ParseVibXML "!oldVibXML!" oldVib "%TMPDIR%\parseoldvib.tmp.cmd"
         call :log ... old version: !oldVibVersion!
         call :log ... new version: !vibVersion!
         call :logRun "%MSGBOX%" 266548 "Do you want to add the VIB&n   !vibName! (version !vibVersion!) ?&n&nWARNING: This will *replace* the existing&n   !oldVibName! (version !oldVibVersion!)&n"
         set vibCont=!RC!
      ) else (
         if /I "!CUSTTYPE!"==".vib" (
            set vibCont=1
         ) else (
            call :logRun "%MSGBOX%" 266276 "Do you want to add the new VIB&n   !vibName! (version !vibVersion!)&n?"
            set vibCont=!RC!
         )
      )
      if "!vibCont!"=="0" (
         call :log VIB apply canceled by user.
         popd
         if /I "!CUSTTYPE!"==".vib" goto :cleanup
         goto :skipvib
      ) else (
         call :log Applying VIB !vibName! now ...
      )
      if "!vibUpdate!"=="1" (
         call :log Removing old VIB !oldVibName! v!oldVibVersion! ...
         call :logFile Deleting old vib xml file "!oldVibXML!" ...
         call :logRun del /f /q "!oldVibXML!"
         call :logFile Read name of old vib payload file from host profile xml ...
         findstr /I /L "_!oldVibName!_" "%IMGDBDIR%\var\db\esximg\profiles\!profileXML!" | "%SED%" -e "s#.*_!oldVibName!_[a-zA-Z0-9._-]*</vib-id><payloads><payload payload-name=\"[a-zA-Z0-9._-]*\">#set oldVibPayloadFile=#I;s#</payload>.*##I" >"%TMPDIR%\getoldpayloadfile.tmp.cmd"
         call "%TMPDIR%\getoldpayloadfile.tmp.cmd"
         call :logFile Removing old vib "!oldVibName!" entry from host profile xml ...
         call :logRun "%SED%" -e "s#<vib><vib-id>[- a-zA-Z0-9._]*_!oldVibName!_[- a-zA-Z0-9._]*</vib-id><payloads><payload payload-name=\"[- a-zA-Z0-9._]*\">[- a-zA-Z0-9._]*</payload></payloads></vib>##I" -i "%IMGDBDIR%\var\db\esximg\profiles\!profileXML!"
         if not "!RC!"=="0" ( call :fatal Error removing old vib "!oldVibName!" entry from host profile xml & exit /b 1 )
         call :logFile Deleting the old payload file "!oldVibPayloadFile!" from ISO root ...
         call :logRun del /f /q "%ISODIR%\!oldVibPayloadFile!"
         if not "!RC!"=="0" ( call :fatal Error deleting the old payload file "!oldVibPayloadFile!" from ISO root & exit /b 1 )
         call :logFile Removing the old payload file "!oldVibPayloadFile!" from BOOT.CFG files ...
         call :logRun "%SED%" -e "s#/!oldVibPayloadFile! --- ##I" -i "%ISODIR%\BOOT.CFG"
         if not "!RC!"=="0" ( call :fatal Error removing the old payload file "!oldVibPayloadFile!" from \BOOT.CFG & exit /b 1 )
         call :logRun "%SED%" -e "s#/!oldVibPayloadFile! --- ##I" -i "%ISODIR%\EFI\BOOT\BOOT.CFG"
         if not "!RC!"=="0" ( call :fatal Error removing the old payload file "!oldVibPayloadFile!" from \EFI\BOOT\BOOT.CFG & exit /b 1 )
      )
   popd
   call :logFile Determining payload file target name ...
   set vibPayloadTargetName=!vibPayloadName:~0,8!
   set i=0
   if /I "!vibPayloadType:~0,1!"=="t" (
      set wc=t
   ) else (
      set wc=?
   )
   :vloop
      if "!i!" EQU "100" ( call :fatal There are already 100 payload files named !vibPayloadName!.!vibPayloadType:~0,1!?? on this CD. Cannot do more ... & exit /b 1)
      set istr=0!i!
      set istr=!istr:~-2!
   if exist "%ISODIR%\!vibPayloadTargetName!.!wc!!istr!" set /a i=!i!+1 & goto :vloop
   set vibPayloadFile=!vibPayloadTargetName!.!vibPayloadType:~0,1!!istr!
   call :logFile Payload file target name target name is "!vibPayloadFile!" ...
   call :logFile Copy payload file to ISO root ...
   call :logRun copy /Y "%TMPDIR%\vib\!vibPayloadName!" "%ISODIR%\!vibPayloadFile!"
   if not "!RC!"=="0" ( call :fatal Error copying payload file to ISO root & exit /b 1 )
   call :Add2BootCFG !vibPayloadFile! || exit /b 1
   call :logFile Adding vib-entry for "!vibPayloadName!" to host profile ...
   call :logRun "%SED%" -e "s#</viblist>#<vib><vib-id>!vibVendor!_!vibType!_!vibName!_!vibVersion!</vib-id><payloads><payload payload-name=\"!vibPayloadName!\">!vibPayloadFile!</payload></payloads></vib></viblist>#I" -i "%IMGDBDIR%\var\db\esximg\profiles\!profileXML!"
   if not "!RC!"=="0" ( call :fatal Error adding !vibPayloadName! vib entry in host profile XML & exit /b 1)
   call :logFile Copy vib.xml file into imgdb-dir ...
   pushd "%IMGDBDIR%\var\db\esximg\vibs" 2>nul: || ( call :fatal Corrupt IMGDB.TGZ file. Cannot continue & exit /b 1)
      if x%2x==xx (
         call :logRun copy /Y "%TMPDIR%\vib\descriptor.xml" "!vibName!-99999999!vibPayloadFile:~-2!.xml"
      ) else (
         call :logRun copy /Y %2 .
      )
      if not "!RC!"=="0" ( call :fatal Error copying descriptor.xml file to ISO root & exit /b 1 )
   popd
   call :logFile Re-numbering payload file names ...
   call :reNumberPayloadFiles !vibPayloadName! t x 0 || exit /b 1
   call :reNumberPayloadFiles !vibPayloadName! v y !j! || exit /b 1
   :skipvib
   call :logFile Cleaning vib-dir ...
   call :logRun rmdir /s /q "%TMPDIR%\vib"
   if exist "%TMPDIR%\vib" call :fatal Error cleaning up the vib-dir & exit /b 1
goto :eof

:AddZIP2ESXi50
   call :log Adding offline-bundle "%~nx1" ...
   call :logFile Unpacking ZIP-file ...
   call :logRun "%SEVENZIP%" x -y -o"%TMPDIR%\zip" %1
   if not "!RC!"=="0" ( call :fatal Error unpacking the ZIP file & exit /b 1)
   pushd "%TMPDIR%\zip"
      if not exist "*.zip" ( call :fatal Corrupt offline bundle. Cannot find metadata.zip file & exit /b 1)
      for %%z in ("*.zip") do set MetaDataZIP=%%z
      call :logFile Unpacking metadata file "!MetaDataZIP!" ...
      call :logRun "%SEVENZIP%" x -y -o".\metadata" "!MetaDataZIP!"
      if not "!RC!"=="0" ( call :fatal Error unpacking !MetaDataZIP! & exit /b 1)
      if not exist "metadata\vibs\*.xml" ( call :fatal Corrupt offline bundle. Illegal Metadata.zip file & exit /b 1)
      for %%x in ("metadata\vibs\*.xml") do (
         call :logFile Get vib-path from "%%x" ...
         findstr /I /L "<relative-path>" "%%x" | "%SED%" -e "s#.*<relative-path>#set vibRelPath=#I;s#</relative-path>.*##I" >"%TMPDIR%\vibRelPath.tmp.cmd"
         call "%TMPDIR%\vibRelPath.tmp.cmd"
         call :logFile Adding vib "!vibRelPath!" ...
         call :AddVIB2ESXi50 "%TMPDIR%\zip\!vibRelPath!" "%TMPDIR%\zip\%%x" || exit /b 1
      )
   popd
goto :eof

:reNumberPayloadFiles
rem parameters: %1=payloadFileName %2=type(t|v) %3=tmptype(x|z) %4=startidx
   set /a j=%4
   if exist "%ISODIR%\%1.%2??" for /f %%f in ('dir /on /b "%ISODIR%\%1.%2??"') do (
      set ext=%%~xf
      set istr=!ext:~-2!
      set jstr=0!j!
      set jstr=!jstr:~-2!
      if !istr! NEQ !jstr! call :renamePayloadFile %1 %2 !istr! %3 !jstr! || exit /b 1
      set /a j=!j!+1
   )
   if exist "%ISODIR%\%1.%3??" for %%f in ("%ISODIR%\%1.%3??") do (
      set ext=%%~xf
      call :renamePayloadFile %1 %3 !ext:~-2! %2 !ext:~-2! || exit /b 1
   )
goto :eof

:renamePayloadFile
rem parameters: %1=payloadFileName %2=oldtype(v|z|x|y) %3=oldnum(00-99) %4=newtype(v|z|x|y) %5=newnum(00-99)
   if exist "%ISODIR%\%1.%2%5" (
      set newname=%1.%4%5
   ) else (
      set newname=%1.%2%5
   )
   for %%z in (a b c d e f g h i j k l m n o p q r s t u v w x y z) do set newname=!newname:%%z=%%z!
   call :logFile Renaming "%1.%2%3" to "!newname!" ...
   call :logRun ren "%ISODIR%\%1.%2%3" "!newname!"
   if not "!RC!"=="0" ( call :fatal Error renaming payload file %1.%2%3 & exit /b 1)
   call :logFile Replacing "%1.%2%3" with "!newname!" in \BOOT.CFG ...
   call :logRun "%SED%" -e "s#--- /%1.%2%3 #--- /!newname! #I" -i "%ISODIR%\BOOT.CFG"
   if not "!RC!"=="0" ( call :fatal Error replacing payload file in BOOT.CFG & exit /b 1)
   call :logFile Replacing "%1.%2%3" with "!newname!" in \EFI\BOOT\BOOT.CFG ...
   call :logRun "%SED%" -e "s#--- /%1.%2%3 #--- /!newname! #I" -i "%ISODIR%\EFI\BOOT\BOOT.CFG"
   if not "!RC!"=="0" ( call :fatal Error replacing payload file in \EFI\BOOT\BOOT.CFG & exit /b 1)
   call :logFile Replacing "%1.%2%3" with "!newname!" in host profile XML ...
   call :logRun "%SED%" -e "s#>%1.%2%3<#>!newname!<#I" -i "%IMGDBDIR%\var\db\esximg\profiles\!profileXML!"
   if not "!RC!"=="0" ( call :fatal Error replacing payload file in host profile XML & exit /b 1)
goto :eof

:CopyOEM2ISORoot
   call :logFile Copying "%1" file to ISO root ...
   call :logRun copy /y "%fOEM%" "%ISODIR%\%1"
   if not "!RC!"=="0" ( call :fatal Error copying '%1' file to ISO root & exit /b 1)
goto :eof

:ModISOLinuxCFG
   call :logFile Adding comment labels to ISOLINUX.CFG ...
   call :logRun findstr "Customized by %SCRIPTNAME%" "%ISODIR%\ISOLINUX.CFG"
   if "!RC!"=="0" call :logFile ... is already there. Skipping. & goto :eof
   ( echo LABEL comment0
   echo   MENU LABEL
   echo LABEL comment1
   echo   MENU LABEL +------------------------------------------------------+
   echo LABEL comment2
   echo   MENU LABEL ^|         Customized by %SCRIPTNAME% %SCRIPTVERSION%          ^|
   echo LABEL comment3
   echo   MENU LABEL ^|          %SCRIPTURL%           ^|
   echo LABEL comment4
   echo   MENU LABEL +------------------------------------------------------+ )>>"%ISODIR%\ISOLINUX.CFG"
   call :logFile Done adding labels to ISOLINUX.CFG.
goto :eof

:FinishESXi50
   call :log Finishing the customized ESXi 5.x ISO ...
   call :logFile Re-packing the IMGDB.TGZ file ...
   pushd "%IMGDBDIR%"
      set IMGDBTAR=%TMPDIR%\IMGDB.tar
      call :logRun "%BUSYBOX%" tar -cf ..\IMGDB.tar *
      if not "!RC!"=="0" ( popd & call :fatal Error taring new IMGDB.tar & exit /b 1)
   popd
   call :logRun "%SEVENZIP%" a -tgzip -y "%TMPDIR%\IMGDB.TGZ" "%IMGDBTAR%"
   if not "!RC!"=="0" ( call :fatal Error compressing new IMGDB.tar & exit /b 1)
   call :logFile Copying IMGDB.TGZ file to ISO root ...
   call :logRun copy /y "%TMPDIR%\IMGDB.TGZ" "%ISODIR%"
   if not "!RC!"=="0" ( call :fatal Error copying IMGDB.TGZ file to ISO root & exit /b 1)
goto :eof


REM ===== entry points for script exits ======

:earlyFatal
   setlocal disabledelayedexpansion
   call :logCons !-----------------------------------------------------------------------------------
   call :logCons !-- FATAL ERROR: %*!
   call :logCons !-----------------------------------------------------------------------------------
   "%MSGBOX%" 266256 "FATAL ERROR:&n   %*!"
exit /b 1

:fatal
   setlocal disabledelayedexpansion
   call :logFile !-----------------------------------------------------------------------------------
   call :logFile !-- FATAL ERROR: %*!
   call :logFile !-----------------------------------------------------------------------------------
   call :logRun "%MSGBOX%" 266260 "FATAL ERROR:&n   %*!&n&nSee log file '%LOGFILE%' for details! Do you want to open the log file in notepad now?"
   setlocal enabledelayedexpansion
   set OPENLOG=!RC!

:cleanup
   call :log Cleaning up ...
   del /f /q "%PARAMSFILE%" >nul: 2>&1
   if "!IMGATT!"=="1" (
      call :logFile Unmount the dd-image ...
      call :logRun "%DISKPART%" /s "%TMPDIR%\diskpart-detach.txt"
      if exist "%TMPDIR%\Hypervisor1\a.z" ( call :logWarning The dd-image is still mounted. Please check manually with diskpart.exe. )
   )
   call :logRun rmdir /s /q "%TMPDIR%"
   if exist "%TMPDIR%" (
      call :logWarning Could not delete "%TMPDIR%".
      call :log Please check and clean up manually.
   )
   call :logCons Good bye ...
   call :logFile This is the end.
   if "%OPENLOG%"=="1" start "" "%NOTEPAD%" "%LOGFILE%"
exit /b 1
