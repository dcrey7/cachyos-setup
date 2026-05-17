/*
 SPDX-FileCopyrightText: 2021 Ismael Asensio <isma.af@gmail.com>
 SPDX-FileCopyrightText: 2026 cachyos-setup (Plasma 6 port + GNOME tuning)

 SPDX-License-Identifier: GPL-2.0-or-later

 Ported from abandoned KDE merge request !91 and tuned to approximate the
 GNOME CoverflowAltTab extension. Constants taken from
 reference/gnome-coverflow/ schema + coverflowSwitcher.js:

   - Full-screen black dim overlay  (matches dim-factor = 1.0)
   - Cards stack at xOffsetLeft = 0.20W, xOffsetRight = 0.80W
   - Side rotation ±90°             (coverflow-window-angle = 90)
   - Side card scale 0.80           (GNOME default scale decay)
   - Card size = 0.5 * screen       (preview-to-monitor-ratio = 0.5)
   - Animation 200 ms               (animation-time = 0.2)
   - Per-side pivot points:         left cards pivot at left edge,
                                     right cards pivot at right edge
   - Plasma 6 API: TabBoxSwitcher + WindowThumbnail + kwin 3.0

 Known approximations vs GNOME (PathView limits):
   - QML easing is linear; GNOME uses ease-out cubic
   - Background is plain black; GNOME shows dimmed wallpaper
   - Pivot is hard-thresholded; GNOME interpolates pivot per-frame
*/

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components 3.0 as PC3

// Plasma 6 / KWin 6 -- the KWin type was bumped to 3.0 and the QML names
// changed: Switcher -> TabBoxSwitcher, ThumbnailItem -> WindowThumbnail.
// (Confirmed via KDE Plasma 6 porting guide + current KF6 switcher source.)
import org.kde.kwin 3.0 as KWin


KWin.TabBoxSwitcher {
    id: tabBox
    currentIndex: thumbnailView ? thumbnailView.currentIndex : -1

    PlasmaCore.Dialog {
        id: dialog
        location: PlasmaCore.Types.Floating
        visible: tabBox.visible
        // KDE's current switcher dialogs use only X11BypassWindowManagerHint.
        // FramelessWindowHint is redundant when bypass is set.
        flags: Qt.X11BypassWindowManagerHint
        backgroundHints: PlasmaCore.Dialog.SolidBackground
        x: screenGeometry.x
        y: screenGeometry.y

        mainItem: Item {
            id: root
            width:  tabBox.screenGeometry.width
            height: tabBox.screenGeometry.height

            // ── Full-screen dim overlay ────────────────────────────────────
            // GNOME uses dim-factor 1.0 + RGB (0,0,0) -- fully opaque black.
            // Anything less and the live windows underneath still show through.
            Rectangle {
                id: dimOverlay
                anchors.fill: parent
                color: "black"
                opacity: 1.0
                z: -10
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                PathView {
                    id: thumbnailView

                    readonly property int   visibleCount: Math.min(count, pathItemCount)
                    // Each card is sized exactly half the screen, matching GNOME's
                    // preview-to-monitor-ratio = 0.5 default.
                    readonly property int   boxWidth:  tabBox.screenGeometry.width  * 0.50
                    readonly property int   boxHeight: tabBox.screenGeometry.height * 0.50

                    focus: true
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    preferredHighlightBegin: 0.5
                    preferredHighlightEnd: 0.5
                    highlightRangeMode: PathView.StrictlyEnforceRange

                    // 200 ms, matching GNOME animation-time = 0.2.
                    // Note: PathView interpolates linearly between PathAttribute
                    // values; GNOME uses ease-out cubic. Visual difference minor.
                    highlightMoveDuration: 200

                    // Show fewer side cards so they STACK instead of fanning
                    // out across the screen. GNOME effectively shows only the
                    // first 2-3 side cards on each side; the rest hide behind.
                    pathItemCount: 7

                    // ── Card path ────────────────────────────────────────
                    // Static PathView approximation of the GNOME math:
                    //   coverflow-window-angle      = 90  -> side rotation
                    //   preview-to-monitor-ratio    = 0.5 -> card size
                    //   xOffsetLeft  = width * 0.20 -> left  stack center
                    //   xOffsetRight = width * 0.80 -> right stack center
                    // Side cards collapse to one anchor point per side.
                    // Scale 0.8 matches GNOME default scale decay.
                    path: Path {
                        // Outer-left (cards further away than the visible stack)
                        startX: thumbnailView.width * 0.20
                        startY: thumbnailView.height * 0.50
                        PathAttribute { name: "progress"; value: 0 }
                        PathAttribute { name: "scale"; value: 0.80 }
                        PathAttribute { name: "rotation"; value: 90 }
                        PathPercent   { value: 0 }

                        // Left stack (the visible left tilted card)
                        PathLine {
                            x: thumbnailView.width * 0.20
                            y: thumbnailView.height * 0.50
                        }
                        PathAttribute { name: "progress"; value: 0.9 }
                        PathAttribute { name: "scale"; value: 0.80 }
                        PathAttribute { name: "rotation"; value: 90 }
                        PathPercent   { value: 0.42 }

                        // Curve up to the center card
                        PathQuad {
                            x: thumbnailView.width * 0.50
                            y: thumbnailView.height * 0.50
                            controlX: thumbnailView.width * 0.35
                            controlY: thumbnailView.height * 0.45
                        }
                        PathAttribute { name: "progress"; value: 1 }
                        PathAttribute { name: "scale"; value: 1 }
                        PathAttribute { name: "rotation"; value: 0 }
                        PathPercent   { value: 0.50 }

                        // Curve down to the right stack
                        PathQuad {
                            x: thumbnailView.width * 0.80
                            y: thumbnailView.height * 0.50
                            controlX: thumbnailView.width * 0.65
                            controlY: thumbnailView.height * 0.45
                        }
                        PathAttribute { name: "progress"; value: 0.9 }
                        PathAttribute { name: "scale"; value: 0.80 }
                        PathAttribute { name: "rotation"; value: -90 }
                        PathPercent   { value: 0.58 }

                        // Outer-right
                        PathLine {
                            x: thumbnailView.width * 0.80
                            y: thumbnailView.height * 0.50
                        }
                        PathAttribute { name: "progress"; value: 0 }
                        PathAttribute { name: "scale"; value: 0.80 }
                        PathAttribute { name: "rotation"; value: -90 }
                        PathPercent   { value: 1 }
                    }

                    model: tabBox.model

                    delegate: Item {
                        id: delegateItem

                        readonly property string caption: model.caption
                        readonly property var    icon:    model.icon

                        // Scale thumbnails so each fits inside the boxWidth x boxHeight.
                        readonly property real scaleFactor: {
                            if (thumbnail.implicitWidth  < thumbnailView.boxWidth &&
                                thumbnail.implicitHeight < thumbnailView.boxHeight) {
                                return 1
                            }
                            return Math.min(thumbnailView.boxWidth  / thumbnail.implicitWidth,
                                            thumbnailView.boxHeight / thumbnail.implicitHeight)
                        }

                        width:  Math.round(thumbnail.implicitWidth  * scaleFactor)
                        height: Math.round(thumbnail.implicitHeight * scaleFactor)
                        scale:  PathView.onPath ? PathView.scale : 0

                        // Z order: center card on top, side cards behind. Use
                        // PathView.progress so the closer-to-center card always
                        // covers ones further out. (Mirrors GNOME's
                        // make_top_layer / make_bottom_layer calls.)
                        z: PathView.onPath
                             ? Math.floor((PathView.progress ?? 0) * thumbnailView.visibleCount * 10)
                             : -1

                        // GNOME side previews are tweened to full opacity --
                        // no per-side fade. (Earlier review pointed this out.)
                        opacity: PathView.onPath ? 1.0 : 0

                        KWin.WindowThumbnail {
                            id: thumbnail
                            readonly property double ratio: implicitWidth / implicitHeight
                            wId: windowId
                            anchors.fill: parent
                        }

                        // Soft drop shadow under each card
                        Kirigami.ShadowedRectangle {
                            anchors.fill: parent
                            z: -1
                            color: "transparent"
                            shadow.size:  PlasmaCore.Units.gridUnit * 2
                            shadow.color: "black"
                            opacity: 0.8
                        }

                        // ── Per-side pivot point (matches GNOME) ──────────
                        // GNOME pivots left cards at x=0 (left edge), right
                        // cards at x=1 (right edge), center card at x=0.5.
                        // This makes side cards look "hinged" like real cover
                        // flow rather than free-floating panels.
                        //   coverflowSwitcher.js:196  -> pivot (0,   0.5)
                        //   coverflowSwitcher.js:200  -> pivot (1,   0.5)
                        readonly property real _rot: delegateItem.PathView.rotation ?? 0
                        transform: Rotation {
                            origin {
                                x: delegateItem._rot > 0
                                     ? 0
                                     : (delegateItem._rot < 0
                                          ? delegateItem.width
                                          : delegateItem.width / 2)
                                y: delegateItem.height / 2
                            }
                            axis  { x: 0; y: 1; z: 0 }
                            angle: delegateItem._rot
                        }

                        TapHandler {
                            grabPermissions: PointerHandler.TakeOverForbidden
                            gesturePolicy:   TapHandler.WithinBounds
                            onSingleTapped: {
                                if (index === thumbnailView.currentIndex) {
                                    // Clicking the front-most card activates it.
                                    // The TabBoxSwitcher model still exposes
                                    // activate(index) on Plasma 6.
                                    thumbnailView.model.activate(index)
                                    return
                                }
                                thumbnailView.movementDirection =
                                    (delegateItem.PathView.rotation < 0)
                                        ? PathView.Positive
                                        : PathView.Negative
                                thumbnailView.currentIndex = index
                            }
                        }
                    }

                    // No highlight rectangle — GNOME doesn't draw one either;
                    // the icon + title below identify the current window.

                    layer.enabled: true
                    layer.smooth:  true

                    onMovementStarted: movementDirection = PathView.Shortest

                    Keys.onUpPressed:    decrementCurrentIndex()
                    Keys.onLeftPressed:  decrementCurrentIndex()
                    Keys.onDownPressed:  incrementCurrentIndex()
                    Keys.onRightPressed: incrementCurrentIndex()
                }

                // ── Bottom icon + window title (like GNOME) ────────────────
                RowLayout {
                    Layout.preferredHeight: PlasmaCore.Units.iconSizes.large
                    Layout.bottomMargin:    PlasmaCore.Units.gridUnit * 3
                    Layout.topMargin:       PlasmaCore.Units.gridUnit
                    Layout.alignment:       Qt.AlignHCenter
                    spacing: PlasmaCore.Units.gridUnit

                    PlasmaCore.IconItem {
                        source: thumbnailView.currentItem ? thumbnailView.currentItem.icon : ""
                        implicitWidth:  PlasmaCore.Units.iconSizes.large
                        implicitHeight: PlasmaCore.Units.iconSizes.large
                        Layout.alignment: Qt.AlignVCenter
                    }

                    PC3.Label {
                        font.bold:      true
                        font.pointSize: Math.round(PlasmaCore.Theme.defaultFont.pointSize * 1.6)
                        color:          "white"
                        text:           thumbnailView.currentItem ? thumbnailView.currentItem.caption : ""
                        maximumLineCount: 1
                        elide:          Text.ElideMiddle
                        Layout.maximumWidth: tabBox.screenGeometry.width * 0.8
                        Layout.alignment:    Qt.AlignVCenter
                    }
                }
            }
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
        if (!visible) {
            thumbnailView.currentIndex = 0
        }
    }
}
