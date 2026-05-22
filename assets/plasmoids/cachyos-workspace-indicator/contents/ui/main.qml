import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PC3
import org.kde.plasma.plasma5support as P5Support
import org.kde.taskmanager as TaskManager
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    readonly property int desktopCount: vdInfo.numberOfDesktops
    readonly property var desktopIds: vdInfo.desktopIds
    readonly property var currentDesktop: vdInfo.currentDesktop

    function desktopIdAt(index) {
        return desktopIds && desktopIds.length > index ? desktopIds[index] : ""
    }

    function switchDesktop(index) {
        const desktopId = desktopIdAt(index)
        if (desktopId && typeof vdInfo.requestActivate === "function") {
            vdInfo.requestActivate(desktopId)
            return
        }

        executable.connectSource("qdbus6 org.kde.KWin /KWin org.kde.KWin.setCurrentDesktop " + (index + 1))
    }

    preferredRepresentation: fullRepresentation

    TaskManager.VirtualDesktopInfo {
        id: vdInfo
    }

    P5Support.DataSource {
        id: executable
        engine: "executable"

        onNewData: function(sourceName) {
            disconnectSource(sourceName)
        }
    }

    fullRepresentation: RowLayout {
        spacing: Kirigami.Units.smallSpacing

        Repeater {
            model: root.desktopCount

            delegate: PC3.AbstractButton {
                id: pill

                Layout.preferredWidth: Kirigami.Units.gridUnit * 1.6
                Layout.preferredHeight: Kirigami.Units.gridUnit * 1.6
                Layout.alignment: Qt.AlignVCenter

                property string desktopId: root.desktopIdAt(index)
                property bool isCurrent: desktopId !== "" && desktopId === root.currentDesktop

                onClicked: root.switchDesktop(index)

                background: Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: pill.isCurrent
                        ? Kirigami.Theme.highlightColor
                        : (pill.hovered ? Qt.rgba(Kirigami.Theme.textColor.r,
                                                  Kirigami.Theme.textColor.g,
                                                  Kirigami.Theme.textColor.b,
                                                  0.15)
                                        : "transparent")
                    border.width: pill.isCurrent ? 0 : 1
                    border.color: Qt.rgba(Kirigami.Theme.textColor.r,
                                          Kirigami.Theme.textColor.g,
                                          Kirigami.Theme.textColor.b,
                                          0.4)

                    Behavior on color {
                        ColorAnimation {
                            duration: 160
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                contentItem: PC3.Label {
                    text: (index + 1).toString()
                    color: pill.isCurrent
                           ? Kirigami.Theme.highlightedTextColor
                           : Kirigami.Theme.textColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize
                    font.bold: pill.isCurrent
                }
            }
        }
    }
}
