#cs ----------------------------------------------------------------------------

 AutoIt Version: 3.3.8.0
 Script name:    RequireAdmin.au3
 Script version: 1.0
 Author:         Andreas Peetz (ESXi-Customizer@v-front.de)

 Script Function:
	Ensures admin rights and executes script passed as args

 License: This source code and its compiled executable are licensed
          under the GNU GPL v3. A copy of the license terms is included
		  in the file GPL-v3.txt

#ce ----------------------------------------------------------------------------

#AutoIt3Wrapper_Res_FileVersion=1.0
#AutoIt3Wrapper_Res_ProductVersion=2.7.2
#AutoIt3Wrapper_Res_LegalCopyright=(C) Andreas Peetz, licensed under the GPL v3
#AutoIt3Wrapper_Res_Description=Elevate rights
#AutoIt3Wrapper_Res_Field=ProductName|ESXi-Customizer
#AutoIt3Wrapper_Res_Field=ProductVersion|2.7.2
#AutoIt3Wrapper_Res_Language=1033

#RequireAdmin
#NoTrayIcon

if $CmdLine[0]=0 Then
	MsgBox(0, "Usage", @Scriptname & " <command-to-run> [parameters]")
Else
	$Args = ""
	For $i = 2 to $CmdLine[0]
		$Args = $Args & " " & $CmdLine[$i]
	Next
	$val = ShellExecuteWait($CmdLine[1], $Args)
EndIf