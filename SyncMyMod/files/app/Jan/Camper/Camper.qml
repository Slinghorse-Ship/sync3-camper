import QtQuick 2.6

MouseArea {
    id: boot
    width: 800
    height: 480
    acceptedButtons: Qt.AllButtons
    preventStealing: true
    propagateComposedEvents: false

    // Der globale Ford-Loader zeichnet die Camper-App als Overlay. Deshalb
    // muss auch jede nicht von einem inneren Bedienelement belegte Fläche den
    // Touch annehmen; andernfalls erreicht er zusätzlich Radio/Navi darunter.
    onPressed: mouse.accepted = true
    onReleased: mouse.accepted = true
    onClicked: mouse.accepted = true
    onDoubleClicked: mouse.accepted = true
    onPressAndHold: mouse.accepted = true

    property bool embeddedInGlobalHost: false
    signal closeRequested()

    function leaveApp() {
        if (embeddedInGlobalHost)
            closeRequested()
        else
            back()
    }

    Rectangle {
        anchors.fill: parent
        color: "#0b1016"
    }

    Text {
        anchors.centerIn: parent
        visible: mainLoader.status === Loader.Loading
        text: "CAMPER WIRD GELADEN"
        color: "#dfe7ee"
        font.pixelSize: 18
        font.bold: true
    }

    Column {
        anchors.centerIn: parent
        width: parent.width - 80
        spacing: 12
        visible: mainLoader.status === Loader.Error

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "CAMPER APP KONNTE NICHT GELADEN WERDEN"
            color: "#e05e68"
            font.pixelSize: 19
            font.bold: true
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "QML-Ladefehler - Version 3.9.9"
            color: "#aeb9c5"
            font.pixelSize: 13
        }
    }

    Rectangle {
        x: 732
        y: 12
        width: 56
        height: 48
        radius: 8
        visible: mainLoader.status === Loader.Error
        color: closeArea.pressed ? "#683038" : "#3d2026"
        border.color: "#e05e68"
        z: 100

        Text {
            anchors.centerIn: parent
            text: "X"
            color: "#ffffff"
            font.pixelSize: 22
            font.bold: true
        }

        MouseArea {
            id: closeArea
            anchors.fill: parent
            onClicked: boot.leaveApp()
        }
    }

    Loader {
        id: mainLoader
        anchors.fill: parent
        source: "CamperMain.qml"

        onLoaded: {
            item.width = width
            item.height = height
            item.embeddedInGlobalHost = boot.embeddedInGlobalHost
        }
    }

    Connections {
        target: mainLoader.item
        onCloseRequested: boot.closeRequested()
    }

    onEmbeddedInGlobalHostChanged: {
        if (mainLoader.item)
            mainLoader.item.embeddedInGlobalHost = embeddedInGlobalHost
    }
}
