/*
 * Copyright (C) 2026 Reuben Horner <reubarb.scons@gmail.com>
 * SPDX-License-Identifier: BSD-3-Clause
 */

import QtQuick
import org.asteroid.controls

/*!
    \qmltype Confirmation
    \inqmlmodule org.asteroid.controls

    \brief A short full screen confirmation: "Sent", "Saved", "Failed".

    As Wear OS confirms an action: the screen dims, a disc grows in
    (scaling from 1.25, Wear OS's dialog entrance) and a check mark draws
    itself in it, the message under it, with a confirm haptic. It goes away
    by itself after \l duration ms or on a tap.

    \qml
    Confirmation { id: confirmation }
    ...
    confirmation.show(qsTrId("id-sent"))           // success
    confirmation.show(qsTrId("id-not-sent"), false) // failure: a cross
    \endqml

    Only transforms and opacity move, for 400 ms; nothing is drawn while it
    is hidden or once it has settled.
*/
Item {
    id: confirmation

    /*! The message under the icon */
    property string text: ""
    /*! True: a check mark on green; false: a cross on red */
    property bool success: true
    /*! How long it stays, in ms (Wear OS: short 1 s, medium 2 s, long 4 s) */
    property int duration: 2000

    /*! Emitted when it has gone */
    signal finished()

    /*! Show \a message; \a ok false shows a failure */
    function show(message, ok) {
        text = message !== undefined ? message : ""
        success = ok === undefined ? true : !!ok
        hideAnim.stop()
        visible = true
        showAnim.restart()
        hideTimer.restart()
        if (success)
            Haptics.confirm()
        else
            Haptics.limit()
    }

    /*! Hide it now (fading out) */
    function hide() {
        if (!visible || hideAnim.running)
            return
        hideTimer.stop()
        showAnim.stop()
        hideAnim.restart()
    }

    anchors.fill: parent
    visible: false
    z: 1000

    // the four parts of the entrance, 0 -> 1
    property real _in: 0      // scrim, disc scale and opacity
    property real _stroke1: 0 // the short leg of the check, or the first bar of the cross
    property real _stroke2: 0 // the long leg, or the second bar
    property real _label: 0

    readonly property var _emphasized: [0.05, 0.7, 0.1, 1, 1, 1]
    readonly property var _standard: [0.2, 0, 0, 1, 1, 1]

    SequentialAnimation {
        id: showAnim
        PropertyAction { target: confirmation; properties: "_in,_stroke1,_stroke2,_label,opacity"; value: 0 }
        PropertyAction { target: confirmation; property: "opacity"; value: 1 }
        ParallelAnimation {
            NumberAnimation {
                target: confirmation; property: "_in"; to: 1; duration: 250
                easing.type: Easing.BezierSpline; easing.bezierCurve: confirmation._emphasized
            }
            SequentialAnimation {
                PauseAnimation { duration: 120 }
                NumberAnimation {
                    target: confirmation; property: "_stroke1"; to: 1; duration: 110
                    easing.type: Easing.BezierSpline; easing.bezierCurve: confirmation._standard
                }
                NumberAnimation {
                    target: confirmation; property: "_stroke2"; to: 1; duration: 170
                    easing.type: Easing.BezierSpline; easing.bezierCurve: confirmation._standard
                }
            }
            SequentialAnimation {
                PauseAnimation { duration: 150 }
                NumberAnimation {
                    target: confirmation; property: "_label"; to: 1; duration: 200
                    easing.type: Easing.BezierSpline; easing.bezierCurve: confirmation._standard
                }
            }
        }
    }

    SequentialAnimation {
        id: hideAnim
        NumberAnimation {
            target: confirmation; property: "opacity"; to: 0; duration: 200
            easing.type: Easing.BezierSpline; easing.bezierCurve: [0.3, 0, 1, 1, 1, 1]
        }
        PropertyAction { target: confirmation; property: "visible"; value: false }
        ScriptAction { script: confirmation.finished() }
    }

    Timer {
        id: hideTimer
        interval: confirmation.duration
        onTriggered: confirmation.hide()
    }

    MouseArea {
        anchors.fill: parent
        onClicked: confirmation.hide()
    }

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.88 * confirmation._in
    }

    Item {
        id: badge
        // Wear OS: a 52 dp icon in the confirmation; the disc around it
        readonly property real size: Math.round(Math.min(confirmation.width, confirmation.height) * 0.36)
        width: size
        height: size
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -Math.round(confirmation.height * 0.06)
        opacity: confirmation._in
        scale: 1.25 - 0.25 * confirmation._in

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: confirmation.success ? "#1e8e3e" : "#d93025"
        }

        // The check mark: two strokes from its corner at (0.42, 0.66);
        // each grows from its start, short leg then long leg
        readonly property real stroke: Math.max(3, Math.round(size * 0.075))

        Rectangle {
            id: shortLeg
            visible: confirmation.success
            readonly property real len: badge.size * 0.21
            x: badge.size * 0.42 - len
            y: badge.size * 0.66 - badge.stroke / 2
            width: len + badge.stroke / 2
            height: badge.stroke
            radius: height / 2
            color: "#ffffff"
            transform: [
                Scale { origin.x: 0; origin.y: badge.stroke / 2; xScale: confirmation._stroke1 },
                Rotation { origin.x: shortLeg.len; origin.y: badge.stroke / 2; angle: 45 }
            ]
        }
        Rectangle {
            id: longLeg
            visible: confirmation.success
            readonly property real len: badge.size * 0.40
            x: badge.size * 0.42 - badge.stroke / 2
            y: badge.size * 0.66 - badge.stroke / 2
            width: len + badge.stroke / 2
            height: badge.stroke
            radius: height / 2
            color: "#ffffff"
            transform: [
                Scale { origin.x: 0; origin.y: badge.stroke / 2; xScale: confirmation._stroke2 },
                Rotation { origin.x: badge.stroke / 2; origin.y: badge.stroke / 2; angle: -45 }
            ]
        }

        // The cross: two bars through the middle
        Repeater {
            model: confirmation.success ? 0 : 2
            delegate: Rectangle {
                readonly property real len: badge.size * 0.46
                x: (badge.size - len) / 2
                y: (badge.size - badge.stroke) / 2
                width: len
                height: badge.stroke
                radius: height / 2
                color: "#ffffff"
                transform: [
                    Scale {
                        origin.x: index === 0 ? 0 : len; origin.y: badge.stroke / 2
                        xScale: index === 0 ? confirmation._stroke1 : confirmation._stroke2
                    },
                    Rotation { origin.x: len / 2; origin.y: badge.stroke / 2; angle: index === 0 ? 45 : -45 }
                ]
            }
        }
    }

    Label {
        anchors.top: badge.bottom
        anchors.topMargin: Math.round(confirmation.height * 0.05)
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.round(confirmation.width * 0.7)
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        maximumLineCount: 2
        elide: Text.ElideRight
        text: confirmation.text
        // Wear OS title medium, 16 sp
        font.pixelSize: Math.round(Math.min(confirmation.width, confirmation.height) * 0.083)
        font.styleName: "SemiCondensed Medium"
        opacity: confirmation._label
        transform: Translate { y: (1 - confirmation._label) * confirmation.height * 0.03 }
    }
}
