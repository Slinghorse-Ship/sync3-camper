import QtQuick 2.6

// Canonical visual tokens copied from the GX/WASM CamperV2Style reference.
QtObject {
    property bool dayMode: false

    readonly property color backgroundTop: dayMode ? "#f8fafb" : "#0d1722"
    readonly property color backgroundBottom: dayMode ? "#edf2f4" : "#080c12"
    readonly property color header: backgroundTop
    readonly property color panel: dayMode ? "#ffffff" : "#111923"
    readonly property color inner: dayMode ? "#e8eef1" : "#15212b"
    readonly property color text: dayMode ? "#10161a" : "#f3f7fa"
    readonly property color muted: dayMode ? "#60717b" : "#8da0ad"
    readonly property color border: dayMode ? "#d6e0e4" : "#243746"

    readonly property color blue: dayMode ? "#006f9f" : "#59caff"
    readonly property color green: dayMode ? "#087a58" : "#36c59b"
    readonly property color orange: dayMode ? "#b76400" : "#ffad45"
    readonly property color yellow: dayMode ? "#9b5b00" : "#f4c94c"
    readonly property color purple: dayMode ? "#7555b5" : "#ad8cf2"
    readonly property color red: dayMode ? "#b83f4a" : "#ef6e76"

    readonly property color selectedBlue: dayMode ? "#e2f5fc" : "#123044"
    readonly property color selectedGreen: dayMode ? "#e4f7ef" : "#112b27"
    readonly property color pressed: dayMode ? "#dce7eb" : "#1c2b39"
    readonly property color disabled: dayMode ? "#e1e6e9" : "#18232c"
}
