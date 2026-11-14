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
    \qmltype Placeholder
    \inqmlmodule org.asteroid.controls

    \brief A loading placeholder with the stock shimmer (E52).

    Stock: the placeholder fill is onSurface at 10 % over the container;
    the shimmer is a diagonal onSurface gradient sweeping from -0.5 to 1.5
    of the size in 800 ms, every 2000 ms, its alpha peaking at 50 % (stops
    0.1 / 0.65 / 0.9); when the content arrives (\l loading false) the
    placeholder wipes off in 400 ms.

    Battery: the shimmer runs only while visible, loading and the display
    is on; at rest nothing animates.

    \qml
    Placeholder { width: 200; height: 32; radius: 16; loading: !model.ready }
    \endqml
*/
Item {
    id: placeholder

    /*! Content is still loading. */
    property bool loading: true
    property real radius: Theme.shape.large
    property bool displayOn: Qt.application.active
    readonly property bool shimmering: _shimmer.running
    /*! Sweep position, -0.5 .. 1.5 of the size. */
    property real sweep: -0.5

    readonly property color fillColor: Qt.rgba(Theme.color.onSurface.r, Theme.color.onSurface.g, Theme.color.onSurface.b, 0.10)

    opacity: loading ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: Motion.duration(400); easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.easing.standard } }

    Rectangle {
        id: fill
        anchors.fill: parent
        radius: Math.min(placeholder.radius, height / 2)
        color: placeholder.fillColor
        clip: true

        Rectangle {
            // a diagonal band: rotated 45 degrees, moved across by "sweep"
            readonly property real d: Math.sqrt(fill.width * fill.width + fill.height * fill.height)
            width: d
            height: d
            // the sweep runs from the start: from the right in a right to left layout
            x: (placeholder.LayoutMirroring.enabled ? fill.width * (1 - placeholder.sweep) : fill.width * placeholder.sweep) - width / 2
            y: (fill.height - height) / 2
            rotation: placeholder.LayoutMirroring.enabled ? -45 : 45
            transform: Scale {
                origin.x: width / 2
                xScale: placeholder.LayoutMirroring.enabled ? -1 : 1
            }
            visible: placeholder.sweep > -0.5 && placeholder.sweep < 1.5
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.1; color: Qt.rgba(Theme.color.onSurface.r, Theme.color.onSurface.g, Theme.color.onSurface.b, 0) }
                GradientStop { position: 0.65; color: Qt.rgba(Theme.color.onSurface.r, Theme.color.onSurface.g, Theme.color.onSurface.b, 0.5) }
                GradientStop { position: 0.9; color: Qt.rgba(Theme.color.onSurface.r, Theme.color.onSurface.g, Theme.color.onSurface.b, 0) }
            }
        }
    }

    SequentialAnimation {
        id: _shimmer
        loops: Animation.Infinite
        running: placeholder.loading && placeholder.visible && placeholder.displayOn && !Motion.reduceMotion
        NumberAnimation { target: placeholder; property: "sweep"; from: -0.5; to: 1.5; duration: 800 }
        PauseAnimation { duration: 1200 }
        onRunningChanged: if (!running) placeholder.sweep = -0.5
    }
}
