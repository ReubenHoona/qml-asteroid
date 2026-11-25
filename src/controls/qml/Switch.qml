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
import org.asteroid.controls

/*!
    \qmltype Switch
    \inqmlmodule org.asteroid.controls

    \brief The Wear OS switch: the small switch of the Wear OS 6 emulator.

    The Wear OS 6 emulator (BP2A.250605; Settings S18-b, S20-b, S21, S23,
    S24 and the Clock's alarm list S29-b, S29-d, measured from the PNGs):
    \list
    \li A fully round 24 x 10 dp track (48 x 20 px) and a 14 dp (28 px)
        thumb that fills the track ends: its centre 7 dp (14 px) from the
        start of the track when off and 17 dp (34 px) when on, so it stands
        4 px over the track above and below. No border, no tick.
    \li A shadow under the thumb: black at 20 %, 1 dp lower (the 2 px
        crescent under every stock thumb, 20 % darker than the row).
    \li Material 3 (Settings): on, the thumb tertiary #D4C7FF and the track
        tertiary at 38 % (#8985A1 on the checked row's gradient); off, the
        thumb #8B8B8F and the track onSurface at 38 % (#74757C on #2F3036).
    \li Material 2 (\l{Theme}{Theme.materialVersion} 2, the Alarm list): on,
        the thumb secondary #FDE293 and the track secondary at 38 %
        (#8A8164 on the #454648 segment); off, the thumb #999999 and the
        track onSurface at 38 % (#8B8C8D on #454648).
    \li Disabled: thumb and track onSurface at 12 %, no shadow.
    \li One transition, the fast effects spring (stiffness 1400, about
        177 ms), slides the thumb and mixes the colours.
    \endlist

    The track's 38 % lies over \l containerColor, the fill under the switch
    (surfaceContainer by default; a row passes its own). With
    \c "transparent" the track is drawn translucent over whatever is under
    the switch, as stock does on the checked row's gradient.

    The control is 24 x 14 dp (48 x 28 px, the implicit size). Tapping it
    toggles \l checked, as before; in a row, use \l SwitchButton.

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
    /*! The fill under the switch, which the track's 38 % lies over:
        surfaceContainer; "transparent" for a translucent track. */
    property color containerColor: Theme.color.surfaceContainer
    /*! Animation progress, 0 (off) to 1 (on). */
    // (written by the spring below, which sets the first value as it is: no binding here)
    property real progress: 0
    // on the fast effects spring itself, 1.0/1400 (SwitchButtonKt.java:144, motion G5 G6): toggled again
    // mid-way, it keeps its speed
    WearSpring {
        target: control
        property: "progress"
        to: control.checked ? 1 : 0
        stiffness: Motion.standard.fastEffects.stiffness
        dampingRatio: 1.0
        visibilityThreshold: 0.001
    }

    function _a(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
    function _mix(a, b, t) { return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t) }
    // a colour at alpha a over the container (translucent without one)
    function _over(c, a) { return containerColor.a > 0 ? Qt.tint(containerColor, _a(c, a)) : _a(c, a) }

    readonly property bool _m2: Theme.materialVersion === 2

    readonly property real trackWidth: Theme.size.switchTrackWidth
    readonly property real trackHeight: Theme.size.switchTrackHeight
    readonly property real borderWidth: Theme.size.switchTrackBorder
    readonly property real thumbSize: Theme.size.switchThumbOff + (Theme.size.switchThumbOn - Theme.size.switchThumbOff) * progress
    /*! Thumb centre from the start of the track: 7 dp off, 17 dp on (the
        thumb fills the track ends). */
    readonly property real thumbCenter: thumbSize / 2 + (trackWidth - thumbSize) * progress

    /*! The on colour: tertiary (Material 3) or secondary (Material 2). */
    readonly property color onColor: _m2 ? Theme.color.secondary : Theme.color.tertiary
    /*! The off thumb: #8B8B8F (Material 3, S20-b, S24) or #999999 (Material 2, S29-d). */
    readonly property color offThumbColor: _m2 ? "#999999" : "#8B8B8F"

    readonly property color _disabled: _a(Theme.color.onSurface, 0.12)
    readonly property color _offTrack: enabled ? _over(Theme.color.onSurface, 0.38) : _disabled
    readonly property color _onTrack: enabled ? _over(onColor, 0.38) : _disabled
    readonly property color _offThumb: enabled ? offThumbColor : _disabled
    readonly property color _onThumb: enabled ? onColor : _disabled
    /*! The track and thumb colours now. */
    readonly property color trackColor: _mix(_offTrack, _onTrack, progress)
    readonly property color thumbColor: _mix(_offThumb, _onThumb, progress)

    implicitWidth: trackWidth
    implicitHeight: Theme.size.switchThumbOn
    width: implicitWidth
    height: implicitHeight

    /*! The thumb, for tests. */
    readonly property Item _thumb: thumb
    /*! The track, for tests. */
    readonly property Item _track: track

    Accessible.role: Accessible.CheckBox
    Accessible.checkable: true
    Accessible.checked: checked

    Rectangle {
        id: track
        width: control.trackWidth
        height: control.trackHeight
        anchors.centerIn: parent
        radius: height / 2
        color: control.trackColor
        border.width: control.borderWidth
        border.color: color

        Rectangle {
            id: shadow
            visible: control.enabled
            x: thumb.x
            y: thumb.y + Theme.dp(1)
            width: thumb.width
            height: width
            radius: width / 2
            color: Qt.rgba(0, 0, 0, 0.2)
        }

        Rectangle {
            id: thumb
            width: control.thumbSize
            height: width
            radius: width / 2
            // from the start of the track: the right in a right to left layout
            x: control.LayoutMirroring.enabled ? track.width - control.thumbCenter - width / 2
                                               : control.thumbCenter - width / 2
            y: (track.height - height) / 2
            color: control.thumbColor
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: control.toggleOnClick
        onClicked: control.checked = !control.checked
    }
}
