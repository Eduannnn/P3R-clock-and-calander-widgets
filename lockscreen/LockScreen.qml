import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
    id: root
    // Lock lifetime must never depend on the desktop widgets or source reloads.
    property bool preview: false
    readonly property url wallpaperSource: "file://" + Quickshell.env("P3R_LOCK_WALLPAPER")
    readonly property url avatarSource: Quickshell.env("P3R_LOCK_AVATAR")
        ? "file://" + Quickshell.env("P3R_LOCK_AVATAR") : ""

    Authentication {
        id: authController
        onAuthenticated: {
            if (root.preview) return;
            sessionLock.locked = false;
            Qt.quit();
        }
    }
    WlSessionLock {
        id: sessionLock
        locked: false
        surface: WlSessionLockSurface {
            id: lockSurface
            color: "#07152e"
            LockView {
                anchors.fill: parent
                authentication: authController
                wallpaperSource: root.wallpaperSource
                avatarSource: root.avatarSource
                userName: authController.userName
                targetScreen: lockSurface.screen
            }
        }
    }
    LazyLoader {
        active: root.preview
        component: FloatingWindow {
            id: previewWindow
            title: "Lock screen preview"
            implicitWidth: 900; implicitHeight: 585
            color: "#07152e"
            LockView {
                anchors.fill: parent
                preview: true
                authentication: authController
                wallpaperSource: root.wallpaperSource
                avatarSource: root.avatarSource
                userName: authController.userName
                targetScreen: previewWindow.screen
            }
            onVisibleChanged: { if (!visible) Qt.quit(); }
        }
    }
    Component.onCompleted: {
        Quickshell.watchFiles = false;
        if (!preview) sessionLock.locked = true;
    }
}
