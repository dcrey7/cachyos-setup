/*
    Proof-of-concept only.

    Ordinary KWin scripts can manipulate managed dock windows, but the
    documented tabBoxAdded/tabBoxClosed lifecycle signals live in the scripted
    effects API, not the KWin/Script API used by this package.
*/

function log(message) {
    console.info("panel-raise: " + message);
}

function describeWindow(window) {
    return [
        "caption=" + window.caption,
        "dock=" + window.dock,
        "managed=" + window.managed,
        "keepAbove=" + window.keepAbove,
        "layer=" + window.layer,
        "geometry=" + window.x + "," + window.y + " " + window.width + "x" + window.height
    ].join(" ");
}

function panels() {
    return workspace.windowList().filter(function (window) {
        return window.dock;
    });
}

function raisePanels(reason) {
    var dockWindows = panels();
    log(reason + ": found " + dockWindows.length + " dock window(s)");

    dockWindows.forEach(function (panel) {
        log(reason + ": before " + describeWindow(panel));
        panel.keepAbove = true;
        workspace.raiseWindow(panel);
        log(reason + ": after  " + describeWindow(panel));
    });
}

function main() {
    log("loaded; ordinary KWin scripts have no tabbox-open signal");
    raisePanels("startup");

    workspace.windowAdded.connect(function (window) {
        log("windowAdded: " + describeWindow(window));
        raisePanels("windowAdded");
    });

    workspace.windowActivated.connect(function () {
        raisePanels("windowActivated");
    });
}

main();
