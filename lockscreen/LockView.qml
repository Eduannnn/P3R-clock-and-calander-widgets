import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtMultimedia
import Quickshell
import "../p3r-clock" as Clock
import "../indicator" as Indicator
import "../notch" as Notch

Item {
    id: view
    required property var authentication
    property bool preview: false
    property url wallpaperSource
    property url avatarSource
    property string userName: ""
    property var targetScreen: null

    Rectangle { anchors.fill: parent; color: "#07152e" }
    MediaPlayer {
        id: video
        source: view.wallpaperSource
        loops: MediaPlayer.Infinite
        autoPlay: true
        videoOutput: videoOutput
    }
    VideoOutput { id: videoOutput; anchors.fill: parent; fillMode: VideoOutput.PreserveAspectCrop }
    Rectangle { anchors.fill: parent; color: "#38000000" }

    // Render the real widgets inside the secure surface. Their desktop
    // windows remain hidden; the indicator exposes only lock-screen power actions.
    Item {
        id: widgets
        z: 2
        width: view.targetScreen ? view.targetScreen.width : view.width
        height: view.height / Math.max(0.01, view.width / width)
        transform: Scale { xScale: view.width / widgets.width; yScale: xScale }
        Notch.NotchCalibration { id: calibration; screen: view.targetScreen }
        readonly property int bandHeight: Math.floor(calibration.valid
            ? calibration.rect.y + calibration.rect.height : 37.5)
        Clock.ClockWidget {
            embeddedParent: widgets
            embeddedScreen: view.targetScreen
            embeddedFullView: true
        }
        Notch.NotchWidget {
            embeddedParent: widgets
            embeddedScreen: view.targetScreen
            lockScreenMode: true
            onLockControlsClosed: password.forceActiveFocus()
        }
    }

    Column {
        anchors.centerIn: parent
        width: Math.min(300, parent.width - 48)
        spacing: 18

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 88; height: 88; radius: 44
            color: "#3340526f"
            border { color: "#a0ffffff"; width: 2 }
            Image {
                id: avatar
                anchors { fill: parent; margins: 3 }
                source: view.avatarSource
                fillMode: Image.PreserveAspectCrop
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: avatarMask
                }
            }
            Item {
                id: avatarMask
                anchors.fill: avatar
                visible: false
                layer.enabled: true
                Rectangle { anchors.fill: parent; radius: width / 2; color: "white" }
            }
            Text {
                anchors.centerIn: parent
                visible: avatar.status !== Image.Ready
                text: view.userName.slice(0, 1).toUpperCase()
                color: "white"
                font { pixelSize: 34; weight: Font.Medium }
            }
        }
        Text {
            width: parent.width
            text: view.userName
            horizontalAlignment: Text.AlignHCenter
            color: "white"
            font { pixelSize: 18; weight: Font.DemiBold }
        }
        TextField {
            id: password
            width: parent.width; height: 48
            focus: true
            enabled: view.preview || !view.authentication.busy
            placeholderText: view.preview ? "Password · preview" : "Password"
            echoMode: !view.preview && view.authentication.responseVisible ? TextInput.Normal : TextInput.Password
            color: !view.preview && view.authentication.responseVisible ? "white" : "transparent"
            selectionColor: "transparent"
            selectedTextColor: color
            cursorVisible: !view.preview && view.authentication.responseVisible && activeFocus
            placeholderTextColor: "#c0ffffff"
            horizontalAlignment: TextInput.AlignHCenter
            inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
            font.pixelSize: 15
            background: Rectangle {
                radius: 12
                color: "#750c1931"
                border { color: password.activeFocus ? "#e0ffffff" : "#70ffffff"; width: 1 }
            }
            onAccepted: {
                if (!view.preview) view.authentication.submit(text);
                clear();
            }
            PasswordDots {
                anchors.centerIn: parent
                count: password.length
                visible: view.preview || !view.authentication.responseVisible
            }
            Connections {
                target: view.authentication
                function onBusyChanged() { if (!view.authentication.busy) password.forceActiveFocus(); }
            }
            Component.onCompleted: forceActiveFocus()
        }
        Text {
            width: parent.width
            height: 36
            text: view.preview ? "Preview only — close this window to return"
                : view.authentication.busy ? "Unlocking…" : view.authentication.message
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
            color: "#eeeeff"
            font.pixelSize: 12
        }
    }
    Text {
        anchors { bottom: parent.bottom; bottomMargin: 12; horizontalCenter: parent.horizontalCenter }
        visible: video.error !== MediaPlayer.NoError
        text: "Wallpaper unavailable"
        color: "#b0ffffff"
        font.pixelSize: 11
    }
}
