/*
    SPDX-FileCopyrightText: 2026 dcrey7 <abhishek01789@gmail.com>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

"use strict";

var coverSwitchZoomInEffect = {
    duration: animationTime(180),
    sessionActive: false,
    animationActive: false,
    sessionStartWindow: null,
    expectingActivation: false,
    expirationDeadline: 0,

    loadConfig: function () {
        coverSwitchZoomInEffect.duration = animationTime(180);
        console.log("coverswitch-zoom-in loadConfig duration=" + coverSwitchZoomInEffect.duration);
    },

    windowGeometry: function (window) {
        if (!window) {
            return null;
        }
        if (window.geometry) {
            return window.geometry;
        }
        if (window.frameGeometry) {
            return window.frameGeometry;
        }
        return null;
    },

    describeWindow: function (window) {
        if (!window) {
            return "null";
        }
        try {
            return [
                "caption=" + window.caption,
                "class=" + window.windowClass,
                "managed=" + window.managed,
                "visible=" + window.visible,
                "minimized=" + window.minimized,
                "deleted=" + window.deleted
            ].join(" ");
        } catch (e) {
            return "" + window;
        }
    },

    describeRect: function (rect) {
        if (!rect) {
            return "null";
        }
        try {
            return JSON.stringify(rect);
        } catch (e) {
            return [
                "x=" + rect.x,
                "y=" + rect.y,
                "width=" + rect.width,
                "height=" + rect.height
            ].join(" ");
        }
    },

    describeKeys: function (object) {
        var keys = [];
        try {
            keys = Object.keys(object);
        } catch (e) {
            keys = [];
        }
        try {
            for (var key in object) {
                if (keys.indexOf(key) === -1) {
                    keys.push(key);
                }
            }
        } catch (e) {
        }
        return keys.join(",");
    },

    screenGeometryForWindow: function (window, windowRect) {
        try {
            if (window && window.output && window.output.geometry) {
                return window.output.geometry;
            }
        } catch (e) {
        }

        try {
            if (effects.virtualScreenGeometry) {
                return effects.virtualScreenGeometry;
            }
        } catch (e) {
        }

        return windowRect;
    },

    onTabBoxAdded: function (mode) {
        console.log("coverswitch-zoom-in tabBoxAdded mode=" + mode);
        coverSwitchZoomInEffect.sessionActive = true;
        coverSwitchZoomInEffect.sessionStartWindow = effects.activeWindow;
        coverSwitchZoomInEffect.expectingActivation = false;
        coverSwitchZoomInEffect.expirationDeadline = 0;
        console.log("coverswitch-zoom-in sessionStartWindow="
            + (effects.activeWindow ? effects.activeWindow.caption : "null"));
    },

    onTabBoxUpdated: function () {
        // No-op: window activation is caught after tabBoxClosed.
        console.log("coverswitch-zoom-in tabBoxUpdated (no-op)");
    },

    onTabBoxClosed: function () {
        if (!coverSwitchZoomInEffect.sessionActive) {
            console.log("coverswitch-zoom-in tabBoxClosed: no active session, skipping");
            return;
        }
        if (coverSwitchZoomInEffect.animationActive) {
            coverSwitchZoomInEffect.resetSession();
            return;
        }
        coverSwitchZoomInEffect.sessionActive = false;
        coverSwitchZoomInEffect.expectingActivation = true;
        coverSwitchZoomInEffect.expirationDeadline = Date.now() + 400;

        console.log("coverswitch-zoom-in tabBoxClosed (arming windowActivated catch)");
    },

    onWindowActivated: function (window) {
        if (!coverSwitchZoomInEffect.expectingActivation) {
            return;
        }
        if (Date.now() > coverSwitchZoomInEffect.expirationDeadline) {
            console.log("coverswitch-zoom-in expiration: no windowActivated within 400ms");
            coverSwitchZoomInEffect.expectingActivation = false;
            coverSwitchZoomInEffect.expirationDeadline = 0;
            coverSwitchZoomInEffect.sessionStartWindow = null;
            return;
        }
        coverSwitchZoomInEffect.expectingActivation = false;
        coverSwitchZoomInEffect.expirationDeadline = 0;

        console.log("coverswitch-zoom-in windowActivated post-tabbox window="
            + (window ? window.caption : "null")
            + " start="
            + (coverSwitchZoomInEffect.sessionStartWindow
                ? coverSwitchZoomInEffect.sessionStartWindow.caption
                : "null"));

        if (!window) {
            coverSwitchZoomInEffect.sessionStartWindow = null;
            return;
        }
        if (window === coverSwitchZoomInEffect.sessionStartWindow) {
            console.log("coverswitch-zoom-in skip: activated same as start (user dismissed)");
            coverSwitchZoomInEffect.sessionStartWindow = null;
            return;
        }

        coverSwitchZoomInEffect.sessionStartWindow = null;
        coverSwitchZoomInEffect.runZoomIn(window);
    },

    runZoomIn: function (window) {
        if (!window) return;

        var rect = coverSwitchZoomInEffect.windowGeometry(window);
        if (!rect || rect.width <= 0 || rect.height <= 0) {
            console.log("coverswitch-zoom-in runZoomIn skip: invalid rect "
                + (rect ? rect.width + "x" + rect.height : "null"));
            return;
        }

        var screenRect = coverSwitchZoomInEffect.screenGeometryForWindow(window, rect);
        var cardW = Math.round(screenRect.width * 0.45);
        var cardH = Math.round(screenRect.height * 0.45);
        var cardX = Math.round(screenRect.x + (screenRect.width - cardW) / 2);
        var cardY = Math.round(screenRect.y + (screenRect.height - cardH) / 2);

        // Translation is relative to the window's CURRENT position. We want the
        // animation to LOOK like the window starts at the card rect (cardX, cardY)
        // at size cardW x cardH, then grows to its real rect.
        var fromTransX = cardX - rect.x;
        var fromTransY = cardY - rect.y;

        console.log("coverswitch-zoom-in runZoomIn window=" + window.caption
            + " rect=" + JSON.stringify(rect)
            + " card=" + cardX + "," + cardY + " " + cardW + "x" + cardH
            + " fromTrans=" + fromTransX + "," + fromTransY);

        try {
            var animId = animate({
                window: window,
                curve: QEasingCurve.OutCubic,
                duration: coverSwitchZoomInEffect.duration,
                keepAlive: false,
                animations: [
                    {
                        type: Effect.Size,
                        from: {
                            value1: cardW,
                            value2: cardH
                        },
                        to: {
                            value1: rect.width,
                            value2: rect.height
                        }
                    },
                    {
                        type: Effect.Translation,
                        from: {
                            value1: fromTransX,
                            value2: fromTransY
                        },
                        to: {
                            value1: 0,
                            value2: 0
                        }
                    },
                    {
                        type: Effect.Opacity,
                        from: 0.85,
                        to: 1.0
                    }
                ]
            });
            console.log("coverswitch-zoom-in animate returned id=" + animId);
            window.coverswitchZoomInAnimation = animId;
            coverSwitchZoomInEffect.animationActive = true;
        } catch (e) {
            console.log("coverswitch-zoom-in animate FAILED: " + e);
        }
    },

    resetSession: function () {
        coverSwitchZoomInEffect.sessionActive = false;
        coverSwitchZoomInEffect.expectingActivation = false;
        coverSwitchZoomInEffect.expirationDeadline = 0;
        coverSwitchZoomInEffect.sessionStartWindow = null;
    },

    onAnimationEnded: function (window) {
        console.log("coverswitch-zoom-in animationEnded window=" +
            coverSwitchZoomInEffect.describeWindow(window));
        if (!window || !window.coverswitchZoomInAnimation) {
            return;
        }

        delete window.coverswitchZoomInAnimation;
        coverSwitchZoomInEffect.animationActive = false;
        window.setData(Effect.WindowForceBlurRole, null);
    },

    init: function () {
        console.log("coverswitch-zoom-in EFFECT init called");
        console.log("coverswitch-zoom-in effects.tabBoxAdded type=" + typeof effects.tabBoxAdded);
        console.log("coverswitch-zoom-in effects.tabBoxClosed type=" + typeof effects.tabBoxClosed);
        console.log("coverswitch-zoom-in effects.tabBoxUpdated type=" + typeof effects.tabBoxUpdated);
        console.log("coverswitch-zoom-in effects.windowActivated type=" + typeof effects.windowActivated);
        console.log("coverswitch-zoom-in effects.windowActivatedChanged type=" + typeof effects.windowActivatedChanged);
        console.log("coverswitch-zoom-in effects.activeWindowChanged type=" + typeof effects.activeWindowChanged);
        console.log("coverswitch-zoom-in effects.activated type=" + typeof effects.activated);
        console.log("coverswitch-zoom-in effects keys: " + coverSwitchZoomInEffect.describeKeys(effects));
        try {
            console.log("coverswitch-zoom-in Effect keys: " + coverSwitchZoomInEffect.describeKeys(Effect));
        } catch (e) {
            console.log("coverswitch-zoom-in Effect keys FAILED: " + e);
        }
        try {
            effect.configChanged.connect(coverSwitchZoomInEffect.loadConfig);
            effect.animationEnded.connect(coverSwitchZoomInEffect.onAnimationEnded);
            effects.tabBoxAdded.connect(coverSwitchZoomInEffect.onTabBoxAdded);
            effects.tabBoxClosed.connect(coverSwitchZoomInEffect.onTabBoxClosed);
            effects.tabBoxUpdated.connect(coverSwitchZoomInEffect.onTabBoxUpdated);
            if (typeof effects.windowActivated !== "undefined") {
                effects.windowActivated.connect(coverSwitchZoomInEffect.onWindowActivated);
            } else if (typeof effects.windowActivatedChanged !== "undefined") {
                effects.windowActivatedChanged.connect(coverSwitchZoomInEffect.onWindowActivated);
            } else if (typeof effects.activeWindowChanged !== "undefined") {
                effects.activeWindowChanged.connect(coverSwitchZoomInEffect.onWindowActivated);
            } else if (typeof effects.activated !== "undefined") {
                effects.activated.connect(coverSwitchZoomInEffect.onWindowActivated);
            }
            console.log("coverswitch-zoom-in EFFECT signals connected OK");
        } catch (e) {
            console.log("coverswitch-zoom-in EFFECT signal connect FAILED: " + e);
        }
        coverSwitchZoomInEffect.loadConfig();
    }
};

coverSwitchZoomInEffect.init();
