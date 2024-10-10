#AutoIt3Wrapper_Au3Check_Parameters=-d -w 1 -w 2 -w 3 -w- 4 -w 5 -w 6 -w- 7
#include <AutoItConstants.au3>
#include <GUIConstantsEx.au3>
#include <File.au3>
#include <Array.au3>
#include <FileConstants.au3>
#include <MsgBoxConstants.au3>
#include <WinAPIFiles.au3>
Opt("WinTitleMatchMode", 2) ; makes it match substring of window. Useful for arduino
Global $demoMode = "1"
Global $indexOfServos = 0

; This is an autoit script that runs v2 of the drone sprayer project. It opens mission planner, connects to the drone, puts a mission on the drone, connects to RTK base station, 
;   then opens arduino windows to run arduino scripts that collect the drone on the landing pad into the battery swap/refill station, finally pushing the drone back out for another mission
; GUI drives everything, calls functions on start etc
MainGUI()

Func MainGUI()
  Local $StartFile, $StartFileValue, $Button1, $Button2, $msg
  Local $iHeight = 150, $iWidth = 550
  Local $continueFlights = 1
  GUICreate("Drone control Window", $iWidth, $iHeight)

  Opt("GUICoordMode", 2)
  $StartFile = GUICtrlCreateInput("C:\Users\naNU\Desktop\dronev2-windows\waypoints\drone1.waypoints", 30, 30, 500)
  $Button1 = GUICtrlCreateButton("Start", -500, 30, 100)
  GUISetState()

  ; Run the GUI until the window is closed
  While 1
    $msg = GUIGetMsg()
    Select
      Case $msg = $GUI_EVENT_CLOSE
        ExitLoop
      Case $msg = $Button1
	    ; Checks To See If The Internet Is Connected first
	    If(_IsInternetConnected() == "True") Then
		  ; first thing is the GUI asks for the starting waypoint file. Then we cycle through all waypoint files in that directory for drone missions. So lets compile that list first
	      $StartFileValue = GUICtrlRead($StartFile) ; Check to see the file exists - the one specified in the GUI on startup. This should be the first waypoints file for a drone flight to follow.
	      If(FileExists($StartFileValue)) Then
			; this file controls continue/stop of drone deployments, it has a 1 in it and when that's changed to 0 it will stop the loop. 
			; In other words, this is a way to stop the the drone missions/batteryswap/refill cycle.
			_createContinueFile() 
			; Set up array of files to go through
		    Local $szDrive, $szDir, $szFName, $szExt ;get the directory path from filename
		    _PathSplit($StartFileValue, $szDrive, $szDir, $szFName, $szExt)
		    Local $aFileList = _FileListToArray($szDrive & $szDir, "*waypoints") ; find all waypoint files in directory  Display: ;_ArrayDisplay($aFileList, "$aFileList")
		    Local $indexResult = _ArrayFindAll($aFileList, $szFName & $szExt) ; find where this file is in the array so we can increment. Note result is also an array
		    MsgBox(0, 'Start', "Loop starting on: " & $aFileList[$indexResult[0]])
			_StartUpArduino() ;Leave these open throughout - these are all the arduino windows we might use during collection/deployment. It includes all servo motor positions and battery left/right push
		    For $i = $indexResult[0] To $aFileList[0] Step 1
		      If(_readContinueFile() == "1") Then ; Check if we should continue - this is our control file for stopping the loop, otherwise end for loop
			    ;_RunMission($szDrive & $szDir & $aFileList[$i]) ; this flys the drone - assumes its ready to fly
				If(_readContinueFile() == "1") Then ; Again check if we should continue before actually doing so
					_CollectDroneSwap() ; this runs arduino program to collect drone, swap stuff and spit it out ready to fly
				Else
					MsgBox(0, 'Stopping', "Continue File doesn't show 1")
					ExitLoop
				Endif
			  Else
				MsgBox(0, 'Stopping', "Continue File doesn't show 1")
			    ExitLoop
			  EndIf
			Next
	      Else
		    MsgBox(0, 'No Start', "That file doesn't exist, can't start")
	      EndIf
	    Else
	      MsgBox(0, 'No Start', "Can't start because internet isn't connected")
	    EndIf
    EndSelect
  WEnd
  WinClose("donothing")
  WinClose("drone_battery_swap")
  _rmContinuefile()
EndFunc

Func _IsInternetConnected()
	Local $aReturn = DllCall('connect.dll', 'long', 'IsInternetConnected')
	If @error Then
	  Return SetError(1, 0, False)
	EndIf
	Return $aReturn[0] = 0
EndFunc ;==>_IsInternetConnected

Func _RunMission($droneFile)
	;Now bring up mission planner. Connect to drone. Connect to base station. Load Plan. Start Mission
	Run("C:\Program Files (x86)\Mission Planner\MissionPlanner.exe")
	Sleep(30000)
	If WinExists("Update Now") Then
	  WinActivate("Update Now") ;Update Now window - exit out
	  Sleep(1000)
	  MouseClick($MOUSE_CLICK_PRIMARY, 886, 485, 1) 
	  Sleep(1000)
	EndIf
	Sleep(1000)
	MouseClick($MOUSE_CLICK_PRIMARY, 1580, 43, 1) ; 1580, 43 is position of connect button (connect to drone). single click
	Sleep(20000); allow connection to proceed
	MouseClick($MOUSE_CLICK_PRIMARY, 123, 53, 1) ; 123, 53 is position of setup bar
	Sleep(1000)
	MouseClick($MOUSE_CLICK_PRIMARY, 89, 142, 1) ; optional hardware
	Sleep(1000)
	MouseClick($MOUSE_CLICK_PRIMARY, 80, 180, 1) ; rtk/gps inject
	Sleep(1000)
	MouseClick($MOUSE_CLICK_PRIMARY, 341, 87, 1) ; connect
	Sleep(1000)
	MouseClick($MOUSE_CLICK_PRIMARY, 862, 482, 1) ; exit out error if it's there
	Sleep(1000)
	MouseClick($MOUSE_CLICK_PRIMARY, 862, 482, 1) ; OK on connect. wait longer to connect
	Sleep(60000) ; wait for connection to complete, let rtk settle in
	If WinExists("New Firmware") Then
		WinActivate("New Firmware")
		Sleep(1000)
		MouseClick($MOUSE_CLICK_PRIMARY, 883, 479, 1) 
		Sleep(1000)
	EndIf
	MouseClick($MOUSE_CLICK_PRIMARY, 73, 53, 1) ; 73, 53 is position of plan
	Sleep(1000)
	MouseClick($MOUSE_CLICK_PRIMARY, 1518, 223, 1) ; 1518, 223 is position of load plan
	Sleep(1000)
	Send($droneFile)
	Send("{ENTER}")
	Sleep(1000)
	if WinExists("Reset") Then
	  WinActivate("Reset")
	  MouseClick($MOUSE_CLICK_PRIMARY, 798, 472, 1) ; position of yes reset home to loaded coords
	  Sleep(1000)
	EndIf
	MouseClick($MOUSE_CLICK_PRIMARY, 1535, 327, 1) ; position of write to drone
	Sleep(15000); wait longer to write all the points to drone
	MouseClick($MOUSE_CLICK_PRIMARY, 15, 42, 1) ; position of data tab
	Sleep(1000)
	MouseClick($MOUSE_CLICK_PRIMARY, 68, 540, 1) ; position of actions subtab
	Sleep(1000)
	MouseClick($MOUSE_CLICK_PRIMARY, 300, 583, 1) ; position of auto - drone setting
	Sleep(1000)
	MouseClick($MOUSE_CLICK_PRIMARY, 418, 693, 1) ; position of arm/disarm
	If($demoMode == "0") Then
	  Sleep(600000) ; wait 10 minutes for drone flight to complete, then continue automatically
	Else
	  Sleep(2000) 
	  MsgBox(0, 'Proceed', 'Click to proceed')
	EndIf
	MouseClick($MOUSE_CLICK_PRIMARY, 1580, 43, 1) ; disconnect
	Sleep(5000)
	WinClose("Mission Planner")
	 ; IMPROVE: figure out how to detect the drone has landed rather than long wait
 EndFunc
Func _CollectDroneSwap()
	Sleep(2000)
	WinActivate("drone_battery_swap_v2_start")
	Sleep(1000)
	Send("^u") ;uploads drone collect and start to arduino
	If($demoMode == "0") Then
	  Sleep(150000) ; wait 2 minutes for collect to finish 
	Else
	  Sleep(2000) 
	  MsgBox(0, 'Proceed', 'Click to proceed')
    EndIf
    If($indexOfServos == 5) Then
	  $indexOfServos = 0 ;prep for next battery position
	  WinActivate("drone_battery_swap_v2_servoR-2")
	  Sleep(1000)
	  Send("^u")
	  If($demoMode == "0") Then
	    Sleep(200000) ;wait 3 minutes for this step.
	  Else
	    Sleep(2000) 
	    MsgBox(0, 'Proceed', 'Click to proceed')
	  EndIf
    EndIf
    If($indexOfServos == 4) Then
	  $indexOfServos = 5 ;prep for next battery position
	  WinActivate("drone_battery_swap_v2_servoL-2")
	  Sleep(1000)
	  Send("^u")
	  If($demoMode == "0") Then
	    Sleep(200000) ;wait 3 minutes for this step.
	  Else
	    Sleep(2000) 
	    MsgBox(0, 'Proceed', 'Click to proceed')
	  EndIf
    EndIf
	If($indexOfServos == 3) Then
	  $indexOfServos = 4 ;prep for next battery position
	  WinActivate("drone_battery_swap_v2_servoR-1")
	  Sleep(1000)
	  Send("^u")
	  If($demoMode == "0") Then
	    Sleep(200000) ;wait 3 minutes for this step.
	  Else
	    Sleep(2000) 
	    MsgBox(0, 'Proceed', 'Click to proceed')
	  EndIf
    EndIf  
    If($indexOfServos == 2) Then
	  $indexOfServos = 3 ;prep for next battery position
	  WinActivate("drone_battery_swap_v2_servoL-1")
	  Sleep(1000)
	  Send("^u")
	  If($demoMode == "0") Then
	    Sleep(200000) ;wait 3 minutes for this step.
	  Else
	    Sleep(2000) 
	    MsgBox(0, 'Proceed', 'Click to proceed')
	  EndIf
    EndIf
    If($indexOfServos == 1) Then
	  $indexOfServos = 2 ;prep for next battery position
	  WinActivate("drone_battery_swap_v2_servoR-0")
	  Sleep(1000)
	  Send("^u")
	  If($demoMode == "0") Then
	    Sleep(200000) ;wait 3 minutes for this step.
	  Else
	    Sleep(2000) 
	    MsgBox(0, 'Proceed', 'Click to proceed')
	  EndIf
    EndIf  
    If($indexOfServos == 0) Then
	  $indexOfServos = 1 ;prep for next battery position
	  WinActivate("drone_battery_swap_v2_servoL-0")
	  Sleep(1000)
	  Send("^u")
	  If($demoMode == "0") Then
	    Sleep(200000) ;wait 3 minutes for this step.
	  Else
	    Sleep(2000) 
	    MsgBox(0, 'Proceed', 'Click to proceed')
	  EndIf
    EndIf
    WinActivate("drone_battery_swap_v2_end")
	Sleep(1000)
	Send("^u") ;uploads end of 
	If($demoMode == "0") Then
	    Sleep(360000) ;wait 6 minutes for this step.
	Else
	    Sleep(2000) 
	    MsgBox(0, 'Proceed', 'Click to proceed')
	EndIf
    WinActivate("donothing")
	Sleep(1000)
	Send("^u") ;uploads donothing to arduino so we can relaunch
	;Then start loop over on mission planner with new file
EndFunc
Func _StartUpArduino()
	; Open arduino connection. Load "do nothing" script so we don't run the lander accidentally. keep do nothing and lander arduino windows ready
	;$iPID = Run('C:\Users\naNU\Desktop\ardu\arduino-1.8.19-windows\arduino.exe', @SW_MAXIMIZE)
	$cmds = "C:\Users\naNU\Desktop\dronev2-windows\arduino-1.8.19-windows\arduino.exe"
	$iPID = Run(@ComSpec & " /c " & $cmds)    ; don't forget " " before "/c".  startup of arduino only runs reliably from cmd line for some reason
	;Allow window to initialize...
	Sleep (15000)
	;Send("#d") ;minimize all windows
	;WinActivate("Arduino")
	Send("^o")
	Sleep(1000)
	Send("C:\Users\naNU\Desktop\dronev2-windows\donothing\donothing.ino")
	Send("{ENTER}")
	Sleep(1000)
	WinActivate("donothing")
	Sleep(1000)
	Send("^u") ;uploads donothing to arduino
	Sleep(20000); wait for upload
	Send("^o")
	Sleep(1000)
	Send("C:\Users\naNU\Desktop\dronev2-windows\drone_battery_swap_v2_start\drone_battery_swap_v2_start.ino")
	Send("{ENTER}")
	Sleep(2000)
	Send("^o")
	Sleep(1000)
	Send("C:\Users\naNU\Desktop\dronev2-windows\drone_battery_swap_v2_end\drone_battery_swap_v2_end.ino")
	Send("{ENTER}")
	Sleep(2000)
	Send("^o")
	Sleep(1000)
	Send("C:\Users\naNU\Desktop\dronev2-windows\drone_battery_swap_v2_servoL-0\drone_battery_swap_v2_servoL-0.ino")
	Send("{ENTER}")
	Sleep(2000)
	Send("^o")
	Sleep(1000)
	Send("C:\Users\naNU\Desktop\dronev2-windows\drone_battery_swap_v2_servoL-1\drone_battery_swap_v2_servoL-1.ino")
	Send("{ENTER}")
	Sleep(2000)
	Send("^o")
	Sleep(1000)
	Send("C:\Users\naNU\Desktop\dronev2-windows\drone_battery_swap_v2_servoL-2\drone_battery_swap_v2_servoL-2.ino")
	Send("{ENTER}")
	Sleep(2000)
	Send("^o")
	Sleep(1000)
	Send("C:\Users\naNU\Desktop\dronev2-windows\drone_battery_swap_v2_servoR-0\drone_battery_swap_v2_servoR-0.ino")
	Send("{ENTER}")
	Sleep(2000)
	Send("^o")
	Sleep(1000)
	Send("C:\Users\naNU\Desktop\dronev2-windows\drone_battery_swap_v2_servoR-1\drone_battery_swap_v2_servoR-1.ino")
	Send("{ENTER}")
	Sleep(2000)
	Send("^o")
	Sleep(1000)
	Send("C:\Users\naNU\Desktop\dronev2-windows\drone_battery_swap_v2_servoR-2\drone_battery_swap_v2_servoR-2.ino")
	Send("{ENTER}")
	Sleep(2000)
	; All needed arduino programs are now open.  Use WinActivate("donothing") or WinActivate("drone_battery_swap...") to bring them up and upload to arduino
EndFunc
Func _createContinueFile()
  ; Create file in same folder as script
  $sFileName = @ScriptDir &"\continue.txt"
  ; Open file - deleting any existing content
  $hFilehandle = FileOpen($sFileName, $FO_OVERWRITE)
  ; Write a line
  FileWrite($hFilehandle, "1")
  ; Close the handle so it can be modified  by hand as needed
  FileClose($hFilehandle)
EndFunc 

Func _readContinueFile()
  ; Create file in same folder as script
  $sFileName = @ScriptDir &"\continue.txt"
  ; Open file - deleting any existing content
  $hFilehandle = FileOpen($sFileName, $FO_READ)
  ; Read it
  local $fileContent = FileRead($sFileName)
  ; Close the handle so it can be modified  by hand as needed
  FileClose($hFilehandle)
  Return $fileContent
EndFunc 

Func _rmContinueFile()
  ; Create file in same folder as script
  $sFileName = @ScriptDir &"\continue.txt"
  ; Delete the temporary file.
  FileDelete($sFileName)
EndFunc
