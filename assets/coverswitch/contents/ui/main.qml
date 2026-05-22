/*
 SPDX-FileCopyrightText: 2021 Ismael Asensio <isma.af@gmail.com>
 SPDX-FileCopyrightText: 2026 cachyos-setup (GNOME-styled Plasma 6 cover switch with panel-visible workaround)

 SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Window

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3
import org.kde.kwin as KWin

KWin.TabBoxSwitcher {
    id: tabBox
    currentIndex: thumbnailView ? thumbnailView.currentIndex : -1
    property bool fadeInStarted: false
    property int panelReserve: __PANEL_RESERVE__
    property int sweepDirection: 1
    property bool correctingCurrentIndex: false

    readonly property int rawScreenWidth: Math.max(
        Screen.width,
        tabBox.screenGeometry.width,
        Screen.desktopAvailableWidth)
    readonly property int rawScreenHeight: Math.max(
        Screen.height,
        tabBox.screenGeometry.height,
        Screen.desktopAvailableHeight)

    function restartFadeIn() {
        fadeInStarted = false
        Qt.callLater(function() { if (tabBox.visible) fadeInStarted = true })
    }

    function clampIndex(idx) {
        if (!thumbnailView || thumbnailView.count <= 0) {
            return -1
        }
        return Math.max(0, Math.min(thumbnailView.count - 1, idx))
    }

    function windowIdForIndex(idx) {
        idx = clampIndex(idx)
        if (idx < 0) {
            return undefined
        }

        if (thumbnailView.currentItem && thumbnailView.currentIndex === idx) {
            return thumbnailView.currentItem.delegateWindowId
        }

        try {
            if (tabBox.model && tabBox.model.get) {
                var entry = tabBox.model.get(idx)
                if (entry) {
                    return entry.windowId || entry.wId || entry.window || entry.internalId
                }
            }
        } catch (e) {
        }

        return undefined
    }

    function rectForCurrentThumbnail() {
        if (!thumbnailView || !thumbnailView.currentItem || !thumbnailView.currentItem.thumbnailItem) {
            return null
        }

        var thumb = thumbnailView.currentItem.thumbnailItem
        var p1 = thumb.mapToItem(morphLayer.parent, 0, 0)
        var p2 = thumb.mapToItem(morphLayer.parent, thumb.width, thumb.height)
        return {
            x: Math.min(p1.x, p2.x),
            y: Math.min(p1.y, p2.y),
            width: Math.max(1, Math.abs(p2.x - p1.x)),
            height: Math.max(1, Math.abs(p2.y - p1.y))
        }
    }

    function setMorphFull(duration, animate) {
        morphLayer.animationDuration = duration
        morphLayer.animationsEnabled = animate
        morphLayer.x = 0
        morphLayer.y = 0
        morphLayer.scale = 1
    }

    function setMorphToRect(rect, duration, animate) {
        if (!rect || window.width <= 0 || window.height <= 0) {
            return
        }

        var targetScale = Math.min(rect.width / window.width, rect.height / window.height)
        morphLayer.animationDuration = duration
        morphLayer.animationsEnabled = animate
        morphLayer.scale = targetScale
        morphLayer.x = rect.x + (rect.width - window.width * targetScale) / 2
        morphLayer.y = rect.y + (rect.height - window.height * targetScale) / 2
    }

    function startOpenMorph() {
        if (!tabBox.visible || !thumbnailView || thumbnailView.count <= 0) {
            return
        }

        var idx = clampIndex(thumbnailView.currentIndex >= 0 ? thumbnailView.currentIndex : tabBox.currentIndex)
        var wId = windowIdForIndex(idx)
        if (wId === undefined || wId === null) {
            wId = windowIdForIndex(0)
        }
        if (wId === undefined || wId === null) {
            return
        }

        morphHideTimer.stop()
        morphLayer.windowId = wId
        morphLayer.active = true
        morphLayer.opacity = 1
        setMorphFull(0, false)

        Qt.callLater(function() {
            if (!tabBox.visible || !morphLayer.active) {
                return
            }
            var rect = rectForCurrentThumbnail()
            if (!rect) {
                morphLayer.active = false
                return
            }
            setMorphToRect(rect, 220, true)
            morphHideTimer.restart()
        })
    }

    function startCloseMorph() {
        if (!thumbnailView || thumbnailView.count <= 0) {
            return
        }

        var wId = windowIdForIndex(thumbnailView.currentIndex)
        var rect = rectForCurrentThumbnail()
        if (wId === undefined || wId === null || !rect) {
            return
        }

        morphHideTimer.stop()
        morphLayer.windowId = wId
        morphLayer.active = true
        morphLayer.opacity = 1
        setMorphToRect(rect, 0, false)

        Qt.callLater(function() {
            if (!morphLayer.active) {
                return
            }
            setMorphFull(180, true)
            morphLayer.opacity = 0
        })
    }

    function syncMovementDirection(nextIndex) {
        if (!thumbnailView || nextIndex === thumbnailView.currentIndex) {
            return
        }
        thumbnailView.movementDirection = nextIndex > thumbnailView.currentIndex ? PathView.Positive : PathView.Negative
    }

    function setCurrentIndexNoWrap(nextIndex) {
        nextIndex = clampIndex(nextIndex)
        if (nextIndex < 0 || nextIndex === thumbnailView.currentIndex) {
            return
        }

        syncMovementDirection(nextIndex)
        correctingCurrentIndex = true
        thumbnailView.currentIndex = nextIndex
        tabBox.currentIndex = nextIndex
        correctingCurrentIndex = false
    }

    function advanceSweep() {
        if (!thumbnailView || thumbnailView.count <= 1) {
            return
        }

        var current = clampIndex(thumbnailView.currentIndex)
        if (current <= 0) {
            sweepDirection = 1
        } else if (current >= thumbnailView.count - 1) {
            sweepDirection = -1
        }

        var next = current + sweepDirection
        if (next >= thumbnailView.count) {
            sweepDirection = -1
            next = thumbnailView.count - 2
        } else if (next < 0) {
            sweepDirection = 1
            next = 1
        }

        setCurrentIndexNoWrap(next)
    }

    function refreshPanelReserve() {
        try {
            var output = KWin.Workspace.screenAt(Qt.point(
                tabBox.screenGeometry.x + tabBox.screenGeometry.width / 2,
                tabBox.screenGeometry.y + tabBox.screenGeometry.height / 2))
            var desktop = KWin.Workspace.currentDesktop
            var areaOption = KWin.MaximizeArea !== undefined ? KWin.MaximizeArea : 2
            var available = KWin.Workspace.clientArea(areaOption, output, desktop)
            var bottomReserve = (tabBox.screenGeometry.y + rawScreenHeight) - (available.y + available.height)

            if (bottomReserve >= 0 && bottomReserve < rawScreenHeight) {
                panelReserve = Math.round(bottomReserve)
            }
        } catch (e) {
            panelReserve = __PANEL_RESERVE__
        }
    }

    Window {
        id: window
        x: tabBox.screenGeometry.x
        y: tabBox.screenGeometry.y
        width: tabBox.rawScreenWidth
        height: Math.max(1, tabBox.rawScreenHeight - tabBox.panelReserve)
        flags: Qt.BypassWindowManagerHint | Qt.FramelessWindowHint
        visibility: Window.Windowed
        visible: tabBox.visible
        color: "transparent"

        Component.onCompleted: {
            tabBox.refreshPanelReserve()
            if (tabBox.visible) {
                tabBox.restartFadeIn()
                Qt.callLater(function() { tabBox.startOpenMorph() })
            }
        }

        KWin.DesktopBackground {
            id: desktopBackground
            width: Screen.width; height: Screen.height
            activity: KWin.Workspace.currentActivity
            output: KWin.Workspace.screenAt(Qt.point(
                tabBox.screenGeometry.x + tabBox.screenGeometry.width / 2,
                tabBox.screenGeometry.y + tabBox.screenGeometry.height / 2))
            z: -10

            Binding {
                target: desktopBackground
                property: "desktop"
                value: KWin.Workspace.currentDesktop
                when: KWin.Workspace.currentDesktop !== undefined
                      && KWin.Workspace.currentDesktop !== null
            }
        }

        Item {
            id: fader
            anchors.fill: parent
            opacity: tabBox.visible && tabBox.fadeInStarted ? 1 : 0
            Accessible.name: thumbnailView.currentItem && thumbnailView.currentItem.caption ? String(thumbnailView.currentItem.caption) : ""

            Behavior on opacity {
                NumberAnimation {
                    duration: 160
                    easing.type: Easing.OutCubic
                    onRunningChanged: if (!running && fader.opacity === 0 && !tabBox.visible) window.visible = false
                }
            }

            Rectangle { width: Screen.width; height: Screen.height; color: "black"; opacity: 0.12; z: -9 }

            PathView {
                id: thumbnailView
                readonly property real previewRatio: 0.45
                readonly property int boxWidth: Math.round(width * previewRatio)
                readonly property int boxHeight: Math.round(height * previewRatio)
                readonly property real centerY: height * 0.48

                focus: true
                anchors.fill: parent
                model: tabBox.model
                preferredHighlightBegin: 0.5
                preferredHighlightEnd: 0.5
                highlightRangeMode: PathView.StrictlyEnforceRange
                highlightMoveDuration: 220
                pathItemCount: 7

                path: Path {
                    startX: thumbnailView.width * 0.40
                    startY: thumbnailView.centerY
                    PathAttribute { name: "progress"; value: 0.55 }
                    PathAttribute { name: "scale"; value: 0.50 }
                    PathAttribute { name: "rotation"; value: 60 }
                    PathPercent { value: 0 }
                    PathLine { x: thumbnailView.width * 0.43; y: thumbnailView.centerY }
                    PathAttribute { name: "progress"; value: 0.68 }
                    PathAttribute { name: "scale"; value: 0.65 }
                    PathAttribute { name: "rotation"; value: 45 }
                    PathPercent { value: 0.23 }
                    PathLine { x: thumbnailView.width * 0.46; y: thumbnailView.centerY }
                    PathAttribute { name: "progress"; value: 0.84 }
                    PathAttribute { name: "scale"; value: 0.85 }
                    PathAttribute { name: "rotation"; value: 30 }
                    PathPercent { value: 0.40 }
                    PathLine { x: thumbnailView.width * 0.50; y: thumbnailView.centerY }
                    PathAttribute { name: "progress"; value: 1.0 }
                    PathAttribute { name: "scale"; value: 1.0 }
                    PathAttribute { name: "rotation"; value: 0 }
                    PathPercent { value: 0.50 }
                    PathLine { x: thumbnailView.width * 0.54; y: thumbnailView.centerY }
                    PathAttribute { name: "progress"; value: 0.84 }
                    PathAttribute { name: "scale"; value: 0.85 }
                    PathAttribute { name: "rotation"; value: -30 }
                    PathPercent { value: 0.60 }
                    PathLine { x: thumbnailView.width * 0.57; y: thumbnailView.centerY }
                    PathAttribute { name: "progress"; value: 0.68 }
                    PathAttribute { name: "scale"; value: 0.65 }
                    PathAttribute { name: "rotation"; value: -45 }
                    PathPercent { value: 0.77 }
                    PathLine { x: thumbnailView.width * 0.60; y: thumbnailView.centerY }
                    PathAttribute { name: "progress"; value: 0.55 }
                    PathAttribute { name: "scale"; value: 0.50 }
                    PathAttribute { name: "rotation"; value: -60 }
                    PathPercent { value: 1 }
                }

                delegate: Item {
                    id: delegateItem
                    readonly property real rotationAngle: PathView.rotation || 0
                    readonly property string caption: model.caption ? String(model.caption) : ""
                    readonly property var delegateWindowId: windowId
                    property alias thumbnailItem: thumbnail
                    property real openScale: tabBox.fadeInStarted ? 1 : 0.8
                    readonly property real thumbnailFitScale: Math.min(
                        width / Math.max(1, thumbnail.implicitWidth),
                        height / Math.max(1, thumbnail.implicitHeight))

                    width: thumbnailView.boxWidth
                    height: thumbnailView.boxHeight
                    scale: PathView.onPath ? openScale * PathView.scale : 0
                    z: PathView.onPath ? Math.round((PathView.progress || 0) * 100) : -1
                    opacity: PathView.onPath ? 1 : 0
                    Accessible.name: model.caption ? String(model.caption) : ""

                    Behavior on openScale {
                        NumberAnimation {
                            duration: 160
                            easing.type: Easing.OutBack
                        }
                    }

                    KWin.WindowThumbnail {
                        id: thumbnail
                        wId: windowId; anchors.centerIn: parent
                        width: Math.round(Math.max(1, implicitWidth) * delegateItem.thumbnailFitScale)
                        height: Math.round(Math.max(1, implicitHeight) * delegateItem.thumbnailFitScale)
                        smooth: false
                    }

                    transform: Rotation {
                        origin {
                            x: delegateItem.rotationAngle > 0 ? 0
                               : (delegateItem.rotationAngle < 0 ? delegateItem.width : delegateItem.width / 2)
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
                            tabBox.setCurrentIndexNoWrap(index)
                        }
                    }
                }

                onMovementStarted: movementDirection = PathView.Shortest
                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Tab
                            || event.key === Qt.Key_Backtab
                            || event.key === Qt.Key_Left
                            || event.key === Qt.Key_Right
                            || event.key === Qt.Key_Up
                            || event.key === Qt.Key_Down) {
                        tabBox.advanceSweep()
                        event.accepted = true
                    }
                }
            }

            Rectangle {
                id: titlePill
                visible: thumbnailView.count > 0 && titleLabel.text.length > 0
                anchors.horizontalCenter: parent.horizontalCenter
                y: thumbnailView.centerY + thumbnailView.boxHeight * 0.5 + Kirigami.Units.gridUnit * 1.2
                width: Math.min(titleLabel.implicitWidth + Kirigami.Units.gridUnit * 1.5, parent.width * 0.72)
                height: titleLabel.implicitHeight + Kirigami.Units.smallSpacing * 2
                radius: height / 2
                color: Qt.rgba(0, 0, 0, 0.45)

                PC3.Label {
                    id: titleLabel
                    anchors.centerIn: parent
                    width: parent.width - Kirigami.Units.gridUnit * 1.5
                    horizontalAlignment: Text.AlignHCenter
                    font.bold: true; font.pointSize: Math.round(Kirigami.Theme.defaultFont.pointSize * 1.15)
                    color: "white"
                    text: thumbnailView.currentItem && thumbnailView.currentItem.caption ? String(thumbnailView.currentItem.caption) : ""
                    textFormat: Text.PlainText
                    maximumLineCount: 1; elide: Text.ElideMiddle
                }
            }

            Kirigami.PlaceholderMessage {
                anchors.centerIn: parent
                width: parent.width - Kirigami.Units.largeSpacing * 2
                icon.source: "edit-none"
                text: i18ndc("kwin", "@info:placeholder no entries in the task switcher", "No open windows")
                visible: thumbnailView.count === 0
            }
        }

        Item {
            id: morphLayer
            property var windowId: undefined
            property bool active: false
            property bool animationsEnabled: false
            property int animationDuration: 220

            width: parent.width
            height: parent.height
            transformOrigin: Item.TopLeft
            visible: active
            z: 50

            KWin.WindowThumbnail {
                anchors.fill: parent
                wId: morphLayer.windowId
                smooth: false
            }

            Behavior on x {
                enabled: morphLayer.animationsEnabled
                NumberAnimation { duration: morphLayer.animationDuration; easing.type: Easing.OutCubic }
            }
            Behavior on y {
                enabled: morphLayer.animationsEnabled
                NumberAnimation { duration: morphLayer.animationDuration; easing.type: Easing.OutCubic }
            }
            Behavior on scale {
                enabled: morphLayer.animationsEnabled
                NumberAnimation { duration: morphLayer.animationDuration; easing.type: Easing.OutCubic }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: 180
                    easing.type: Easing.OutCubic
                    onRunningChanged: if (!running && morphLayer.opacity === 0) morphLayer.active = false
                }
            }
        }

        Timer {
            id: morphHideTimer
            interval: 240
            repeat: false
            onTriggered: {
                if (tabBox.visible) {
                    morphLayer.opacity = 0
                }
            }
        }
    }

    onCurrentIndexChanged: {
        if (correctingCurrentIndex || currentIndex === thumbnailView.currentIndex) {
            return
        }

        if (thumbnailView.count <= 1) {
            thumbnailView.currentIndex = clampIndex(currentIndex)
            return
        }

        advanceSweep()
    }

    onVisibleChanged: {
        if (visible) {
            refreshPanelReserve()
            sweepDirection = 1
            window.visible = true
            restartFadeIn()
            Qt.callLater(function() { tabBox.startOpenMorph() })
        } else {
            startCloseMorph()
            fadeInStarted = false
            Qt.callLater(function() {
                correctingCurrentIndex = true
                thumbnailView.currentIndex = 0
                tabBox.currentIndex = 0
                correctingCurrentIndex = false
            })
        }
    }
}
