import QtQuick 2.6

// Canonical visual tokens shared with the Node-RED dashboard and gui-v2 port.
// The old Dark/Light mock-up defines the visual language; the current SYNC
// application continues to define geometry, touch targets and behaviour.
QtObject {
    property bool dayMode: false

    readonly property color backgroundTop: dayMode ? "#fafafa" : "#081116"
    readonly property color backgroundBottom: dayMode ? "#eceff1" : "#03090d"
    readonly property color header: dayMode ? "#ffffff" : "#071116"
    readonly property color panel: dayMode ? "#fbfbfb" : "#111b20"
    readonly property color inner: dayMode ? "#f1f3f4" : "#0d171c"
    readonly property color text: dayMode ? "#24282c" : "#f4f7f9"
    readonly property color muted: dayMode ? "#626a70" : "#aab4ba"
    readonly property color border: dayMode ? "#d0d3d5" : "#344149"

    readonly property color blue: dayMode ? "#0875c1" : "#42b9f4"
    readonly property color green: dayMode ? "#11845f" : "#2fd49b"
    readonly property color orange: dayMode ? "#d66b00" : "#ff981f"
    readonly property color yellow: dayMode ? "#a96f00" : "#f4c94c"
    readonly property color purple: dayMode ? "#7555b5" : "#ad8cf2"
    readonly property color red: dayMode ? "#b83f4a" : "#ef6e76"

    readonly property color selectedBlue: dayMode ? "#e4f3fb" : "#102b38"
    readonly property color selectedGreen: dayMode ? "#e0f4ec" : "#15352d"
    readonly property color pressed: dayMode ? "#d9e1e5" : "#263640"
    readonly property color disabled: dayMode ? "#e1e4e6" : "#182229"
}
