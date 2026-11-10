/*
 * Copyright (C) 2016 - Florent Revest <revestflo@gmail.com>
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
import QtQuick.Window
import org.asteroid.controls
import org.asteroid.utils

/*!
    \qmltype PageDot
    \inqmlmodule org.asteroid.controls

    \brief Display indicator dots indicating a fixed collection.

    The \l PageDot control shows a series of dots with one dot
    highlighted.  This is typically used to show a series of pages
    or other items and to indicate where within the collection
    one currently is.

    On a round screen it draws the stock curved page indicator along the
    bottom of the screen (\l ArcPageIndicator; stock paged screens never use
    a straight row, PageIndicator.kt, E40), whatever its own position: the
    dots are placed on the window, not in the item. On a square screen it
    keeps the straight row. Unselected dots are at 30 %.

    Here is a short example:

    \qml
    import QtQuick
    import org.asteroid.controls

    Item {
        PageDot {
            height: parent.height * 0.03
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.bottom
                bottomMargin: parent.height * 0.04
            }
            dotNumber: 5
            currentIndex: 2
        }
    }
    \endqml
*/
Item {
    id: pageDot

    width: height*5/4*(dotNumber+(additionalDot ? 1 : 0))
    visible: additionalDot ? dotNumber > 0 : dotNumber > 1

    property int currentIndex: 0
    property int dotNumber: 0
    property bool additionalDot: false
    property string additionalDotText: "+"

    /*! Draw the curved indicator on the window (round screens). */
    readonly property bool arc: DeviceSpecs.hasRoundScreen && Window.contentItem !== null
    /*! The curved indicator (for tests). */
    readonly property alias arcIndicator: _arc

    ArcPageIndicator {
        id: _arc
        parent: pageDot.arc ? pageDot.Window.contentItem : pageDot
        visible: pageDot.arc && pageDot.visible
        z: 100
        count: pageDot.dotNumber + (pageDot.additionalDot ? 1 : 0)
        position: pageDot.currentIndex
    }

    Row {
        anchors.fill: parent
        spacing: height/4
        visible: !pageDot.arc
        Repeater {
            model: dotNumber
            Rectangle {
                width: parent.height
                height: parent.height
                radius: parent.height
                color: Theme.color.onBackground
                opacity: index == currentIndex ? 1 : Theme.alpha.pageDotUnselected
            }
        }
        Label {
            text: additionalDotText
            width: additionalDot ? parent.height : 0
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            opacity: currentIndex == dotNumber ? 1 : Theme.alpha.pageDotUnselected
            visible: additionalDot
        }
    }
}
