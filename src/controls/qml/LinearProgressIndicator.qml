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
    \qmltype LinearProgressIndicator
    \inqmlmodule org.asteroid.controls

    \brief A straight progress bar (E51), as the battery item of stock
    Settings: tertiary on surfaceContainer, 4 dp (8 px) tall with round
    caps, 4 dp between the indicator and the track, and a 4 dp stop dot
    (tertiary) at the end of the track.

    \qml
    LinearProgressIndicator { width: parent.width; progress: battery.level / 100 }
    \endqml
*/
Item {
    id: bar

    /*! 0..1 */
    property real progress: 0
    property color color: Theme.color.tertiary
    property color trackColor: Theme.color.surfaceContainer
    readonly property real thickness: Theme.dp(4)
    readonly property real gap: Theme.dp(4)
    readonly property real _p: Math.max(0, Math.min(1, progress))

    implicitWidth: Theme.dp(120)
    implicitHeight: thickness
    height: thickness

    Accessible.role: Accessible.ProgressBar

    Rectangle {
        id: indicator
        height: bar.thickness
        radius: height / 2
        width: bar._p > 0 ? Math.max(height, bar.width * bar._p) : 0
        visible: bar._p > 0
        color: bar.color
    }
    Rectangle {
        id: track
        height: bar.thickness
        radius: height / 2
        x: bar._p > 0 ? indicator.width + bar.gap : 0
        width: Math.max(0, bar.width - x)
        visible: bar._p < 1 && width > 0
        color: bar.trackColor
        Rectangle {
            id: stop
            width: bar.thickness
            height: width
            radius: width / 2
            anchors.right: parent.right
            color: bar.color
        }
    }
}
