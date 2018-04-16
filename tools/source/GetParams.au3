#cs ----------------------------------------------------------------------------

 AutoIt Version: 3.3.8.0
 Script name:    GetParams.au3
 Script version: 2.7.2
 Author:         Andreas Peetz (ESXi-Customizer@v-front.de)

 Script Function:
	Get the parameters for ESXi-Customizer

 License: This source code and its compiled executable are licensed
          under the GNU GPL v3. A copy of the license terms is included
		  in the file GPL-v3.txt

#ce ----------------------------------------------------------------------------

#AutoIt3Wrapper_Res_FileVersion=2.7.2
#AutoIt3Wrapper_Res_ProductVersion=2.7.2
#AutoIt3Wrapper_Res_LegalCopyright=(C) Andreas Peetz, licensed under the GNU GPL v3
#AutoIt3Wrapper_Res_Description=Get Parameters GUI
#AutoIt3Wrapper_Res_Field=ProductName|ESXi-Customizer
#AutoIt3Wrapper_Res_Field=ProductVersion|2.7.2
#AutoIt3Wrapper_Res_Language=1033

#NoTrayIcon
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <EditConstants.au3>

Opt("GuiCoordMode",0)
Opt("GuiResizeMode", $GUI_DOCKLEFT + $GUI_DOCKTOP + $GUI_DOCKSIZE)

if $CmdLine[0] <> 1 Then
	MsgBox(0, "Error", "Usage: " & @ScriptName & " <file-to-store-parameters>")
	Exit(2)
EndIf

; Create the GUI elements
$GUI = GUICreate("ESXi-Customizer - ESXi-Customizer.v-front.de", 500, 263, 250, 250, $WS_CAPTION + $WS_SYSMENU + $WS_MINIMIZEBOX + $WS_SIZEBOX)
GUICtrlCreateLabel("Select the original VMware ESXi ISO:", 10, 10, 400)
$ISO_Browse = GUICtrlCreateButton(" Browse... ", 0, 18)
$ISO_Input = GUICtrlCreateInput("", 65, 3 , 410, 20, $ES_LEFT)
GUICtrlCreateLabel("Select an OEM.tgz file, a VIB file or an Offline Bundle:", -65, 30, 400)
$OEM_Browse = GUICtrlCreateButton(" Browse... ", 0, 18)
$OEM_Input = GUICtrlCreateInput("", 65, 3 , 410, 20, $ES_LEFT)
GUICtrlCreateLabel("Select the working directory (needs to be on a local NTFS-formatted drive):", -65, 30, 400)
$WD_Browse = GUICtrlCreateButton(" Browse... ", 0, 18)
$WD_Input = GUICtrlCreateInput("", 65, 3 , 410, 20, $ES_LEFT)

$tgz_repack = GUICtrlCreateLabel("Choose TGZ repacking option (only for TGZ files, see tooltips for further information):",-64,30)
Dim $radio[3]
$radio[0] = GUICtrlCreateRadio("Do not touch", 0, 15, 120, 20)
GUICtrlSetTip(-1, "Uses the package as is, preserves symbolic links," & @LF & "special permissions (e.g. for executables) etc.")
$radio[1] = GUICtrlCreateRadio("Force repacking", 120, 0, 120, 20)
GUICtrlSetTip(-1, "To fix bad TGZ packages that cause 'Corrupt boot image'" & @LF & "messages when booting the installed system." & @LF & "This was the default in older versions.")
$radio[2] = GUICtrlCreateRadio("Force repacking and pause for adv. editing", 120, 0, 240, 20)
GUICtrlSetTip(-1, "Use this (at your own risk!) if you want to make manual" & @LF & "changes to the contents of the TGZ file.")

; $enableUEFI = GUICtrlCreateCheckbox("Create (U)EFI-bootable ISO (ESXi 5.0 only)", -240, 25)
; GUICtrlSetTip(-1, "Enable this option to create an ISO file with (U)EFI boot record." & @LF & "Such an ISO file cannot be further customized by ESXi-Customizer!")
$updateCheck = GUICtrlCreateCheckbox("Enable automatic update check (requires working Internet connection)", -240, 20)
GUICtrlSetTip(-1, "Please leave this enabled to be notified about ESXi-Customizer updates.")
$Launcher = GUICtrlCreateButton(" Run! ", 170, 30)
$Canceler = GUICtrlCreateButton(" Cancel ", 60, 0)

; function to switch TGZ repack options to enabled/disabled
Func ToggleTGZOptions($onoff)
	GUICtrlSetState($tgz_repack, $onoff)
	GUICtrlSetState($radio[0], $onoff)
	GUICtrlSetState($radio[1], $onoff)
	GUICtrlSetState($radio[2], $onoff)
EndFunc

; Set initial GUI controls' state
GUICtrlSetState($ISO_Input, $GUI_DISABLE)
GUICtrlSetState($OEM_Input, $GUI_DISABLE)
GUICtrlSetState($WD_Input, $GUI_DISABLE)
GUICtrlSetState($Launcher, $GUI_DISABLE)
ToggleTGZOptions($GUI_DISABLE)

; Load last settings from ini-file
$ISO_File = IniRead(@AppDataDir & "\ESXi-Customizer.ini", "Settings", "sISO", "")
if FileExists($ISO_File) Then GUICtrlSetData($ISO_Input, $ISO_File)
$OEM_File = IniRead(@AppDataDir & "\ESXi-Customizer.ini", "Settings", "fOEM", "")
if FileExists($OEM_File) Then
	GUICtrlSetData($OEM_Input, $OEM_File)
	If StringLower(StringRight($OEM_File, 4)) = ".tgz" Then ToggleTGZOptions($GUI_ENABLE)
EndIf
$WorkDir = IniRead(@AppDataDir & "\ESXi-Customizer.ini", "Settings", "wDir", "")
if $WorkDir = "" OR NOT FileExists($WorkDir) Then $WorkDir = @MyDocumentsDir
GUICtrlSetData($WD_Input, $WorkDir)
$repackOpt = IniRead(@AppDataDir & "\ESXi-Customizer.ini", "Settings", "repackOpt", "1")
GUICtrlSetState($radio[$repackOpt], $GUI_CHECKED)
GUICtrlSetState($radio[Mod($repackOpt+1,3)], $GUI_UNCHECKED)
GUICtrlSetState($radio[Mod($repackOpt+2,3)], $GUI_UNCHECKED)
; if IniRead(@AppDataDir & "\ESXi-Customizer.ini", "Settings", "enableUEFI", "0") = "1" Then GUICtrlSetState($enableUEFI,$GUI_CHECKED)
if IniRead(@AppDataDir & "\ESXi-Customizer.ini", "Settings", "updateCheck", "1") = "1" Then GUICtrlSetState($updateCheck,$GUI_CHECKED)

; characters not allowed in file names (will cause errors in the script)
$InvalidChars = "%&!()"

; function to test a filename for invalid characters
Func TestInvalidChars($testString)
	if StringRegExp($testString,"[" & $InvalidChars & "]") Then
		MsgBox(0,"Invalid character", "The name of the selected file contains an invalid character (" & $InvalidChars & ") that will cause errors with the script. Please rename the file and re-select it!")
		return 1
	Else
		return 0
	EndIf
EndFunc

; Show the GUI
GUISetState()

; Get and react on messages
While 1
	; Enable the Run-Button if all parameters are set
	If GUICtrlRead($ISO_Input) <> "" AND GUICtrlRead($OEM_Input) <> "" AND GUICtrlRead($WD_Input) <> "" Then
		if BitAnd(GuiCtrlGetState($Launcher), $GUI_DISABLE) > 0 Then GUICtrlSetState($Launcher, $GUI_ENABLE)
	Else
		if BitAnd(GuiCtrlGetState($Launcher), $GUI_ENABLE) > 0 Then GUICtrlSetState($Launcher, $GUI_DISABLE)
	EndIf
	; Get message
	$msg = GUIGetMsg()
	Select
		; Cancel button clicked
		case $msg = $Canceler OR $msg = $GUI_EVENT_CLOSE
			$ExitCode = 1
			ExitLoop
		; Browse for ISO
		case $msg = $ISO_Browse
			$ISO_File = GUICtrlRead($ISO_Input)
			if $ISO_File = "" Then
				$ISO_BrowseDir = @MyDocumentsDir
			Else
				$ISO_BrowseDir = StringLeft($ISO_File,StringInStr($ISO_File,"\",0,-1)-1)
			EndIf
			$ISO_Selection = FileOpenDialog("Select the original VMware ESXi ISO file:", $ISO_BrowseDir, "ISO files (*.iso)", 1 )
			if $ISO_Selection <> "" AND Not TestInvalidChars($ISO_Selection) Then GUICtrlSetData($ISO_Input, $ISO_Selection)
		; Browse for OEM file
		case $msg = $OEM_Browse
			$OEM_File = GUICtrlRead($OEM_Input)
			if $OEM_File = "" Then
				$OEM_BrowseDir = @MyDocumentsDir
			Else
				$OEM_BrowseDir = StringLeft($OEM_File,StringInStr($OEM_File,"\",0,-1)-1)
			EndIf
			$OEM_Selection = FileOpenDialog("Select the OEM package", $OEM_BrowseDir, "TGZ files (*.tgz)| VIB files (*.vib) | Offline bundles (*.zip)", 1 )
			if $OEM_Selection <> "" AND Not TestInvalidChars($OEM_Selection) Then
				GUICtrlSetData($OEM_Input, $OEM_Selection)
				If StringLower(StringRight($OEM_Selection, 4)) = ".tgz" Then
					ToggleTGZOptions($GUI_ENABLE)
				Else
					ToggleTGZOptions($GUI_DISABLE)
				EndIf
			EndIf
		; Browse for working dir
		case $msg = $WD_Browse
			$WorkDir = GuiCtrlRead($WD_Input)
			If $WorkDir = "" Then
				$WorkDirBrowse = @MyDocumentsDir
			Else
				$WorkDirBrowse = $WorkDir
			EndIf
			$WD_Selection = FileSelectFolder("Select the working directory:", "", 1+2, $WorkDirBrowse)
			if $WD_Selection <> "" AND Not TestInvalidChars($WD_Selection) Then GUICtrlSetData($WD_Input, $WD_Selection)
		; Run button clicked
		case $msg = $Launcher
;			If GUICtrlRead($enableUEFI) = $GUI_CHECKED AND MsgBox(266545,"Warning", "Please note: An (U)EFI-bootable ISO cannot be further customized by ESXi-Customizer!") = 2 Then ContinueLoop
			$CheckDrive = StringLeft(GUICtrlRead($WD_Input),2)
			; MsgBox(0,"Debug","DriveType=" & DriveGetType($CheckDrive & "\") & " FileSystem=" & DriveGetFileSystem($CheckDrive & "\"))
			If $CheckDrive = "\\" OR DriveGetType($CheckDrive & "\") = "Network" Then
				MsgBox(0,"Error", "The Working Directory is on a network share which is not supported by the script. Please select a directory from a local disk that is NTFS formatted!")
				ContinueLoop
			Elseif DriveGetFileSystem($CheckDrive & "\") <> "NTFS" Then
				MsgBox(0,"Error", "The Working Directory needs to be on a local NTFS formatted drive! The drive you selected is of type " & DriveGetFileSystem($CheckDrive & "\") & "!")
				ContinueLoop
			EndIf
			IniWrite(@AppDataDir & "\ESXi-Customizer.ini", "Settings", "sISO", GUICtrlRead($ISO_Input))
			IniWrite(@AppDataDir & "\ESXi-Customizer.ini", "Settings", "fOEM", GUICtrlRead($OEM_Input))
			IniWrite(@AppDataDir & "\ESXi-Customizer.ini", "Settings", "wDir", GUICtrlRead($WD_Input))
			for $i = 0 to 2
				if BitAND(GUICtrlRead($radio[$i]), $GUI_CHECKED) = $GUI_CHECKED then $repackOpt = $i
			Next
			IniWrite(@AppDataDir & "\ESXi-Customizer.ini", "Settings", "repackOpt", $repackOpt)
;			If GUICtrlRead($enableUEFI) = $GUI_CHECKED Then
;				$enableUEFI_Flag = "1"
;			Else
;				$enableUEFI_Flag = "0"
;			EndIf
;			IniWrite(@AppDataDir & "\ESXi-Customizer.ini", "Settings", "enableUEFI", $enableUEFI_Flag)
			If GUICtrlRead($updateCheck) = $GUI_CHECKED Then
				$updateCheck_Flag = "1"
			Else
				$updateCheck_Flag = "0"
			EndIf
			IniWrite(@AppDataDir & "\ESXi-Customizer.ini", "Settings", "updateCheck", $updateCheck_Flag)
			$parFile = FileOpen($CmdLine[1], 2)
			If $parFile = -1 Then
				MsgBox(0, "Error", "Cannot open output file " & $CmdLine[1])
				$ExitCode = 2
			Else
				FileWriteLine($parFile,"set sISO=" & GUICtrlRead($ISO_Input))
				FileWriteLine($parFile,"set fOEM=" & GUICtrlRead($OEM_Input))
				FileWriteLine($parFile,"set wDir=" & GUICtrlRead($WD_Input))
				FileWriteLine($parFile,"set repackOpt=" & $repackOpt)
;				FileWriteLine($parFile,"set enableUEFI=" & $enableUEFI_Flag)
				FileWriteLine($parFile,"set updateCheck=" & $updateCheck_Flag)
				FileClose($parFile)
				$ExitCode = 0
			EndIf
			ExitLoop
	EndSelect
WEnd

GUIDelete()

Exit($ExitCode)