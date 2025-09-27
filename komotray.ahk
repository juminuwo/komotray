#SingleInstance, force
#NoEnv

#Include, %A_ScriptDir%\lib\JSON.ahk

; Set common config options
AutoStartKomorebi := true
global IconPath := A_ScriptDir . "/assets/icons/"
global KomorebiConfig := A_ScriptDir . "/komorebi-config/komorebi.json"

; ======================================================================
; Initialization
; ======================================================================

; Set up simplified tray menu (removed pause/restart functionality)
Menu, Tray, NoStandard
Menu, Tray, add, Reload Tray, ReloadTray
Menu, Tray, add, Exit Tray, ExitTray

; Initialize internal states
LeftMonitorIconState := -1
RightMonitorIconState := -1
global Screen := 0
global LastTaskbarScroll := 0

; Wait for komorebi server to be available with retry logic
WaitForKomorebi()

; ======================================================================
; Event Handler
; ======================================================================

; Set up pipe
PipeName := "komotray"
PipePath := "\\.\pipe\" . PipeName
OpenMode := 0x01  ; access_inbound
PipeMode := 0x04 | 0x02 | 0x01  ; type_message | readmode_message | nowait
BufferSize := 64 * 1024

; Create named pipe instance
Pipe := DllCall("CreateNamedPipe", "Str", PipePath, "UInt", OpenMode, "UInt", PipeMode
    , "UInt", 1, "UInt", BufferSize, "UInt", BufferSize, "UInt", 0, "Ptr", 0, "Ptr")
if (Pipe = -1) {
    MsgBox, % "CreateNamedPipe: " A_LastError
    ExitTray()
}

; Subscribe to Komorebi and wait for connection
SubscribeToKomorebi(PipeName, Pipe)

; Subscribe to Komorebi events
Loop {
    ; Continue if buffer is empty
    ExitCode := DllCall("PeekNamedPipe", "Ptr", Pipe, "Ptr", 0, "UInt", 1
        , "Ptr", 0, "UintP", BytesToRead, "Ptr", 0)
    if (!ExitCode || !BytesToRead) {
        Sleep, 50
        Continue
    }

    ; Read the buffer
    VarSetCapacity(Data, BufferSize, 0 )
    DllCall("ReadFile", "Ptr", Pipe, "Str", Data, "UInt", BufferSize
        , "PtrP", Bytes, "Ptr", 0)

    ; Strip new lines
    if (Bytes <= 1)
        Continue

    State := JSON.Load(StrGet(&Data, Bytes, "UTF-8")).state
    Paused := State.is_paused
    Screen := State.Monitors.focused
    ScreenQ := State.Monitors.elements[Screen + 1]
    Workspace := ScreenQ.workspaces.focused
    WorkspaceQ := ScreenQ.workspaces.elements[Workspace + 1]

    ; Update tray icons for both monitors
    UpdateMonitorIcons(State)
}
Return

; ======================================================================
; Key Bindings
; ======================================================================

; Alt + scroll to cycle workspaces
!WheelUp::ScrollWorkspace("previous")
!WheelDown::ScrollWorkspace("next")

; Scroll taskbar to cycle workspaces
#if MouseIsOver("ahk_class Shell_TrayWnd") || MouseIsOver("ahk_class Shell_SecondaryTrayWnd")
    WheelUp::ScrollWorkspace("previous")
    WheelDown::ScrollWorkspace("next")
#if

; ======================================================================
; Functions
; ======================================================================

Komorebi(arg) {
    RunWait % "komorebic.exe " . arg,, Hide
}



SwapScreens() {
    ; Swap monitors on a 2 screen setup. ToDo: Add safeguard for 3+ monitors
    Komorebi("swap-workspaces-with-monitor " . 1 - Screen)
}


UpdateMonitorIcons(State) {
    ; Get monitor information
    LeftMonitor := State.Monitors.elements[1]
    LeftWorkspace := LeftMonitor.workspaces.focused
    LeftWorkspaceQ := LeftMonitor.workspaces.elements[LeftWorkspace + 1]

    ; Build states for comparison
    NewLeftState := LeftWorkspace << 4
    NewRightState := 0
    RightTooltip := ""

    ; Handle right monitor if it exists
    if (State.Monitors.elements.Length() > 1) {
        RightMonitor := State.Monitors.elements[2]
        RightWorkspace := RightMonitor.workspaces.focused
        RightWorkspaceQ := RightMonitor.workspaces.elements[RightWorkspace + 1]
        NewRightState := RightWorkspace << 8
        RightTooltip := "`nRight: " . (RightWorkspace + 1) . " on " . RightMonitor.name
    }

    ; Update icon if any monitor state changed
    if (NewLeftState != LeftMonitorIconState || NewRightState != RightMonitorIconState) {
        ; Use focused monitor's icon as primary display
        FocusedMonitor := State.Monitors.focused
        FocusedWorkspace := State.Monitors.elements[FocusedMonitor + 1].workspaces.focused

        icon := IconPath . FocusedWorkspace + 1 . "-" . FocusedMonitor + 1 . ".ico"
        if (FileExist(icon)) {
            Menu, Tray, Icon, %icon%
        } else {
            ; Fallback icon
            Menu, Tray, Icon, % IconPath . "1-1.ico"
        }

        ; Create comprehensive tooltip showing both monitors with workspace numbers
        LeftTooltip := "Left: " . (LeftWorkspace + 1) . " on " . LeftMonitor.name
        FullTooltip := LeftTooltip . RightTooltip
        Menu, Tray, Tip, %FullTooltip%

        LeftMonitorIconState := NewLeftState
        RightMonitorIconState := NewRightState
    }
}

ReloadTray() {
    DllCall("CloseHandle", "Ptr", Pipe)
    Reload
}

ExitTray() {
    DllCall("CloseHandle", "Ptr", Pipe)
    ExitApp
}

ScrollWorkspace(dir) {
    ; This adds a state-dependent debounce timer to adress an issue where a single wheel
    ; click spawns multiple clicks when a web browser is in focus.
    _isBrowser := WinActive("ahk_class Chrome_WidgetWin_1") || WinActive("ahk_class MozillaWindowClass")
    _t := _isBrowser ? 800 : 100
    ; Total debounce time = _t[this_call] + _t[last_call] to address interim focus changes
    if (A_PriorKey != A_ThisHotkey) || (A_TickCount - LastTaskbarScroll > _t) {
        LastTaskbarScroll := A_TickCount + _t
        Komorebi("mouse-follows-focus disable")
        Komorebi("cycle-workspace " . dir)
        ; ToDo: only re-enable if it was enabled before
        Komorebi("mouse-follows-focus enable")
    }
}

; ======================================================================
; Retry Logic Functions
; ======================================================================

WaitForKomorebi() {
    MaxRetries := 30
    RetryDelay := 1000

    Loop, %MaxRetries% {
        Process, Exist, komorebi.exe
        if (ErrorLevel) {
            Menu, Tray, Tip, Connected to Komorebi
            return true
        }

        if (A_Index = 1) {
            Menu, Tray, Tip, Waiting for Komorebi to start...
        } else {
            Menu, Tray, Tip, Waiting for Komorebi... (%A_Index%/%MaxRetries%)
        }

        Sleep, %RetryDelay%
    }

    MsgBox, 48, Komorebi Timeout, Komorebi server did not start within 30 seconds.`n`nPlease start komorebi manually and reload this tray application.
    ExitTray()
}

SubscribeToKomorebi(PipeName, Pipe) {
    MaxRetries := 10
    RetryDelay := 500

    Loop, %MaxRetries% {
        try {
            Komorebi("subscribe " . PipeName)
            DllCall("ConnectNamedPipe", "Ptr", Pipe, "Ptr", 0)
            Menu, Tray, Tip, Connected to Komorebi events
            return true
        } catch e {
            if (A_Index < MaxRetries) {
                Menu, Tray, Tip, Connecting to Komorebi... (%A_Index%/%MaxRetries%)
                Sleep, %RetryDelay%
            }
        }
    }

    MsgBox, 48, Connection Failed, Failed to subscribe to Komorebi events.`n`nPlease check if komorebi is running properly.
    ExitTray()
}

; ======================================================================
; Auxiliary Functions
; ======================================================================

MouseIsOver(WinTitle) {
    MouseGetPos,,, Win
    return WinExist(WinTitle . " ahk_id " . Win)
}


