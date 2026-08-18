pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../common"

/**
 * Single source of truth for the macOS cmd-Tab-style window switcher.
 *
 * Entries are apps (windows grouped by class), ordered most-recently-used
 * via Hyprland's focusHistoryID. Monitor/workspace are irrelevant here:
 * every toplevel is a candidate, and confirming focuses the selected
 * app's most-recent window wherever it lives.
 */
Singleton {
    id: root

    property bool open: false
    property int selectedIndex: 0

    // Monitor the switcher is pinned to for this session. Captured at open
    // time so the panel never hops displays if Hyprland's focused monitor
    // changes while the switcher is up (keyboard grab, focus events, etc.).
    property int displayMonitorId: -1

    // address ("0x...") -> Wayland toplevel, for screencopy previews.
    readonly property var toplevelByAddress: {
        const map = ({});
        const values = ToplevelManager.toplevels?.values ?? [];
        for (const tl of values) {
            const addr = `0x${tl?.HyprlandToplevel?.address ?? ""}`;
            map[addr] = tl;
        }
        return map;
    }

    // MRU-ordered list of windows (one entry per window). Each entry:
    //   { appClass, title, focusAddress, addresses, windowCount, rank,
    //     iconPath, toplevel }
    readonly property var entries: {
        // Re-run when the desktop entry index updates (for icon lookup).
        DesktopEntries.applications.values;

        const byAddr = HyprlandData.windowByAddress;
        const includeSpecial = Config.options.switcher.includeSpecialWorkspaces;
        const list = [];

        for (const addr in byAddr) {
            const win = byAddr[addr];
            if (!win)
                continue;
            const wsName = `${win?.workspace?.name ?? ""}`;
            if (!includeSpecial && wsName.startsWith("special:"))
                continue;
            const cls = `${win?.class ?? ""}`;
            const winAddress = `${win?.address ?? ""}`;
            list.push({
                appClass: cls,
                title: `${win?.title ?? cls}`,
                focusAddress: winAddress,
                addresses: [winAddress],
                windowCount: 1,
                rank: win?.focusHistoryID ?? 99999,
                iconPath: root.iconPathForClass(cls),
                toplevel: root.toplevelByAddress[winAddress] ?? null
            });
        }

        list.sort((a, b) => a.rank - b.rank);
        return list;
    }

    readonly property var selectedEntry: entries[selectedIndex] ?? null

    function iconPathForClass(cls) {
        const entry = DesktopEntries.heuristicLookup(`${cls ?? ""}`);
        const raw = `${entry?.icon ?? ""}`.trim()
            .replace(/^image:\/\/icon\//, "")
            .split("?")[0]
            .trim();
        const name = raw.length > 0 ? raw : "application-x-executable";
        return Quickshell.iconPath(name, "image-missing");
    }

    function openSwitcher() {
        // Provisional pin: the focused monitor, so the keyboard grab can fire
        // instantly (a delayed grab misses a fast SUPER release). Guaranteed
        // to be a real id — never -1 — so the panel can't fall into the
        // live-tracking path in WindowSwitcher and hop displays. Refined to
        // the cursor's monitor as soon as the async cursorpos query returns
        // (focusedMonitor can diverge from the cursor when a window on the
        // other display steals focus without the cursor moving).
        root.displayMonitorId = Hyprland.focusedMonitor?.id
            ?? (Hyprland.monitors?.values?.[0]?.id ?? 0);
        root.open = true;
        // Mirror macOS: first tap lands on the previous app.
        root.selectedIndex = root.entries.length > 1 ? 1 : 0;
        // Correct the pin to the monitor the cursor is actually on.
        cursorPosProc.running = true;
    }

    // Which monitor's logical rect contains the given cursor point, or -1.
    // hyprctl reports x/y in logical coords but width/height in physical
    // pixels, so the logical extent is width/scale x height/scale.
    function monitorIdAt(cx, cy) {
        const mons = Hyprland.monitors?.values ?? [];
        for (const mon of mons) {
            const o = mon?.lastIpcObject ?? mon;
            if (o?.width === undefined || o?.height === undefined)
                continue;
            const scale = (o.scale && o.scale > 0) ? o.scale : 1;
            const lw = o.width / scale;
            const lh = o.height / scale;
            if (cx >= o.x && cx < o.x + lw && cy >= o.y && cy < o.y + lh)
                return mon.id;
        }
        return -1;
    }

    function applyCursorPos(text) {
        if (!root.open)
            return;
        const m = `${text ?? ""}`.match(/(-?\d+)\s*,\s*(-?\d+)/);
        if (!m)
            return;
        const id = root.monitorIdAt(parseInt(m[1], 10), parseInt(m[2], 10));
        if (id >= 0)
            root.displayMonitorId = id;
    }

    // One-shot cursor position query, fired on every open (see openSwitcher).
    Process {
        id: cursorPosProc
        command: ["hyprctl", "cursorpos"]
        stdout: StdioCollector {
            onStreamFinished: root.applyCursorPos(this.text)
        }
    }

    function next() {
        const n = root.entries.length;
        if (n === 0)
            return;
        root.selectedIndex = (root.selectedIndex + 1) % n;
    }

    function prev() {
        const n = root.entries.length;
        if (n === 0)
            return;
        root.selectedIndex = (root.selectedIndex - 1 + n) % n;
    }

    function confirm() {
        // Only act while open, so an optional `bindr = SUPER, Super_L`
        // safety net (see README) can't refocus an app on every Super
        // release when the switcher isn't showing.
        if (!root.open)
            return;
        const entry = root.selectedEntry;
        root.open = false;
        if (!entry || !entry.focusAddress)
            return;
        if (Hyprland.usingLua) {
            Hyprland.dispatch(`hl.dsp.focus({ window = 'address:${entry.focusAddress}' })`);
        } else {
            Hyprland.dispatch(`focuswindow address:${entry.focusAddress}`);
        }
    }

    function closeWindowAt(index) {
        const entry = root.entries[index];
        if (!entry || !entry.focusAddress)
            return;
        if (Hyprland.usingLua) {
            Hyprland.dispatch(`hl.dsp.window.close('address:${entry.focusAddress}')`);
        } else {
            Hyprland.dispatch(`closewindow address:${entry.focusAddress}`);
        }
    }

    function cancel() {
        root.open = false;
    }
}
