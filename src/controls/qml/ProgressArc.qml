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
import QtQuick.Shapes
import org.asteroid.controls

/*!
    \qmltype ProgressArc
    \inqmlmodule org.asteroid.controls
    \internal

    \brief One round-capped arc segment of the progress indicators.

    The segment covers \l startAngle .. \l startAngle + \l sweepAngle
    degrees (0 at three o'clock, clockwise) including its round caps, on a
    circle of \l radius around the centre of the item, as the Compose
    indicators measure their segments.
*/
Shape {
    id: arc

    property real radius: Math.min(width, height) / 2 - strokeWidth / 2
    property real radiusY: radius
    property real strokeWidth: 10
    property color color: Theme.color.primary
    property real startAngle: 270
    property real sweepAngle: 0
    /*! A full ring is drawn without caps. */
    readonly property bool _full: sweepAngle >= 359.99
    readonly property real _cap: radius > 0 ? (strokeWidth / 2) / radius * 180 / Math.PI : 0
    readonly property real _from: _full ? startAngle : startAngle + Math.min(_cap, sweepAngle / 2)
    readonly property real _sweep: _full ? 360 : Math.max(0.01, sweepAngle - 2 * _cap)

    visible: sweepAngle > 0.01

    ShapePath {
        strokeWidth: arc.strokeWidth
        strokeColor: arc.color
        fillColor: "transparent"
        capStyle: arc._full ? ShapePath.FlatCap : ShapePath.RoundCap
        PathAngleArc {
            centerX: arc.width / 2
            centerY: arc.height / 2
            radiusX: arc.radius
            radiusY: arc.radiusY
            startAngle: arc._from
            sweepAngle: arc._sweep
        }
    }
}
