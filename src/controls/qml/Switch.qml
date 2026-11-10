/*
 * Copyright (C) 2020 Darrel Griët <idanlcontact@gmail.com>
 * Copyright (C) 2016 Florent Revest <revestflo@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as
 * published by the Free Software Foundation, either version 2.1 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick
import QtQuick.Shapes
import org.asteroid.controls

/*!
    \qmltype Switch
    \inqmlmodule org.asteroid.controls

    \brief The Wear OS Material 3 switch.

    Stock (SwitchButtonKt.java:144,160, SwitchButtonTokens.java:50-97):
    a fully round 32 x 22 dp track (64 x 44 px) with a 2 dp border.
    \list
    \li Off: track surfaceContainer, border outline, a 12 dp (24 px) thumb in
        outline, its centre 11 dp (22 px) from the start.
    \li On: track and border primary, an 18 dp (36 px) thumb in
        primaryContainer, its centre 21 dp (42 px) from the start, and a check
        mark in primary: strokes (7.4,13)-(9.9,15.5) and (10.5,15.1)-(16.5,9.1)
        dp in a 24 dp box centred on the thumb, 2 dp round caps, scaled by
        1 - (1 - p)^3.
    \li One transition, the fast effects spring (stiffness 1400, about
        177 ms), drives size, position and tick.
    \li Disabled: track and border onSurface at 12 %, thumb onSurface at 12 %
        (off) or background at 38 % (on), tick onSurface at 12 %.
    \endlist

    The control sits in a 32 x 24 dp slot (64 x 48 px, the implicit size).
    Tapping it toggles \l checked, as before; in a row, use \l SwitchButton.

    \qml
    Switch { checked: true }
    \endqml
*/
Item {
    id: control

    /*! The switch is on. */
    property bool checked: false
    /*! Toggle on tap (off when a row handles the taps). */
    property bool toggleOnClick: true
    /*! Animation progress, 0 (off) to 1 (on). */
    property real progress: checked ? 1 : 0
    Behavior on progress {
        NumberAnimation {
            duration: Motion.springDuration(Motion.standard.fastEffects.stiffness)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.springEasing
        }
    }

    function _a(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
    function _mix(a, b, t) { return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t) }

    readonly property real trackWidth: Theme.size.switchTrackWidth
    readonly property real trackHeight: Theme.size.switchTrackHeight
    readonly property real borderWidth: Theme.size.switchTrackBorder
    readonly property real thumbSize: Theme.size.switchThumbOff + (Theme.size.switchThumbOn - Theme.size.switchThumbOff) * progress
    /*! Thumb centre from the start of the track: 11 dp off, 21 dp on. */
    readonly property real thumbCenter: Theme.dp(11) + Theme.dp(10) * progress

    readonly property color _offTrack: enabled ? Theme.color.surfaceContainer : "transparent"
    readonly property color _onTrack: enabled ? Theme.color.primary : _a(Theme.color.onSurface, 0.12)
    readonly property color _offBorder: enabled ? Theme.color.outline : _a(Theme.color.onSurface, 0.12)
    readonly property color _onBorder: enabled ? Theme.color.primary : _a(Theme.color.onSurface, 0.12)
    readonly property color _offThumb: enabled ? Theme.color.outline : _a(Theme.color.onSurface, 0.12)
    readonly property color _onThumb: enabled ? Theme.color.primaryContainer : _a(Theme.color.background, 0.38)
    readonly property color tickColor: enabled ? Theme.color.primary : _a(Theme.color.onSurface, 0.12)

    implicitWidth: Theme.dp(32)
    implicitHeight: Theme.dp(24)
    width: implicitWidth
    height: implicitHeight

    Accessible.role: Accessible.CheckBox
    Accessible.checkable: true
    Accessible.checked: checked

    Rectangle {
        id: track
        width: control.trackWidth
        height: control.trackHeight
        anchors.centerIn: parent
        radius: height / 2
        color: control._mix(control._offTrack, control._onTrack, control.progress)
        border.width: control.borderWidth
        border.color: control._mix(control._offBorder, control._onBorder, control.progress)

        Rectangle {
            id: thumb
            width: control.thumbSize
            height: width
            radius: width / 2
            x: control.thumbCenter - width / 2
            anchors.verticalCenter: parent.verticalCenter
            color: control._mix(control._offThumb, control._onThumb, control.progress)
        }

        Shape {
            id: tick
            // a 24 dp box centred on the thumb
            width: Theme.dp(24)
            height: width
            x: control.thumbCenter - width / 2
            anchors.verticalCenter: parent.verticalCenter
            readonly property real p: control.progress
            scale: 1 - Math.pow(1 - p, 3)
            visible: p > 0
            ShapePath {
                strokeWidth: Theme.size.switchTickStroke
                strokeColor: control.tickColor
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathMove { x: Theme.dp(7.4); y: Theme.dp(13) }
                PathLine { x: Theme.dp(9.9); y: Theme.dp(15.5) }
                PathMove { x: Theme.dp(10.5); y: Theme.dp(15.1) }
                PathLine { x: Theme.dp(16.5); y: Theme.dp(9.1) }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: control.toggleOnClick
        onClicked: control.checked = !control.checked
    }
}
