import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../common"
import "../../common/functions"
import "../../services"

// One app entry in the switcher row. Renders as an icon, a live window
// thumbnail, or a hybrid of both depending on Config.options.switcher.style.
Item {
    id: root

    // Injected by the Repeater in SwitcherView.
    required property var modelData
    required property int index
    readonly property var entry: modelData
    property bool selected: false

    property real tileSize: Config.options.switcher.tileSize
    property string style: Config.options.switcher.style
    property bool previewsEnabled: Config.options.switcher.previewsEnabled
    property bool livePreview: previewsEnabled && `${Config.options.switcher.previewMode ?? "live"}`.trim().toLowerCase() === "live"
    property bool wantsPreview: previewsEnabled && (style === "thumbnails" || style === "hybrid")

    readonly property real iconSize: style === "hybrid" ? tileSize * 0.42 : tileSize * 0.66

    // Selection color, cycled per position through the configured palette
    // (orange, green, blue, black by default) — the bar's multicolor pill look.
    readonly property var highlightColors: Config.options.switcher.highlightColors
    readonly property color highlightColor: (highlightColors && highlightColors.length > 0)
        ? highlightColors[root.index % highlightColors.length]
        : OmarchyTheme.foreground

    // Offset of the selected tile's hard drop shadow. Kept below the row's
    // tileSpacing so a selected tile's shadow never touches its neighbor.
    property int tileShadowOffset: 6

    implicitWidth: tileSize
    implicitHeight: tileSize

    // Hard neobrutalist drop shadow for the SELECTED tile, in its highlight
    // color — the same chunky treatment the panel gets, so selection reads as
    // solid and offset rather than a thin outline. Declared first (paints
    // behind the tile); spills into the row gap / panel padding.
    Rectangle {
        id: tileShadow
        visible: root.selected
        x: root.tileShadowOffset
        y: root.tileShadowOffset
        width: parent.width
        height: parent.height
        radius: 10
        color: root.highlightColor
    }

    // Tile background + selection highlight (neobrutalist: highlight-washed fill
    // under a chunky highlight-colored border when selected; a faint inset wash
    // otherwise, so tiles read against the cream panel).
    Rectangle {
        id: background
        anchors.fill: parent
        radius: 10
        color: root.selected
            ? ColorUtils.applyAlpha(root.highlightColor, 0.20)
            : ColorUtils.applyAlpha(OmarchyTheme.foreground, 0.06)
        border.width: 2
        border.color: root.selected ? root.highlightColor : "transparent"

        Behavior on color {
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }
        Behavior on border.color {
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }
    }

    // Live window preview (thumbnails / hybrid styles).
    ScreencopyView {
        id: preview
        visible: root.wantsPreview && root.entry?.toplevel
        anchors.fill: parent
        anchors.margins: 6
        captureSource: (Switcher.open && root.wantsPreview && root.entry?.toplevel) ? root.entry.toplevel : null
        live: root.livePreview
        opacity: root.style === "hybrid" ? 0.55 : 1.0
    }

    // App icon.
    Image {
        id: icon
        visible: root.style !== "thumbnails" || !root.entry?.toplevel || !root.previewsEnabled
        anchors.centerIn: parent
        source: root.entry?.iconPath ?? ""
        width: root.iconSize
        height: root.iconSize
        sourceSize: Qt.size(Math.max(1, Math.round(root.iconSize)), Math.max(1, Math.round(root.iconSize)))
        smooth: true
    }

    // Small window-count badge when an app has multiple windows.
    Rectangle {
        visible: (root.entry?.windowCount ?? 1) > 1
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 4
        width: badgeText.implicitWidth + 8
        height: badgeText.implicitHeight + 4
        radius: height / 2
        color: OmarchyTheme.accent
        Text {
            id: badgeText
            anchors.centerIn: parent
            text: `${root.entry?.windowCount ?? 1}`
            color: OmarchyTheme.background
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.family: Appearance.font.family.main
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onEntered: Switcher.selectedIndex = root.index
        onClicked: event => {
            if (event.button === Qt.LeftButton) {
                Switcher.selectedIndex = root.index;
                Switcher.confirm();
            } else if (event.button === Qt.MiddleButton) {
                Switcher.closeWindowAt(root.index);
            }
        }
    }
}
