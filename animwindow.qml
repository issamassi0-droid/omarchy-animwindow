pragma ComponentBehavior: Bound
import QtQuick

// AnimWindow: oshelf-style open/close animation helper.
//
//   PanelWindow {
//       visible: root.opened || anim.closing
//       color: "transparent"
//       AnimWindow { id: anim; open: root.opened }
//       BorderSurface {
//           opacity: anim.openness
//           y: baseY + (1 - anim.openness) * anim.slideY
//           scale: anim.startScale + anim.openness * (1 - anim.startScale)
//       }
//   }

Item {
    id: root

    required property bool open
    property real duration: 260
    property real closeDuration: Math.round(root.duration * 0.75)
    property real slideY: 40.0
    property real startScale: 0.96

    property real openness: root.open ? 1.0 : 0.0
    readonly property bool closing: !root.open && _opennessAnim.running

    Behavior on openness {
        NumberAnimation {
            id: _opennessAnim
            duration: root.open ? root.duration : root.closeDuration
            easing.type: Easing.OutCubic
        }
    }
}
