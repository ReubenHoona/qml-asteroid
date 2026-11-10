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
    \qmltype ArcProgressIndicator
    \inqmlmodule org.asteroid.controls

    \brief The Wear OS indeterminate arc progress indicator (E50), as on the
    shutdown screen.

    Stock (ArcProgressIndicatorKt.java:27-82, ArcProgressIndicatorDefaults,
    ShuttingDialogProvider ConstraintLayout$5.java:170-174): a square box
    81.24 % of the screen height, centred; stroke 6 dp (12 px), gap 2 dp;
    an arc from 65 to 115 degrees (50 degrees at the bottom), run
    counter-clockwise; the head moves 0 -> 1 over 0-600 ms and the tail over
    300-900 ms with cubic (0.3, 0, 0.7, 1), on a 2000 ms cycle; primaryDim.
    The track (the rest of the arc) is drawn in surfaceContainer (inferred,
    as the circular indicator).

    Battery: it animates only while visible and the display is on.
*/
Item {
    id: indicator

    property bool displayOn: Qt.application.active
    property color color: Theme.color.primaryDim
    property color trackColor: Theme.color.surfaceContainer
    readonly property real strokeWidth: Theme.dp(6)
    readonly property real gap: Theme.dp(2)
    /*! The arc: 65 .. 115 degrees. */
    readonly property real arcStart: 65
    readonly property real arcEnd: 115
    readonly property bool running: _cycle.running

    property real cycleTime: 0
    function _ease(x) {
        var x1 = 0.3, y1 = 0, x2 = 0.7, y2 = 1
        function bx(t) { return 3 * x1 * t * (1 - t) * (1 - t) + 3 * x2 * t * t * (1 - t) + t * t * t }
        function by(t) { return 3 * y1 * t * (1 - t) * (1 - t) + 3 * y2 * t * t * (1 - t) + t * t * t }
        var lo = 0, hi = 1
        for (var i = 0; i < 24; i++) {
            var m = (lo + hi) / 2
            if (bx(m) < x) lo = m; else hi = m
        }
        return by((lo + hi) / 2)
    }
    /*! Head and tail progress (0..1) at \a t ms of the 2000 ms cycle. */
    function head(t) { return _ease(Math.max(0, Math.min(1, t / 600))) }
    function tail(t) { return _ease(Math.max(0, Math.min(1, (t - 300) / 600))) }

    // counter-clockwise from 115 degrees
    readonly property real _span: arcEnd - arcStart
    readonly property real _headAngle: arcEnd - _span * head(cycleTime)
    readonly property real _tailAngle: arcEnd - _span * tail(cycleTime)
    readonly property real _radius: Math.min(width, height) * 0.8124 / 2 - strokeWidth / 2
    readonly property real _gapDeg: _radius > 0 ? gap / _radius * 180 / Math.PI : 0

    anchors.fill: parent

    NumberAnimation {
        id: _cycle
        target: indicator
        property: "cycleTime"
        from: 0
        to: 2000
        duration: 2000
        loops: Animation.Infinite
        running: indicator.visible && indicator.displayOn
    }

    ProgressArc {
        anchors.fill: parent
        radius: indicator._radius
        strokeWidth: indicator.strokeWidth
        color: indicator.trackColor
        startAngle: indicator.arcStart
        sweepAngle: Math.max(0, indicator._headAngle - indicator.arcStart - indicator._gapDeg)
    }
    ProgressArc {
        anchors.fill: parent
        radius: indicator._radius
        strokeWidth: indicator.strokeWidth
        color: indicator.trackColor
        startAngle: indicator._tailAngle + indicator._gapDeg
        sweepAngle: Math.max(0, indicator.arcEnd - indicator._tailAngle - indicator._gapDeg)
    }
    ProgressArc {
        anchors.fill: parent
        radius: indicator._radius
        strokeWidth: indicator.strokeWidth
        color: indicator.color
        startAngle: indicator._headAngle
        sweepAngle: indicator._tailAngle - indicator._headAngle
    }
}
