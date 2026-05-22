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
    selectedWindow: null,
    selectionChanged: false,

    loadConfig: function () {
        coverSwitchZoomInEffect.duration = animationTime(180);
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

    currentTabBoxWindow: function () {
        try {
            return effects.currentTabBoxWindow;
        } catch (e) {
            return null;
        }
    },

    rememberSelection: function () {
        if (!coverSwitchZoomInEffect.sessionActive) {
            return;
        }

        var window = coverSwitchZoomInEffect.currentTabBoxWindow();
        if (!window) {
            return;
        }

        coverSwitchZoomInEffect.selectedWindow = window;
        if (window !== coverSwitchZoomInEffect.sessionStartWindow) {
            coverSwitchZoomInEffect.selectionChanged = true;
        }
    },

    onTabBoxAdded: function () {
        coverSwitchZoomInEffect.sessionActive = true;
        coverSwitchZoomInEffect.sessionStartWindow = effects.activeWindow;
        coverSwitchZoomInEffect.selectedWindow = coverSwitchZoomInEffect.currentTabBoxWindow();
        coverSwitchZoomInEffect.selectionChanged =
            coverSwitchZoomInEffect.selectedWindow &&
            coverSwitchZoomInEffect.selectedWindow !== coverSwitchZoomInEffect.sessionStartWindow;
    },

    onTabBoxUpdated: function () {
        coverSwitchZoomInEffect.rememberSelection();
    },

    onTabBoxClosed: function () {
        if (!coverSwitchZoomInEffect.sessionActive) {
            return;
        }
        if (coverSwitchZoomInEffect.animationActive) {
            coverSwitchZoomInEffect.resetSession();
            return;
        }

        coverSwitchZoomInEffect.rememberSelection();

        var targetWindow = coverSwitchZoomInEffect.selectedWindow || coverSwitchZoomInEffect.currentTabBoxWindow();
        if ((!targetWindow || targetWindow === coverSwitchZoomInEffect.sessionStartWindow) &&
                effects.activeWindow && effects.activeWindow !== coverSwitchZoomInEffect.sessionStartWindow) {
            targetWindow = effects.activeWindow;
            coverSwitchZoomInEffect.selectionChanged = true;
        }

        if (!targetWindow || targetWindow === coverSwitchZoomInEffect.sessionStartWindow || !coverSwitchZoomInEffect.selectionChanged) {
            coverSwitchZoomInEffect.resetSession();
            return;
        }

        coverSwitchZoomInEffect.animateWindow(targetWindow);
        coverSwitchZoomInEffect.resetSession();
    },

    animateWindow: function (window) {
        if (!window || effects.hasActiveFullScreenEffect) {
            return;
        }
        if (!window.visible || !window.managed || window.minimized || window.deleted) {
            return;
        }
        if (window.coverswitchZoomInAnimation) {
            cancel(window.coverswitchZoomInAnimation);
            delete window.coverswitchZoomInAnimation;
            window.setData(Effect.WindowForceBlurRole, null);
            coverSwitchZoomInEffect.animationActive = false;
        }

        var windowRect = coverSwitchZoomInEffect.windowGeometry(window);
        if (!windowRect || windowRect.width <= 0 || windowRect.height <= 0) {
            return;
        }

        var screenRect = coverSwitchZoomInEffect.screenGeometryForWindow(window, windowRect);
        var smallW = Math.max(1, Math.round(screenRect.width * 0.45));
        var smallH = Math.max(1, Math.round(screenRect.height * 0.45));
        var smallX = Math.round(screenRect.x + (screenRect.width - smallW) / 2);
        var smallY = Math.round(screenRect.y + (screenRect.height - smallH) / 2);

        window.setData(Effect.WindowForceBlurRole, true);
        coverSwitchZoomInEffect.animationActive = true;
        window.coverswitchZoomInAnimation = animate({
            window: window,
            curve: QEasingCurve.OutCubic,
            duration: coverSwitchZoomInEffect.duration,
            keepAlive: false,
            animations: [
                {
                    type: Effect.Size,
                    from: {
                        value1: smallW,
                        value2: smallH
                    },
                    to: {
                        value1: windowRect.width,
                        value2: windowRect.height
                    }
                },
                {
                    type: Effect.Translation,
                    from: {
                        value1: smallX - windowRect.x - (windowRect.width - smallW) / 2,
                        value2: smallY - windowRect.y - (windowRect.height - smallH) / 2
                    },
                    to: {
                        value1: 0.0,
                        value2: 0.0
                    }
                },
                {
                    type: Effect.Opacity,
                    from: 0.85,
                    to: 1.0
                }
            ]
        });
    },

    resetSession: function () {
        coverSwitchZoomInEffect.sessionActive = false;
        coverSwitchZoomInEffect.sessionStartWindow = null;
        coverSwitchZoomInEffect.selectedWindow = null;
        coverSwitchZoomInEffect.selectionChanged = false;
    },

    onAnimationEnded: function (window) {
        if (!window || !window.coverswitchZoomInAnimation) {
            return;
        }

        delete window.coverswitchZoomInAnimation;
        coverSwitchZoomInEffect.animationActive = false;
        window.setData(Effect.WindowForceBlurRole, null);
    },

    init: function () {
        effect.configChanged.connect(coverSwitchZoomInEffect.loadConfig);
        effect.animationEnded.connect(coverSwitchZoomInEffect.onAnimationEnded);
        effects.tabBoxAdded.connect(coverSwitchZoomInEffect.onTabBoxAdded);
        effects.tabBoxClosed.connect(coverSwitchZoomInEffect.onTabBoxClosed);
        effects.tabBoxUpdated.connect(coverSwitchZoomInEffect.onTabBoxUpdated);
        coverSwitchZoomInEffect.loadConfig();
    }
};

coverSwitchZoomInEffect.init();
