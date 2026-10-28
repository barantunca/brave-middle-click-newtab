#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================================================
; Brave: middle-click on the empty area of the tab strip -> open a new tab
; (the way Firefox does it)
;
; UI Automation tree measured in Brave (horizontal tabs):
;   Empty area : Pane   class 'FrameGrabHandle'  -> parent 'BraveHorizontalTabStripRegionView'
;   "+" button : Button class 'BraveNewTabButton'
;   A tab      : TabItem class 'BraveTab'
;
; Decision rule (whitelist; when in doubt, do nothing):
;   1) the element under the cursor must have class FrameGrabHandle or
;      BraveHorizontalTabStripRegionView
;   2) walking up the parents, BraveHorizontalTabStripRegionView must be found
;   3) no TabItem may be on the way
;
; The middle click is always passed through to Brave (~), so closing a tab or
; opening a link in a new tab keeps working. The UIA query runs when the middle
; button is PRESSED (before Chromium closes the tab / opens the link, so the
; element is read correctly). Ctrl+T is sent when the button is RELEASED,
; because Chromium does its own close/open work on release.
; No timers, no polling loop: idle CPU is ~0%.
;
;   Ctrl+Alt+D : toggle debug mode (tooltip + brave_uia_log.txt next to the script)
; ============================================================================

MAX_PARENT   := 8
TOOLTIP_MS   := 12000
LOG_FILE     := A_ScriptDir "\brave_uia_log.txt"
REGION_CLASS := "BraveHorizontalTabStripRegionView"      ; the tab strip
EMPTY_CLASSES := Map("FrameGrabHandle", 1, REGION_CLASS, 1) ; classes of the empty area
TABITEM      := 50019                                    ; UIA ControlType TabItem

DebugOn := false
Decision := false        ; decision made on button press
PressX := 0, PressY := 0 ; where the button was pressed

; Per-monitor DPI awareness: UIA gets physical pixels (125% / 150% scaling is fine)
try DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")

; --- UI Automation via plain COM (no external library) ----------------------
UIA := ComObject("{FF48DBA4-60EF-4201-AA87-54103EEF594E}"
               , "{30CBE57D-D9D0-452A-AB13-7AC5AC4825EE}")
Walker := 0
ComCall(14, UIA, "ptr*", &Walker)         ; get_ControlViewWalker

^!d:: {
    global DebugOn
    DebugOn := !DebugOn
    CoordMode("ToolTip", "Screen")
    ToolTip("Brave middle-click debug: " (DebugOn ? "ON" : "OFF"), 20, 20)
    SetTimer(() => ToolTip(), -1500)
}

#HotIf WinActive("ahk_exe brave.exe")
~MButton:: {
    global Decision, PressX, PressY
    CoordMode("Mouse", "Screen")
    MouseGetPos(&PressX, &PressY)
    Decision := false
    info := ""
    try Decision := Analyze(PressX, PressY, &info)
    catch as err
        info .= "ERROR: " err.Message "`n"
    if DebugOn
        ShowDebug(PressX, PressY, info, Decision)
}

~MButton Up:: {
    global Decision
    if !Decision
        return
    Decision := false
    CoordMode("Mouse", "Screen")
    MouseGetPos(&x, &y)
    ; Ignore drags and window switches
    if Abs(x - PressX) > 8 || Abs(y - PressY) > 8
        return
    if WinActive("ahk_exe brave.exe")
        Send("^t")
}
#HotIf

; Looks at the element under the point and its parent chain and decides
; "is this the empty area of the tab strip?". info = chain dump for debug mode.
Analyze(x, y, &info) {
    info := ""
    el := 0
    ComCall(7, UIA, "int64", (x & 0xFFFFFFFF) | (y << 32), "ptr*", &el)  ; ElementFromPoint
    class0 := "", inRegion := false, blocked := false
    level := 0
    while el && level <= MAX_PARENT {
        ctype := 0
        ComCall(21, el, "int*", &ctype)                ; ControlType
        cls := BstrGet(el, 30)                        ; ClassName
        if level = 0
            class0 := cls
        if DebugOn
            info .= (level = 0 ? "[ELEMENT]  " : "[PARENT " level "] ") ElementSummary(el, ctype, cls) "`n"
        if !inRegion && !blocked {
            if ctype = TABITEM
                blocked := true
            else if cls = REGION_CLASS
                inRegion := true
        }
        parent := 0
        ComCall(3, Walker, "ptr", el, "ptr*", &parent)    ; GetParentElement
        ObjRelease(el)
        el := parent
        level++
        if !DebugOn && (inRegion || blocked)
            break                                      ; decided, no need to go further
    }
    if el
        ObjRelease(el)
    return EMPTY_CLASSES.Has(class0) && inRegion && !blocked
}

ShowDebug(x, y, info, decision) {
    CoordMode("ToolTip", "Screen")
    s := "Click (screen): " x "," y "`n----`n" info "----`nDECISION: "
       . (decision ? "send Ctrl+T" : "do nothing")
    ToolTip(s, x + 25, y + 25)
    SetTimer(() => ToolTip(), -TOOLTIP_MS)
    try FileAppend("[" FormatTime(, "yyyy-MM-dd HH:mm:ss") "]`n" s "`n`n", LOG_FILE, "UTF-8")
}

ElementSummary(el, ctype, cls) {
    name := BstrGet(el, 23)                           ; Name
    if StrLen(name) > 40
        name := SubStr(name, 1, 40) "…"
    r := Buffer(16, 0)
    ComCall(43, el, "ptr", r)                         ; BoundingRectangle
    l := NumGet(r, 0, "int"), t := NumGet(r, 4, "int")
    return "Type=" ctype " Name='" name "' Class='" cls "' Rect=" l "," t " "
         . (NumGet(r, 8, "int") - l) "x" (NumGet(r, 12, "int") - t)
}

; Reads a BSTR UIA property and frees the string
BstrGet(el, index) {
    p := 0
    ComCall(index, el, "ptr*", &p)
    s := p ? StrGet(p, "UTF-16") : ""
    if p
        DllCall("oleaut32\SysFreeString", "ptr", p)
    return s
}
