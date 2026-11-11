/*
 * Copyright (C) 2026 Reuben Horner
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as
 * published by the Free Software Foundation, either version 2.1 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick
import org.asteroid.controls

/*!
    \qmltype Toast
    \inqmlmodule org.asteroid.controls

    \brief The Wear OS text toast (E13), as SystemUI draws it on the watch.

    Stock CP3A (systemui text_toast.xml, SystemUIToast.java:59-100,120-142,
    160-186,283-284, framework drawable-watch/toast_frame.xml,
    values-watch/styles.xml:399-404, config_toastDefaultGravity 0x11 and
    toast_y_offset 0dp in values-watch, NotificationManagerService.java:9901),
    px on the 384 px screen:
    \list
    \li centred on the screen; a rectangle with 24 dp (48 px) corners in
        #E6FFFFFF (tooltip_background_light), 2 dp elevation;
    \li text 13 sp (26 px) black, medium weight, letter spacing 0.023 em,
        at most 2 lines with an ellipsis; 16 dp (32 px) at the start and
        end, 12 dp (24 px) above and below the text; at least 16 dp (32 px)
        from the screen sides;
    \li the app icon, 24 dp (48 px), left of the text (10 dp, 20 px, gap;
        10 dp above and below it) when \c iconSource is given; the text
        starts at the left;
    \li 2000 ms (Toast.LENGTH_SHORT), 3500 ms long;
    \li in: scale 0.9 -> 1.0 over 333 ms (0, 0, 0, 1), alpha 0 -> 1 over
        66 ms, the text alpha 0 -> 1 over 283 ms after 50 ms; out: scale
        1.0 -> 0.9 over 250 ms (0.3, 0, 1, 1), alpha 1 -> 0 over 100 ms
        after 150 ms.
    \endlist

    A toast takes no touches. A new show() replaces the one shown.

    \qml
    Toast { id: toast }
    ...
    toast.show(qsTr("Copied"))
    toast.show(qsTr("Mode on"), true, "file:///usr/share/icons/app.png")
    \endqml
*/
Item {
    id: toast

    /*! The text shown. */
    property string text: ""
    /*! An image source for the app icon; empty: no icon. */
    property string iconSource: ""
    /*! Toast.LENGTH_SHORT and LENGTH_LONG, ms. */
    readonly property int shortDuration: 2000
    readonly property int longDuration: 3500
    /*! The duration of the toast shown now. */
    property int duration: shortDuration

    /*! The toast is on screen (showing, shown or leaving). */
    readonly property bool active: _in.running || _out.running || _bubble.opacity > 0

    /*! Show \a message; \a long for 3500 ms; \a icon an image source. */
    function show(message, long, icon) {
        text = message !== undefined ? message : ""
        iconSource = icon !== undefined && icon !== null ? icon : ""
        duration = long ? longDuration : shortDuration
        _out.stop()
        _in.restart()
        _timer.interval = duration
        _timer.restart()
    }
    /*! Hide it now. */
    function hide() {
        _timer.stop()
        if (_bubble.opacity <= 0 && !_in.running)
            return
        _in.stop()
        _out.restart()
    }

    /* ---- stock numbers (px) ---- */
    readonly property real cornerRadius: Theme.dp(24)
    readonly property color backgroundColor: "#E6FFFFFF"
    readonly property real fontPixelSize: Theme.sp(13)
    readonly property real letterSpacingEm: 0.023
    readonly property real paddingSides: Theme.dp(16)
    readonly property real paddingVertical: Theme.dp(12)
    readonly property real screenMargin: Theme.dp(16)
    readonly property real iconSize: Theme.dp(24)
    readonly property real iconGap: Theme.dp(10)
    readonly property real enterScale: 0.9

    anchors.fill: parent
    enabled: false
    visible: active
    z: 1100

    Accessible.role: Accessible.AlertMessage
    Accessible.name: text

    Timer {
        id: _timer
        onTriggered: toast.hide()
    }

    ParallelAnimation {
        id: _in
        NumberAnimation {
            target: _bubble; property: "scale"; from: toast.enterScale; to: 1
            duration: Motion.duration(333)
            easing.type: Easing.BezierSpline; easing.bezierCurve: [0, 0, 0, 1, 1, 1]
        }
        NumberAnimation {
            target: _bubble; property: "opacity"; from: 0; to: 1
            duration: Motion.duration(66)
        }
        SequentialAnimation {
            PropertyAction { target: _label; property: "opacity"; value: 0 }
            PauseAnimation { duration: Motion.duration(50) }
            NumberAnimation {
                target: _label; property: "opacity"; to: 1
                duration: Motion.duration(283)
            }
        }
    }
    ParallelAnimation {
        id: _out
        NumberAnimation {
            target: _bubble; property: "scale"; to: toast.enterScale
            duration: Motion.duration(250)
            easing.type: Easing.BezierSpline; easing.bezierCurve: [0.3, 0, 1, 1, 1, 1]
        }
        SequentialAnimation {
            PauseAnimation { duration: Motion.duration(150) }
            NumberAnimation {
                target: _bubble; property: "opacity"; to: 0
                duration: Motion.duration(100)
            }
        }
    }

    /*! The rectangle, for tests. */
    readonly property alias bubble: _bubble
    readonly property alias label: _label
    readonly property alias icon: _icon

    Rectangle {
        id: _bubble
        readonly property real maxWidth: toast.width - 2 * toast.screenMargin
        readonly property real contentWidth: (_icon.visible ? toast.iconSize + toast.iconGap : 0) + _label.implicitWidth
        width: Math.min(maxWidth, contentWidth + 2 * toast.paddingSides)
        // the text has 12 dp above and below, the icon 10 dp (text_toast.xml)
        height: Math.max(_label.height + 2 * toast.paddingVertical,
                         _icon.visible ? toast.iconSize + 2 * toast.iconGap : 0)
        anchors.centerIn: parent
        radius: toast.cornerRadius
        color: toast.backgroundColor
        opacity: 0
        scale: toast.enterScale

        Image {
            id: _icon
            visible: toast.iconSource !== ""
            source: toast.iconSource
            width: toast.iconSize
            height: toast.iconSize
            sourceSize.width: width
            sourceSize.height: height
            x: toast.paddingSides
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            id: _label
            x: _icon.visible ? _icon.x + toast.iconSize + toast.iconGap : toast.paddingSides
            width: _bubble.width - x - toast.paddingSides
            anchors.verticalCenter: parent.verticalCenter
            text: toast.text
            color: "#000000"
            font.family: Theme.fontFamily
            font.pixelSize: toast.fontPixelSize
            font.weight: Theme.weight(500)
            font.styleName: Theme.boldText ? "Bold" : "Medium"
            font.letterSpacing: toast.letterSpacingEm * toast.fontPixelSize
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignLeft
        }
    }
}
