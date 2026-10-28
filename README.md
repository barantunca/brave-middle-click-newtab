# Brave middle-click new tab

Middle-click on the empty area of Brave's tab strip to open a new tab, just like in Firefox. An AutoHotkey v2 script for Windows.

- Middle-clicking a **tab** still just closes it.
- Middle-clicking a **link** still opens it in a new tab (no extra tab).
- The "+" button, address bar, bookmarks bar, window buttons, extension icons and page content are left alone.
- Only active when the foreground window is `brave.exe`.
- Zero idle CPU: no timers, no polling. The UI Automation query only runs when you middle-click.
- DPI-safe (125% / 150% scaling, maximized or not): the decision is made from the UI Automation element under the cursor, not from pixel coordinates.
- Plain COM (`CUIAutomation`), no external library.

## Install

1. Install [AutoHotkey v2](https://www.autohotkey.com/).
2. Download `brave-middle-click-newtab.ahk` and double-click it. A green "H" icon appears in the tray.

To start it with Windows: press `Win+R`, run `shell:startup`, and put a shortcut to the `.ahk` file in that folder.

## How it works

Brave (Chromium) exposes its tab strip through UI Automation. Measured with Brave on Windows 11, horizontal tabs:

| What you click | UIA element |
|---|---|
| Empty tab strip area | `Pane`, class `FrameGrabHandle`, inside `BraveHorizontalTabStripRegionView` |
| A tab | `TabItem`, class `BraveTab` |
| "+" button | `Button`, class `BraveNewTabButton` |

`Ctrl+T` is sent only if the element under the cursor is the empty area **and** its parent chain contains the tab strip **and** it contains no `TabItem`. Anything else does nothing (whitelist, not blacklist).

The query runs when the middle button is pressed (before Brave closes the tab or opens the link, so the element is read correctly). `Ctrl+T` is sent when the button is released, because Chromium does its own close/open work on release. If the mouse moved more than 8 px between press and release, nothing is sent.

## Debug mode

`Ctrl+Alt+D` toggles debug mode (off by default). While on, every middle-click in Brave shows a tooltip with the ControlType, Name, ClassName and bounds of the element under the cursor plus its parents and the decision, and appends the same text to `brave_uia_log.txt` next to the script.

## Limitations

- Horizontal tabs only. Vertical tabs use a different region class; open an issue with the debug output if you need it.
- The class names come from Brave's current UI. A Brave update could rename them; debug mode shows what to change (`REGION_CLASS` and `EMPTY_CLASSES` at the top of the script).
- Tested on Brave on Windows 11 only.

## Manual test list

1. Middle-click empty tab strip area: a new tab opens.
2. Middle-click a tab: it closes, no extra tab.
3. Middle-click a link: it opens in a new tab, no extra tab.
4. Middle-click the "+" button or address bar: no extra tab.
5. Middle-click in another app: nothing changes.
