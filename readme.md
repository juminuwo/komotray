# komo*Tray*

A system tray status indicator for the [komorebi](https://github.com/LGUG2Z/komorebi/) tiling window manager. It shows the focused workspace and monitor for each display with independent tray icons.

<img src="assets/previews/tray.png" height="48" />

## Status indicator

> [!NOTE]
> The preview icons below have white foregrounds. To see them, enable darkmode for your browser or Github.

The icon indicates the currently focused monitor using <img src="assets/previews/0-1.png" height="16" /> and <img src="assets/previews/0-2.png" height="16" /> for the left and right monitor. The number at the center of the icon is the currently focused workspace *on the active monitor*.

For example, the first of the following icons indicates that workspace 1 on the left monitor is focused. The second icon indicates that workspace 1 on the right monitor is focused, etc. The last icon indicates that komorebi is currently paused.

<p float="left">
    <img src="assets/previews/1-1.png" height="48" />
    <img src="assets/previews/1-2.png" height="48" />
    <img src="assets/previews/2-1.png" height="48" />
    <img src="assets/previews/2-2.png" height="48" />
    <img src="assets/previews/pause.png" height="48" />
</p>

Currently, there are icons included for up to 9 workspaces and for 2 monitors. Setups with more workspaces or more monitors are supported but require adding a suitable collection of icons.

## Usage

### Dual Monitor Setup
For dual monitor setups, run both applications:
- `komotray-left.ahk` - Creates a tray icon for the left monitor (Monitor 1)
- `komotray-right.ahk` - Creates a tray icon for the right monitor (Monitor 2)

Each application runs independently and displays its respective monitor's workspace information.

### Single Monitor Setup
For single monitor setups, only run `komotray-left.ahk`.

***Note:*** The script requires komorebi server to be running. Start komorebi manually before launching the tray applications. The capability to restart or pause komorebi has been removed from the tray menu for simplicity.

***Note:*** The first time komo*Tray* is started, the tray icon may eventual disappear in the overflow menu. If this happens simply drag & drop it back to the tray area. After doing this once, Windows should remember the position of komo*Tray* and always show it.

## Tray menu and (optional) hotkeys

Right click on either tray icon opens a simplified menu with options to reload the tray application or exit. The capability to pause, restart, or start komorebi has been removed from the tray menu for simplicity.

Optionally, komo*Tray* can also be used to configure additional key bindings. See [my personal configuration](komorebi-config) for an example. 

