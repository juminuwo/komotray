#SingleInstance, force
#NoEnv

#Include, %A_ScriptDir%\lib\JSON.ahk

; Set common config options
AutoStartKomorebi := true
global IconPath := A_ScriptDir . "/assets/icons/"
global KomorebiConfig := A_ScriptDir . "/komorebi-config/komorebi.json"
global MonitorIndex := 1  ; Left monitor (elements[1] in JSON)
global MonitorName := "Left Monitor"

; ======================================================================
; Initialization
; ======================================================================

; Set up simplified tray menu
Menu, Tray, NoStandard
Menu, Tray, add, Reload Tray, ReloadTray
Menu, Tray, add, Exit Tray, ExitTray

; Initialize internal state
MonitorIconState := -1
global Screen := 0
global LastTaskbarScroll := 0

; Check if komorebi server is running
Process, Exist, komorebi.exe
if (!ErrorLevel) {
    MsgBox, Warning: Komorebi server is not running. Please start it manually.
}

; ======================================================================
; Event Handler
; ======================================================================

; Set up pipe with unique name for left monitor
PipeName := "komotray-left"
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

; Wait for Komorebi to connect
Komorebi("subscribe " . PipeName)
DllCall("ConnectNamedPipe", "Ptr", Pipe, "Ptr", 0)

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
    Screen := State.Monitors.focused

    ; Update tray icon for left monitor only
    UpdateMonitorIcon(State)
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
    ; Swap monitors on a 2 screen setup
    Komorebi("swap-workspaces-with-monitor " . 1 - Screen)
}

UpdateMonitorIcon(State) {
    ; Check if left monitor exists
    if (State.Monitors.elements.Length() < MonitorIndex) {
        ; Left monitor doesn't exist, exit gracefully
        Menu, Tray, Tip, Left Monitor: Not Connected
        return
    }

    ; Get left monitor information
    Monitor := State.Monitors.elements[MonitorIndex]
    Workspace := Monitor.workspaces.focused
    WorkspaceQ := Monitor.workspaces.elements[Workspace + 1]

    ; Build state for comparison
    NewState := Workspace << 4

    ; Update icon if state changed
    if (NewState != MonitorIconState) {
        ; Use workspace and monitor index for icon name
        icon := IconPath . (Workspace + 1) . "-" . MonitorIndex . ".ico"
        if (FileExist(icon)) {
            Menu, Tray, Icon, %icon%
        } else {
            ; Fallback icon
            Menu, Tray, Icon, % IconPath . "1-1.ico"
        }

        ; Create tooltip showing left monitor information
        TooltipText := "Monitor 1: Workspace " . (Workspace + 1) . " on " . Monitor.name
        Menu, Tray, Tip, %TooltipText%

        MonitorIconState := NewState
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
    ; State-dependent debounce timer to address browser wheel spawning multiple clicks
    _isBrowser := WinActive("ahk_class Chrome_WidgetWin_1") || WinActive("ahk_class MozillaWindowClass")
    _t := _isBrowser ? 800 : 100
    ; Total debounce time = _t[this_call] + _t[last_call] to address interim focus changes
    if (A_PriorKey != A_ThisHotkey) || (A_TickCount - LastTaskbarScroll > _t) {
        LastTaskbarScroll := A_TickCount + _t
        Komorebi("mouse-follows-focus disable")
        Komorebi("cycle-workspace " . dir)
        Komorebi("mouse-follows-focus enable")
    }
}

; ======================================================================
; Auxiliary Functions
; ======================================================================

MouseIsOver(WinTitle) {
    MouseGetPos,,, Win
    return WinExist(WinTitle . " ahk_id " . Win)
}