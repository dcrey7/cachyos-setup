/*
 SPDX-FileCopyrightText: 2021 Ismael Asensio <isma.af@gmail.com>
 SPDX-FileCopyrightText: 2026 cachyos-setup (Plasma 6 port + GNOME coverflow tuning)

 SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import QtQuick.Window

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3

import org.kde.kwin as KWin


KWin.TabBoxSwitcher {
    id: tabBox
    currentIndex: thumbnailView ? thumbnailView.currentIndex : -1
    readonly property int panelReserve: 40
    property bool fadeInStarted: false

    function restartFadeIn() {
        fadeInStarted = false
        Qt.callLater(function() {
            if (tabBox.visible) {
                fadeInStarted = true
            }
        })
    }

    Window {
        id: window

        readonly property int rawScreenWidth: Math.max(Screen.width, tabBox.screenGeometry.width, Screen.desktopAvailableWidth)
        readonly property int rawScreenHeight: Math.max(Screen.height, tabBox.screenGeometry.height, Screen.desktopAvailableHeight)

        x: tabBox.screenGeometry.x
        y: tabBox.screenGeometry.y
        width: rawScreenWidth
        height: Math.max(1, rawScreenHeight - tabBox.panelReserve)
        flags: Qt.BypassWindowManagerHint | Qt.FramelessWindowHint
        visibility: Window.Windowed
        visible: true
        color: "transparent"

        Component.onCompleted: {
            tabBox.restartFadeIn()
            console.log("coverswitch_g21 screenGeometry:",
                        tabBox.screenGeometry.x,
                        tabBox.screenGeometry.y,
                        tabBox.screenGeometry.width,
                        tabBox.screenGeometry.height)
            console.log("coverswitch_g21 Screen:",
                        "width", Screen.width,
                        "height", Screen.height,
                        "virtualX", Screen.virtualX,
                        "virtualY", Screen.virtualY,
                        "desktopAvailableWidth", Screen.desktopAvailableWidth,
                        "desktopAvailableHeight", Screen.desktopAvailableHeight)
            console.log("coverswitch_g21 windowGeometry:",
                        window.x,
                        window.y,
                        window.width,
                        window.height,
                        "panelReserve", tabBox.panelReserve)
        }

        KWin.DesktopBackground {
            id: desktopBackground

            x: 0
            y: 0
            width: Screen.width
            height: Screen.height
            activity: KWin.Workspace.currentActivity
            outputName: window.screen.name
            z: -10

            Binding {
                target: desktopBackground
                property: "desktop"
                value: KWin.Workspace.currentVirtualDesktop
                when: KWin.Workspace.currentVirtualDesktop !== undefined
                      && KWin.Workspace.currentVirtualDesktop !== null
            }
        }

        Item {
            id: fader
            anchors.fill: parent
            opacity: tabBox.visible && tabBox.fadeInStarted ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 160
                    easing.type: Easing.OutCubic
                }
            }

            Rectangle {
                x: 0
                y: 0
                width: Screen.width
                height: Screen.height
                color: "black"
                opacity: 0.12
                z: -9
            }

            Item {
                id: scene
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                }
                height: parent.height
                Accessible.name: thumbnailView.currentItem ? thumbnailView.currentItem.caption : ""

                PathView {
                    id: thumbnailView

                    readonly property int visibleCount: Math.min(count, pathItemCount)
                    readonly property real previewRatio: 0.45
                    readonly property int boxWidth: Math.round(width * previewRatio)
                    readonly property int boxHeight: Math.round(height * previewRatio)
                    readonly property real centerY: height * 0.48
                    readonly property real leftOuterX: width * 0.40
                    readonly property real leftMiddleX: width * 0.43
                    readonly property real leftInnerX: width * 0.46
                    readonly property real centerX: width * 0.5
                    readonly property real rightInnerX: width * 0.54
                    readonly property real rightMiddleX: width * 0.57
                    readonly property real rightOuterX: width * 0.60

                    focus: true
                    anchors.fill: parent

                    preferredHighlightBegin: 0.5
                    preferredHighlightEnd: 0.5
                    highlightRangeMode: PathView.StrictlyEnforceRange
                    highlightMoveDuration: 220
                    pathItemCount: 7

                path: Path {
                    startX: thumbnailView.leftOuterX
                    startY: thumbnailView.centerY
                    PathAttribute { name: "progress"; value: 0.55 }
                    PathAttribute { name: "scale"; value: 0.50 }
                    PathAttribute { name: "rotation"; value: 60 }
                    PathPercent { value: 0 }

                    PathLine { x: thumbnailView.leftMiddleX; y: thumbnailView.centerY }
                    PathAttribute { name: "progress"; value: 0.68 }
                    PathAttribute { name: "scale"; value: 0.65 }
                    PathAttribute { name: "rotation"; value: 45 }
                    PathPercent { value: 0.23 }

                    PathLine { x: thumbnailView.leftInnerX; y: thumbnailView.centerY }
                    PathAttribute { name: "progress"; value: 0.84 }
                    PathAttribute { name: "scale"; value: 0.85 }
                    PathAttribute { name: "rotation"; value: 30 }
                    PathPercent { value: 0.40 }

                    PathLine { x: thumbnailView.centerX; y: thumbnailView.centerY }
                    PathAttribute { name: "progress"; value: 1.0 }
                    PathAttribute { name: "scale"; value: 1.0 }
                    PathAttribute { name: "rotation"; value: 0 }
                    PathPercent { value: 0.50 }

                    PathLine { x: thumbnailView.rightInnerX; y: thumbnailView.centerY }
                    PathAttribute { name: "progress"; value: 0.84 }
                    PathAttribute { name: "scale"; value: 0.85 }
                    PathAttribute { name: "rotation"; value: -30 }
                    PathPercent { value: 0.60 }

                    PathLine { x: thumbnailView.rightMiddleX; y: thumbnailView.centerY }
                    PathAttribute { name: "progress"; value: 0.68 }
                    PathAttribute { name: "scale"; value: 0.65 }
                    PathAttribute { name: "rotation"; value: -45 }
                    PathPercent { value: 0.77 }

                    PathLine { x: thumbnailView.rightOuterX; y: thumbnailView.centerY }
                    PathAttribute { name: "progress"; value: 0.55 }
                    PathAttribute { name: "scale"; value: 0.50 }
                    PathAttribute { name: "rotation"; value: -60 }
                    PathPercent { value: 1 }
                }

                model: tabBox.model

                delegate: Item {
                    id: delegateItem

                    readonly property string caption: model.caption
                    readonly property real rotationAngle: PathView.rotation || 0
                    readonly property real thumbnailFitScale: Math.min(
                        width / Math.max(1, thumbnail.implicitWidth),
                        height / Math.max(1, thumbnail.implicitHeight))

                    width: thumbnailView.boxWidth
                    height: thumbnailView.boxHeight
                    scale: PathView.onPath ? PathView.scale : 0
                    z: PathView.onPath ? Math.round((PathView.progress || 0) * 100) : -1
                    opacity: PathView.onPath ? 1 : 0
                    Accessible.name: caption

                    KWin.WindowThumbnail {
                        id: thumbnail
                        wId: windowId
                        anchors.centerIn: parent
                        width: Math.round(Math.max(1, implicitWidth) * delegateItem.thumbnailFitScale)
                        height: Math.round(Math.max(1, implicitHeight) * delegateItem.thumbnailFitScale)
                        smooth: true
                    }

                    transform: Rotation {
                        origin {
                            x: delegateItem.rotationAngle > 0
                                ? 0
                                : (delegateItem.rotationAngle < 0
                                    ? delegateItem.width
                                    : delegateItem.width / 2)
                            y: delegateItem.height / 2
                        }
                        axis { x: 0; y: 1; z: 0 }
                        angle: delegateItem.rotationAngle
                    }

                    TapHandler {
                        grabPermissions: PointerHandler.TakeOverForbidden
                        gesturePolicy: TapHandler.WithinBounds
                        onSingleTapped: {
                            if (index === thumbnailView.currentIndex) {
                                thumbnailView.model.activate(index)
                                return
                            }
                            thumbnailView.movementDirection =
                                (delegateItem.rotationAngle < 0)
                                    ? PathView.Positive
                                    : PathView.Negative
                            thumbnailView.currentIndex = index
                        }
                    }
                }

                onMovementStarted: {
                    movementDirection = PathView.Shortest
                }

                Keys.onUpPressed: decrementCurrentIndex()
                Keys.onLeftPressed: decrementCurrentIndex()
                Keys.onDownPressed: incrementCurrentIndex()
                Keys.onRightPressed: incrementCurrentIndex()
            }

            PC3.Label {
                id: infoBar

                visible: thumbnailView.count > 0
                anchors.horizontalCenter: parent.horizontalCenter
                y: thumbnailView.centerY + thumbnailView.boxHeight * 0.5 + Kirigami.Units.gridUnit
                width: Math.min(implicitWidth, parent.width * 0.72)
                horizontalAlignment: Text.AlignHCenter
                font.bold: true
                font.pointSize: Math.round(Kirigami.Theme.defaultFont.pointSize * 1.15)
                color: "white"
                text: thumbnailView.currentItem ? thumbnailView.currentItem.caption : ""
                textFormat: Text.PlainText
                maximumLineCount: 1
                elide: Text.ElideMiddle
            }

            Kirigami.PlaceholderMessage {
                anchors.centerIn: parent
                width: parent.width - Kirigami.Units.largeSpacing * 2
                icon.source: "edit-none"
                text: i18ndc("kwin", "@info:placeholder no entries in the task switcher", "No open windows")
                visible: thumbnailView.count === 0
            }
        }
        }

        onSceneGraphError: () => {
        }
    }

    onCurrentIndexChanged: {
        if (currentIndex === thumbnailView.currentIndex) {
            return
        }
        if (thumbnailView.count === 2 ||
            (currentIndex === 0 && thumbnailView.currentIndex === thumbnailView.count - 1)) {
            thumbnailView.movementDirection = PathView.Positive
        } else if (currentIndex === (thumbnailView.count - 1) && thumbnailView.currentIndex === 0) {
            thumbnailView.movementDirection = PathView.Negative
        } else {
            thumbnailView.movementDirection =
                (currentIndex > thumbnailView.currentIndex)
                    ? PathView.Positive
                    : PathView.Negative
        }
        thumbnailView.currentIndex = tabBox.currentIndex
    }

    onVisibleChanged: {
        if (visible) {
            window.visible = true
            restartFadeIn()
        } else {
            fadeInStarted = false
            thumbnailView.currentIndex = 0
            window.visible = false
        }
    }
}
