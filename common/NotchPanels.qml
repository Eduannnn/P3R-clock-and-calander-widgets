pragma Singleton
import QtQuick

QtObject {
    property bool overviewVisible: false
    property real overviewLeft: 0
    property real overviewProgress: 0
    property real indicatorX: 0
    property real indicatorY: 0
    property real indicatorSize: 32
    property bool controlCenterVisible: false
    property real controlCenterLeft: 0
    readonly property bool visible: overviewVisible || controlCenterVisible
    readonly property real left: controlCenterVisible ? controlCenterLeft : overviewLeft
}
