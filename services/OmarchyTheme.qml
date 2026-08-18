pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Live Omarchy theme palette — the exact colors the top bar uses.
 *
 * Reads ~/.local/state/omarchy/current/theme/colors.toml (the same source
 * the Omarchy shell's Color singleton reads) so the switcher tracks the
 * active theme instead of carrying its own Material-You palette. Swapping
 * themes (omarchy-theme-set) retargets the `current` symlink; the FileView
 * watcher re-reads and every binding below updates live.
 *
 * Only the four roles the neobrutalist look needs are exposed:
 *   background  light pill/panel fill      (colors.toml `background`)
 *   foreground  dark border / text / shadow (colors.toml `foreground`)
 *   accent      selection accent            (colors.toml `accent`)
 *   active      urgent / red                (colors.toml `color1`)
 */
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string colorsPath: home + "/.local/state/omarchy/current/theme/colors.toml"

    // Harbor/Quattro defaults; overwritten the instant colors.toml loads.
    property color background: "#dfe4c4"
    property color foreground: "#1c2d28"
    property color accent: "#5e81ac"
    property color active: "#b14752"

    function applyToml(text) {
        const map = ({});
        const lines = `${text ?? ""}`.split("\n");
        for (const line of lines) {
            const m = line.match(/^\s*([A-Za-z0-9_]+)\s*=\s*"?(#[0-9A-Fa-f]{3,8})"?/);
            if (m)
                map[m[1].toLowerCase()] = m[2];
        }
        if (map.background)
            root.background = map.background;
        if (map.foreground)
            root.foreground = map.foreground;
        if (map.accent)
            root.accent = map.accent;
        if (map.color1)
            root.active = map.color1;
    }

    FileView {
        id: colorsFile
        path: root.colorsPath
        watchChanges: true
        printErrors: false
        onLoaded: root.applyToml(colorsFile.text())
        onFileChanged: colorsFile.reload()
    }
}
