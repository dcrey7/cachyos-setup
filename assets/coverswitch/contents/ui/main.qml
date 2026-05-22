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
    property bool correctingCurrentIndex: false
    property bool closeMorphPending: false
    property bool centerRectDebugVisible: false
    property var centerRectDebugRect: ({ x: 0, y: 0, width: 0, height: 0 })

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

    function updateMorphAspect(idx) {
        idx = clampIndex(idx)
        if (idx < 0 || !thumbnailView || !thumbnailView.currentItem || thumbnailView.currentIndex !== idx) {
            morphLayer.windowAspect = window.width / Math.max(1, window.height)
            return
        }

        var thumb = thumbnailView.currentItem.thumbnailItem
        if (thumb && thumb.width > 0 && thumb.height > 0) {
            morphLayer.windowAspect = thumb.width / Math.max(1, thumb.height)
        } else {
            morphLayer.windowAspect = window.width / Math.max(1, window.height)
        }
    }

    function rectForCenterCard() {
        if (!thumbnailView || window.width <= 0 || window.height <= 0) {
            return null
        }

        var w = thumbnailView.boxWidth
        var h = thumbnailView.boxHeight
        if (w <= 0 || h <= 0) {
            return null
        }

        return {
            x: Math.round((window.width - w) / 2),
            y: Math.round((window.height - h) / 2),
            width: w,
            height: h
        }
    }

    function logCenterCardRect(reason) {
        var rect = rectForCenterCard()
        if (!rect) {
            console.log("coverswitch center-card-rect", reason, "unavailable",
                        "window", window.width + "x" + window.height)
            return
        }

        console.log("coverswitch center-card-rect", reason,
                    "x", rect.x, "y", rect.y,
                    "width", rect.width, "height", rect.height,
                    "boxWidth", thumbnailView.boxWidth,
                    "boxHeight", thumbnailView.boxHeight,
                    "window", window.width + "x" + window.height)
    }

    function showCenterRectDebug(reason) {
        var rect = rectForCenterCard()
        logCenterCardRect(reason)
        if (!rect) {
            return
        }
        centerRectDebugRect = rect
        centerRectDebugVisible = true
        centerRectDebugTimer.restart()
    }

    function dumpTabBoxApi() {
        console.log("coverswitch tabBox API enumeration begin")
        for (var k in tabBox) {
            try {
                console.log("coverswitch tabBox." + k + " = " + tabBox[k])
            } catch (e) {
                console.log("coverswitch tabBox." + k + " = <error " + e + ">")
            }
        }
        console.log("coverswitch tabBox API enumeration end")
        console.log("coverswitch tabBox model.activate type",
                    tabBox.model && tabBox.model.activate ? typeof tabBox.model.activate : "unavailable")
    }

    function setMorphFull(duration, animate) {
        morphLayer.animationDuration = duration
        morphLayer.animationsEnabled = animate
        morphLayer.x = 0
        morphLayer.y = 0
        morphLayer.width = window.width
        morphLayer.height = window.height
        morphLayer.scale = 1
    }

    function setMorphToRect(rect, duration, animate) {
        if (!rect || window.width <= 0 || window.height <= 0) {
            return
        }

        morphLayer.animationDuration = duration
        morphLayer.animationsEnabled = animate
        morphLayer.x = rect.x
        morphLayer.y = rect.y
        morphLayer.width = rect.width
        morphLayer.height = rect.height
        morphLayer.scale = 1
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

        updateMorphAspect(idx)
        morphHideTimer.stop()
        morphLayer.windowId = wId
        morphLayer.active = true
        morphLayer.opacity = 1
        setMorphFull(0, false)

        Qt.callLater(function() {
            if (!tabBox.visible || !morphLayer.active) {
                return
            }
            var rect = rectForCenterCard()
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
        updateMorphAspect(thumbnailView.currentIndex)
        var rect = rectForCenterCard()
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

    function commitCurrentSelection() {
        if (!thumbnailView || thumbnailView.count <= 0 || !tabBox.model || !tabBox.model.activate) {
            closeMorphPending = false
            return
        }

        var idx = clampIndex(thumbnailView.currentIndex)
        if (idx >= 0) {
            closeMorphPending = false
            tabBox.model.activate(idx)
        }
    }

    function confirmSelection(event) {
        if (event) {
            event.accepted = true
        }
        if (closeMorphPending) {
            return
        }

        closeMorphPending = true
        startCloseMorph()
        closeMorphCompleteTimer.restart()
    }

    function wrappedIndex(idx) {
        if (!thumbnailView || thumbnailView.count <= 0) {
            return -1
        }
        return ((idx % thumbnailView.count) + thumbnailView.count) % thumbnailView.count
    }

    function movementDirectionForTransition(fromIndex, toIndex) {
        if (!thumbnailView || thumbnailView.count <= 1 || fromIndex === toIndex) {
            return PathView.Shortest
        }
        if (fromIndex === thumbnailView.count - 1 && toIndex === 0) {
            return PathView.Negative
        }
        if (fromIndex === 0 && toIndex === thumbnailView.count - 1) {
            return PathView.Positive
        }
        return toIndex > fromIndex ? PathView.Positive : PathView.Negative
    }

    function highlightMoveDistance(fromIndex, toIndex) {
        if (!thumbnailView || thumbnailView.count <= 1 || fromIndex === toIndex) {
            return 0
        }
        if ((fromIndex === thumbnailView.count - 1 && toIndex === 0)
                || (fromIndex === 0 && toIndex === thumbnailView.count - 1)) {
            return thumbnailView.count - 1
        }
        return Math.abs(fromIndex - toIndex)
    }

    function prepareHighlightMove(fromIndex, toIndex) {
        if (!thumbnailView) {
            return
        }

        var distance = highlightMoveDistance(fromIndex, toIndex)
        var duration = Math.max(thumbnailView.baseHighlightMoveDuration, distance * 160)
        thumbnailView.highlightMoveDuration = duration
        highlightDurationResetTimer.interval = duration + 40
        highlightDurationResetTimer.restart()
    }

    function setCurrentIndexWrapped(nextIndex) {
        if (!thumbnailView || thumbnailView.count <= 0) {
            return
        }

        nextIndex = wrappedIndex(nextIndex)
        if (nextIndex < 0 || nextIndex === thumbnailView.currentIndex) {
            return
        }

        var fromIndex = thumbnailView.currentIndex
        thumbnailView.movementDirection = movementDirectionForTransition(fromIndex, nextIndex)
        prepareHighlightMove(fromIndex, nextIndex)
        correctingCurrentIndex = true
        thumbnailView.currentIndex = nextIndex
        tabBox.currentIndex = nextIndex
        correctingCurrentIndex = false
    }

    function stepCurrentIndex(delta) {
        if (!thumbnailView || thumbnailView.count <= 0) {
            return
        }
        setCurrentIndexWrapped(thumbnailView.currentIndex + delta)
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
            tabBox.dumpTabBoxApi()
            if (tabBox.visible) {
                tabBox.restartFadeIn()
                Qt.callLater(function() { tabBox.showCenterRectDebug("Component.onCompleted") })
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
                readonly property int baseHighlightMoveDuration: 220
                highlightMoveDuration: baseHighlightMoveDuration
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
                            tabBox.setCurrentIndexWrapped(index)
                        }
                    }
                }

                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Tab || event.key === Qt.Key_Right || event.key === Qt.Key_Down) {
                        tabBox.stepCurrentIndex(1)
                        event.accepted = true
                    } else if (event.key === Qt.Key_Backtab || event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
                        tabBox.stepCurrentIndex(-1)
                        event.accepted = true
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                        tabBox.confirmSelection(event)
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

        Rectangle {
            id: centerRectDebugOutline
            x: tabBox.centerRectDebugRect.x
            y: tabBox.centerRectDebugRect.y
            width: tabBox.centerRectDebugRect.width
            height: tabBox.centerRectDebugRect.height
            visible: tabBox.centerRectDebugVisible && tabBox.visible
            color: "transparent"
            border.color: "red"
            border.width: 2
            z: 49
        }

        Item {
            id: morphLayer
            property var windowId: undefined
            property real windowAspect: window.width / Math.max(1, window.height)
            property bool active: false
            property bool animationsEnabled: false
            property int animationDuration: 220

            width: window.width
            height: window.height
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
            Behavior on width {
                enabled: morphLayer.animationsEnabled
                NumberAnimation { duration: morphLayer.animationDuration; easing.type: Easing.OutCubic }
            }
            Behavior on height {
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

        Timer {
            id: centerRectDebugTimer
            interval: 1400
            repeat: false
            onTriggered: tabBox.centerRectDebugVisible = false
        }

        Timer {
            id: closeMorphCompleteTimer
            interval: 180
            repeat: false
            onTriggered: tabBox.commitCurrentSelection()
        }

        Timer {
            id: highlightDurationResetTimer
            interval: thumbnailView ? thumbnailView.baseHighlightMoveDuration : 220
            repeat: false
            onTriggered: if (thumbnailView) thumbnailView.highlightMoveDuration = thumbnailView.baseHighlightMoveDuration
        }
    }

    onCurrentIndexChanged: {
        if (correctingCurrentIndex || currentIndex === thumbnailView.currentIndex) {
            return
        }

        if (thumbnailView.count <= 0) {
            return
        }

        var nextIndex = wrappedIndex(currentIndex)
        if (nextIndex < 0 || nextIndex === thumbnailView.currentIndex) {
            return
        }

        var fromIndex = thumbnailView.currentIndex
        thumbnailView.movementDirection = movementDirectionForTransition(fromIndex, nextIndex)
        prepareHighlightMove(fromIndex, nextIndex)
        correctingCurrentIndex = true
        thumbnailView.currentIndex = nextIndex
        tabBox.currentIndex = nextIndex
        correctingCurrentIndex = false
    }

    onVisibleChanged: {
        if (visible) {
            refreshPanelReserve()
            window.visible = true
            restartFadeIn()
            closeMorphPending = false
            Qt.callLater(function() { tabBox.showCenterRectDebug("onVisibleChanged") })
            Qt.callLater(function() { tabBox.startOpenMorph() })
        } else {
            morphHideTimer.stop()
            closeMorphCompleteTimer.stop()
            centerRectDebugTimer.stop()
            morphLayer.active = false
            closeMorphPending = false
            centerRectDebugVisible = false
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
