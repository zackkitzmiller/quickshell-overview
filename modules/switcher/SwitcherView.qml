import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../common"
import "../../common/functions"
import "../../common/widgets"
import "../../services"

// The switcher panel: a horizontal row of app tiles with a title label.
Item {
    id: root

    property real padding: Config.options.switcher.backgroundPadding
    property bool showTitle: Config.options.switcher.showTitle
    property real panelOpacity: Math.max(0, Math.min(1, Config.options.switcher.effects.panelOpacity))

    // Neobrutalist "chunky shadow": a solid, unblurred copy of the panel
    // offset down-right in the theme's dark foreground — the exact technique
    // the Omarchy top bar uses for its pills, scaled up for a large panel.
    property int shadowOffset: 10
    // Chunkier-than-Material corners to sit closer to the bar's pill feel.
    property int panelRadius: 14

    // Reserve room on every side for the offset shadow so it never clips.
    implicitWidth: background.implicitWidth + root.shadowOffset * 2 + 4
    implicitHeight: background.implicitHeight + root.shadowOffset * 2 + 4

    // Hard neobrutalist drop shadow: a solid, unblurred copy of the panel
    // offset down-right in the theme's dark foreground. Declared BEFORE the
    // panel so it paints behind it (earlier siblings render first), and sized
    // to track the panel's geometry.
    Rectangle {
        id: panelShadow
        x: background.x + root.shadowOffset
        y: background.y + root.shadowOffset
        width: background.width
        height: background.height
        radius: background.radius
        color: OmarchyTheme.foreground
    }

    Rectangle {
        id: background
        anchors.centerIn: parent
        radius: root.panelRadius
        implicitWidth: contentLayout.implicitWidth + root.padding * 2
        implicitHeight: contentLayout.implicitHeight + root.padding * 2
        color: ColorUtils.applyAlpha(OmarchyTheme.background, root.panelOpacity)
        border.width: 2
        border.color: OmarchyTheme.foreground

        ColumnLayout {
            id: contentLayout
            anchors.centerIn: parent
            spacing: Math.max(6, root.padding * 0.5)

            RowLayout {
                id: tileRow
                Layout.alignment: Qt.AlignHCenter
                spacing: Config.options.switcher.tileSpacing

                Repeater {
                    model: Switcher.entries
                    delegate: SwitcherTile {
                        selected: index === Switcher.selectedIndex
                    }
                }
            }

            StyledText {
                id: titleLabel
                visible: root.showTitle && (Switcher.entries.length > 0)
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: tileRow.implicitWidth
                text: Switcher.selectedEntry?.title ?? ""
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: Appearance.font.pixelSize.normal
                font.family: Appearance.font.family.main
                color: OmarchyTheme.foreground
            }

            StyledText {
                visible: Switcher.entries.length === 0
                Layout.alignment: Qt.AlignHCenter
                text: "No open windows"
                font.pixelSize: Appearance.font.pixelSize.normal
                font.family: Appearance.font.family.main
                color: ColorUtils.transparentize(OmarchyTheme.foreground, 0.4)
            }
        }
    }
}
