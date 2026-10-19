/*
    SPDX-FileCopyrightText: 2012-2013 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import plasma.applet.org.kde.plasma.taskmanager as TaskManagerApplet

GridLayout {
    id: taskListRoot

    property bool animating: false

    rowSpacing: 0
    columnSpacing: 0

    property int animationsRunning: 0
    onAnimationsRunningChanged: {
        animating = animationsRunning > 0;
    }

    required property int count

    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical

    readonly property real minimumWidth: children
        .filter(item => item.visible && item.width > 0)
        .reduce((minimumWidth, item) => Math.min(minimumWidth, item.width), Infinity)

    readonly property int stripeCount: {
        if (Plasmoid.configuration.maxStripes === 1) {
            return 1;
        }
        if (Plasmoid.configuration.forceStripes) {
            return Plasmoid.configuration.maxStripes;
        }

        // The maximum number of stripes allowed by the applet's size
        const stripeSizeLimit = vertical
            ? Math.floor(parent.width / children[0].implicitWidth)
            : Math.floor(parent.height / children[0].implicitHeight)
        const maxStripes = Math.min(Plasmoid.configuration.maxStripes, stripeSizeLimit)


        // The number of tasks that will fill a "stripe" before starting the next one
        const maxTasksPerStripe = vertical
            ? Math.ceil(parent.height / TaskManagerApplet.LayoutMetrics.preferredMinHeight())
            : Math.ceil(parent.width / TaskManagerApplet.LayoutMetrics.preferredMinWidth())

        return Math.min(Math.ceil(count / maxTasksPerStripe), maxStripes)
    }

    readonly property int orthogonalCount: {
        return Math.ceil(count / stripeCount);
    }

    rows: vertical ? orthogonalCount : stripeCount
    columns: vertical ? stripeCount : orthogonalCount

    // dock-zoom: a Mac-style zoom on the icons near the mouse.
    // Only scale transforms change while the mouse moves (no new layout),
    // so the GPU does the work. Task.qml reads these values.
    readonly property real zoomRest: 0.8   // icon size at rest, of its slot
    readonly property real zoomMax: 1.12   // icon size right under the mouse
    readonly property real zoomReach: 2.5  // how many icons around it grow
    // Where the mouse is (kept when it leaves, so the zoom fades in place).
    property real zoomX: 0
    // How much zoom is on: eases 0 -> 1 when the mouse comes, back when it goes.
    property real zoomAmount: zoomHover.hovered && !vertical ? 1 : 0
    Behavior on zoomAmount {
        NumberAnimation { duration: 70; easing.type: Easing.OutQuad }
    }
    HoverHandler {
        id: zoomHover
    }
    Binding {
        when: zoomHover.hovered
        target: taskListRoot
        property: "zoomX"
        value: zoomHover.point.position.x
        restoreMode: Binding.RestoreNone
    }
}
