; Add to top of script
#SingleInstance Force
#Persistent
#WinActivateForce
DllCall("winmm\timeBeginPeriod", "uint", 1)

; GUI Setup
Gui, +AlwaysOnTop +ToolWindow -SysMenu
Gui, Color, FFFFFF
Gui, Margin, 15, 15

; Custom styles
Gui, Font, s10 cBlack, Segoe UI
buttonW := 100
buttonH := 30
groupW := 350
spacing := 10

; Timer Group - Reorganized vertically
Gui, Font, s12 bold, Segoe UI
Gui, Add, GroupBox, x10 y5 w%groupW% h120, Timer Controls
Gui, Font, s10 norm, Segoe UI

Gui, Add, Text, xp+15 yp+30, Schedule Time (minutes):
Gui, Add, Edit, x+10 yp-2 vScheduleTime w60 h25 Number Center, 120

; Moved timer buttons below
Gui, Add, Button, x25 y65 w155 h25 gSetTimer +Default, Set Timer
Gui, Add, Button, x+10 yp w155 h25 gStopTimer, Stop Timer

; Status Group
Gui, Font, s12 bold, Segoe UI
Gui, Add, GroupBox, x10 y135 w%groupW% h60, Status
Gui, Font, s10 norm, Segoe UI

Gui, Add, Text, xp+15 yp+25, Current Status:
Gui, Add, Text, x+10 yp vStatusText w200 cGreen, Idle

; Controls Group
Gui, Font, s12 bold, Segoe UI
Gui, Add, GroupBox, x10 y205 w%groupW% h85, Controls
Gui, Font, s10 norm, Segoe UI

; Calculate positions for centered buttons
firstX := 30
Gui, Add, Button, x%firstX% y235 w%buttonW% h%buttonH% gToggleRecord, Record (F5)
Gui, Add, Button, x+10 yp w%buttonW% h%buttonH% gToggleReplay, Replay (F6)
Gui, Add, Button, x+10 yp w%buttonW% h%buttonH% gStopReplay, Stop (F7)

; Timer Display - Increased text area width
Gui, Font, s12 bold, Segoe UI
Gui, Add, GroupBox, x10 y300 w%groupW% h60, Next Auto-Sell
Gui, Font, s10 norm, Segoe UI
Gui, Add, Text, xp+15 yp+25 vTimerDisplay w320 cBlue, Not scheduled

; Exit Button with custom style
Gui, Font, s10, Segoe UI
Gui, Add, Button, x10 y395 w%groupW% h35 gExitScript, Exit Application (Esc)

; Custom button styles
Gui, Add, Text, Hidden vCustomStyles, % CustomButtonStyles()

Gui, Show,, AutoTrader v1.0

return



CustomButtonStyles() {
    ; Add custom button styles
    Loop, % A_Gui "_Button"
    {
        GuiControl, +BackgroundFFFFFF, Button%A_Index%
        GuiControl, +Border0, Button%A_Index%
    }
}

; Add these style functions
ButtonStylesOn:
    GuiControl, +Background98FB98, % A_GuiControl
return

ButtonStylesOff:
    GuiControl, +BackgroundFFFFFF, % A_GuiControl
return

; Update your existing toggle functions to include visual feedback
ToggleRecord:
    if (!Recording) {
        GuiControl, +Background98FB98, Record (F5)
    } else {
        GuiControl, +BackgroundFFFFFF, Record (F5)
    }
    Gosub, F5
return

ToggleReplay:
    if (!Replaying) {
        GuiControl, +Background98FB98, Replay (F6)
    } else {
        GuiControl, +BackgroundFFFFFF, Replay (F6)
    }
    Gosub, F6
return


ResetTimerButtonColor:
    GuiControl, +BackgroundFFFFFF, Set Timer
return



; Global System
global Macro := []
global Recording := false
global Replaying := false
global TimerActive := false
global RefreshTimeMS := 0
global NextRun := 0
global winX, winY
global LastState := "Up"
global LastPos := {x: 0, y: 0}

; Scroll Recording
~WheelDown::
~WheelUp::
    if (Recording) {
        MouseGetPos, mX, mY
        WinGetPos, wX, wY,,, Industry Idle
        relativeX := mX - wX
        relativeY := mY - wY
        direction := InStr(A_ThisHotkey, "WheelDown") ? "Down" : "Up"
        
        Macro.Push( { x: relativeX, y: relativeY, scroll: direction, time: A_TickCount } )
    }
return

; Enhanced Click Recording
~LButton::
    if (Recording && WinActive("Industry Idle")) {
        MouseGetPos, mX, mY, winHandle
        WinGetPos, wX, wY,,, Industry Idle
        
        ; Account for window borders and title bar
        WinGet, style, Style, Industry Idle
        borderWidth := (style & 0x00800000) ? 8 : 0
        titleHeight := (style & 0x00C00000) ? 30 : 0
        
        relativeX := mX - wX - borderWidth
        relativeY := mY - wY - titleHeight
        
        Macro.Push({x: relativeX
                , y: relativeY
                , state: "Down"
                , time: A_TickCount})
    }
return

~LButton Up::
    if (Recording && WinActive("Industry Idle")) {
        MouseGetPos, mX, mY, winHandle
        WinGetPos, wX, wY,,, Industry Idle
        
        ; Account for window borders and title bar
        WinGet, style, Style, Industry Idle
        borderWidth := (style & 0x00800000) ? 8 : 0
        titleHeight := (style & 0x00C00000) ? 30 : 0
        
        relativeX := mX - wX - borderWidth
        relativeY := mY - wY - titleHeight
        
        Macro.Push({x: relativeX
                , y: relativeY
                , state: "Up"
                , time: A_TickCount})
    }
return

; Timer Controls
SetTimer:
    GuiControl, +Background98FB98, Set Timer
    SetTimer, ResetTimerButtonColor, -1000
    Gui, Submit, NoHide
    RefreshTimeMS := ScheduleTime * 60000
    NextRun := A_TickCount + RefreshTimeMS
    TimerActive := true
    SetTimer, AutoSell, % RefreshTimeMS
    SetTimer, UpdateTimer, 1000
    Gosub, UpdateTimer
return

StopTimer:
    TimerActive := false
    SetTimer, AutoSell, Off
    SetTimer, UpdateTimer, Off
    GuiControl,, TimerDisplay, Timer Stopped
return

; Improved Recording Initialization
F5::
    if (!Recording) {
        if !WinExist("Industry Idle") {
            MsgBox Game window not found!
            return
        }
        WinGetPos, winX, winY,,, Industry Idle
        Macro := []
        Recording := true
        LastState := "Up"
        GuiControl,, StatusText, Recording...
        
        ; Record initial position
        MouseGetPos, mX, mY
        relativeX := mX - winX
        relativeY := mY - winY
        Macro.Push( { x: relativeX, y: relativeY, state: "Init", time: A_TickCount } )
        LastPos := {x: relativeX, y: relativeY}
        
        SetTimer, RecordMovement, 10
    } else {
        Recording := false
        SetTimer, RecordMovement, Off
        GuiControl,, StatusText, Idle
    }
return

; Movement Tracker
RecordMovement:
    WinGetPos, newX, newY,,, Industry Idle
    if (newX != winX || newY != winY) {
        winX := newX
        winY := newY
    }
    
    MouseGetPos, mX, mY
    WinGet, style, Style, Industry Idle
    borderWidth := (style & 0x00800000) ? 8 : 0
    titleHeight := (style & 0x00C00000) ? 30 : 0
    
    relativeX := mX - winX - borderWidth
    relativeY := mY - winY - titleHeight
    
    distance := Sqrt((relativeX-LastPos.x)**2 + (relativeY-LastPos.y)**2)
    if (distance > 2) {
        WinGet, windowState, MinMax, Industry Idle
        Macro.Push({x: relativeX
                , y: relativeY
                , state: "Move"
                , time: A_TickCount
                , windowState: windowState})
        LastPos := {x: relativeX, y: relativeY}
    }
return



; Enhanced Replay System
F6::
    if (Replaying || !Macro.Length())
        return
    
    Replaying := true
    GuiControl,, StatusText, Replaying...
    
    if !WinExist("Industry Idle") {
        MsgBox Game window not found!
        Replaying := false
        return
    }
    
    WinActivate, Industry Idle
    Sleep, 100
    
    prevTime := Macro[1].time
    
    for i, action in Macro {
        if (!Replaying)
            break
            
        if (i > 1) {
            timeDiff := action.time - prevTime
            Sleep % timeDiff
        }
        
        ; Get current window position
        WinGetPos, currentX, currentY,,, Industry Idle
        
        ; Account for window borders and title bar
        WinGet, style, Style, Industry Idle
        borderWidth := (style & 0x00800000) ? 8 : 0
        titleHeight := (style & 0x00C00000) ? 30 : 0
        
        ; Calculate target position
        targetX := currentX + action.x + borderWidth
        targetY := currentY + action.y + titleHeight
        
        ; Handle different action types
        if (action.HasKey("scroll")) {
            MouseMove, %targetX%, %targetY%, 0
            Sleep, 10
            Send, % "{Wheel" action.scroll "}"
        } 
        else {
            MouseMove, %targetX%, %targetY%, 0
            Sleep, 10
            
            if (action.state = "Down")
                Click Down
            else if (action.state = "Up")
                Click Up
        }
        
        prevTime := action.time
    }
    
    ; Ensure mouse button is released
    Click Up
    Replaying := false
    GuiControl,, StatusText, Idle
return

; Fixed Scheduler
AutoSell:
    if (TimerActive) {
        Gosub, F6
        NextRun := A_TickCount + RefreshTimeMS
        SetTimer, AutoSell, % RefreshTimeMS
        Gosub, UpdateTimer
    }
return

; Live Timer Updates
UpdateTimer:
    if (TimerActive && NextRun > A_TickCount) {
        remainingMS := NextRun - A_TickCount
        minutes := remainingMS // 60000
        seconds := Mod(remainingMS, 60000) // 1000
        GuiControl,, TimerDisplay, %minutes%m %seconds%s remaining
    }
    else if (TimerActive) {
        NextRun := A_TickCount + RefreshTimeMS
        GuiControl,, TimerDisplay, %ScheduleTime%m 0s remaining
    }
return

; Recording Function
RecordActions:
    WinGetPos, newX, newY,,, Industry Idle
    if (newX != winX || newY != winY) {
        winX := newX
        winY := newY
    }
    
    MouseGetPos, mX, mY
    relativeX := mX - winX
    relativeY := mY - winY
    
    state := GetKeyState("LButton", "P") ? "Down" : "Up"
    
    if (!GetKeyState("WheelDown", "P")) {
        Macro.Push({x: relativeX
                , y: relativeY
                , state: state
                , time: A_TickCount
                , scroll: 0})
    }
return



StopReplay:
F7::
    Replaying := false
    GuiControl,, StatusText, Idle
return

ExitScript:
Esc::
    DllCall("winmm\timeEndPeriod", "uint", 1)
    ExitApp
return