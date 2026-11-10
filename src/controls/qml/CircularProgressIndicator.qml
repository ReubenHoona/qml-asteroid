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
    \qmltype CircularProgressIndicator
    \inqmlmodule org.asteroid.controls

    \brief The Wear OS circular progress indicator (E49, E50; E20/E21 of the
    dialogs audit): a determinate ring or an indeterminate spinner.

    \b Determinate (\c{indeterminate: false}, the default): fills its parent
    as the full-screen ring at the screen edge. Stroke 5 dp (10 px), 2 dp
    from the edge, starting at 12 o'clock (270 degrees), the indicator in
    primary and the track in surfaceContainer with a gap of stroke / 3 on
    each side; past 1 (overflow) the track turns primary at 60 %. Progress
    changes animate (default effects spring, about 297 ms).

    \b Indeterminate: a 24 dp spinner (48 x 48 px), 3 dp (6 px) stroke, gap
    stroke / 3, starting at 12 o'clock, on a 5000 ms cycle: rotation 0 to
    1440 degrees linear plus extra turns 0 / 360 / 360 / 720 degrees and an
    arc length of 0.8 / 0.2 / 0.8 / 0 of the circle at 1250 / 2500 / 3750 /
    5000 ms, standard easing (0.2, 0, 0, 1) between the key frames.

    Battery: the spinner animates only while it is visible and the display
    is on (\l displayOn, the application is active); otherwise nothing runs.

    \qml
    CircularProgressIndicator { indeterminate: true; anchors.centerIn: parent }
    CircularProgressIndicator { anchors.fill: parent; progress: download.fraction }
    \endqml
*/
Item {
    id: indicator

    /*! Progress 0..1 (determinate); above 1 is overflow. */
    property real progress: 0
    /*! Spin without a known end. */
    property bool indeterminate: false
    /*! The display is on: the spinner stops when it is off. */
    property bool displayOn: Qt.application.active
    /*! Stroke: 5 dp determinate, 3 dp indeterminate. */
    property real strokeWidth: indeterminate ? Theme.dp(3) : Theme.dp(5)
    /*! Gap between the indicator and the track: stroke / 3. */
    readonly property real gap: strokeWidth / 3
    /*! Distance from the edge of the item to the stroke: 2 dp (determinate). */
    property real edgePadding: indeterminate ? 0 : Theme.space.xxs
    property color color: Theme.color.primary
    property color trackColor: progress > 1 ? Qt.rgba(Theme.color.primary.r, Theme.color.primary.g, Theme.color.primary.b, 0.6)
                                            : Theme.color.surfaceContainer
    /*! The animated progress shown. */
    property real shownProgress: progress
    Behavior on shownProgress {
        enabled: !indicator.indeterminate
        NumberAnimation {
            duration: Motion.springDuration(Motion.standard.defaultEffects.stiffness)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.springEasing
        }
    }

    /*! The spinner animation runs. */
    readonly property bool running: _cycle.running

    /*! Time in the 5000 ms cycle. */
    property real cycleTime: 0
    readonly property var _keyTimes: [0, 1250, 2500, 3750, 5000]
    readonly property var _keySweep: [0, 0.8, 0.2, 0.8, 0]
    readonly property var _keyExtra: [0, 0, 360, 360, 720]

    // standard easing (0.2, 0, 0, 1) as CSS cubic-bezier
    function _ease(x) {
        var x1 = 0.2, y1 = 0, x2 = 0, y2 = 1
        function bx(t) { return 3 * x1 * t * (1 - t) * (1 - t) + 3 * x2 * t * t * (1 - t) + t * t * t }
        function by(t) { return 3 * y1 * t * (1 - t) * (1 - t) + 3 * y2 * t * t * (1 - t) + t * t * t }
        var lo = 0, hi = 1
        for (var i = 0; i < 24; i++) {
            var m = (lo + hi) / 2
            if (bx(m) < x) lo = m; else hi = m
        }
        return by((lo + hi) / 2)
    }
    /*! A key-framed value at \a t ms. */
    function keyframe(values, t) {
        var k = _keyTimes
        for (var i = 1; i < k.length; i++) {
            if (t <= k[i]) {
                var f = _ease((t - k[i - 1]) / (k[i] - k[i - 1]))
                return values[i - 1] + (values[i] - values[i - 1]) * f
            }
        }
        return values[values.length - 1]
    }
    /*! The spinner's head angle (degrees) and arc length (fraction) now. */
    readonly property real spinRotation: 1440 * cycleTime / 5000 + keyframe(_keyExtra, cycleTime)
    readonly property real spinSweep: keyframe(_keySweep, cycleTime)

    readonly property real _start: 270 + (indeterminate ? spinRotation : 0)
    readonly property real _fraction: indeterminate ? spinSweep
                                                    : (shownProgress > 1 ? shownProgress - Math.floor(shownProgress) : Math.max(0, shownProgress))
    readonly property real _radius: Math.min(width, height) / 2 - edgePadding - strokeWidth / 2
    readonly property real _gapDeg: _radius > 0 ? gap / _radius * 180 / Math.PI : 0

    implicitWidth: Theme.dp(24)
    implicitHeight: Theme.dp(24)

    Accessible.role: Accessible.ProgressBar

    NumberAnimation {
        id: _cycle
        target: indicator
        property: "cycleTime"
        from: 0
        to: 5000
        duration: 5000
        loops: Animation.Infinite
        running: indicator.indeterminate && indicator.visible && indicator.displayOn
    }

    ProgressArc {
        id: track
        anchors.fill: parent
        radius: indicator._radius
        strokeWidth: indicator.strokeWidth
        color: indicator.trackColor
        startAngle: indicator._fraction > 0 ? indicator._start + indicator._fraction * 360 + indicator._gapDeg : indicator._start
        sweepAngle: indicator._fraction > 0 ? Math.max(0, 360 * (1 - indicator._fraction) - 2 * indicator._gapDeg) : 360
    }
    ProgressArc {
        id: bar
        anchors.fill: parent
        radius: indicator._radius
        strokeWidth: indicator.strokeWidth
        color: indicator.color
        startAngle: indicator._start
        sweepAngle: 360 * Math.min(1, indicator._fraction)
    }
}
