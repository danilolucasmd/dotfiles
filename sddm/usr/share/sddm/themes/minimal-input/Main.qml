import QtQuick 2.15

Rectangle {
    width: Screen.width
    height: Screen.height
    color: "black"

    TextInput {
        id: password
        anchors.centerIn: parent
        width: 300
        height: 40

        focus: true
        echoMode: TextInput.Password
        color: "white"
        font.pixelSize: 18
        cursorVisible: true
        horizontalAlignment: TextInput.AlignHCenter
        verticalAlignment: TextInput.AlignVCenter

        onAccepted: {
            sddm.login("danilolucasmd", text, "hyprland")
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.BlankCursor
    }
}
