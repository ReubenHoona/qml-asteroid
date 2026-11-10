/*
 * Copyright (C) 2023 - Timo Könnecke <github.com/eLtMosen>
 * Copyright (C) 2022 - Ed Beroset <github.com/beroset>
 * Copyright (C) 2020 - Darrel Griët <idanlcontact@gmail.com>
 * Copyright (C) 2015 - Florent Revest <revestflo@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
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
    \qmltype HighlightBar
    \inqmlmodule org.asteroid.controls

    \brief A combined Rectangle and MouseArea with the Wear OS press ripple.

    The \l HighlightBar can be used as part of a delegate for a \l ListView
    or other similar collection or by itself as a convenience. It fills its
    parent, is transparent, draws the stock bounded ripple (\l Ripple: the
    content colour at 10 % from the touch point, 450 ms grow, 375 ms fade)
    while pressed and emits \l MouseArea::clicked. \c forceOn shows the
    \c activeColor fill (a selected item).

    Note that because HighlightBar fills
    the parent, creating a smaller HighlightBar requires defining a
    parent with a set width and height.

    \qml
    import QtQuick
    import org.asteroid.controls

    Item {
        width: 200; height: 104
        HighlightBar { radius: 52; onClicked: console.log("tap") }
    }
    \endqml
*/
MouseArea {
    id: bar

    /*! alias to receive boolean forceOn to act like a controlled radio button */
    property bool forceOn: false

    /*! The fill while \c forceOn is set */
    property color activeColor: "#33ffffff"
    property color inactiveColor: "#00ffffff"
    property alias color: highlight.color
    /*! Corner radius of the fill and the ripple */
    property alias radius: highlight.radius
    /*! The ripple colour: the content colour (white by default) */
    property alias rippleColor: _ripple.color

    hoverEnabled: true

    anchors.fill: parent

    Rectangle {
        id: highlight
        anchors.fill: parent
        color: bar.forceOn ? bar.activeColor : bar.inactiveColor
        Behavior on color {
            ColorAnimation {
                duration: 150;
                easing.type: Easing.OutQuad
            }
        }
    }

    Ripple {
        id: _ripple
        radius: highlight.radius
        pressed: bar.pressed
        pressX: bar.mouseX
        pressY: bar.mouseY
    }
}
