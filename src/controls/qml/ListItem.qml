/*
 * Copyright (C) 2023 - Timo Könnecke <github.com/eLtMosen>
 *               2015 - Florent Revest <revestflo@gmail.com>
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
import org.asteroid.utils

/*!
    \qmltype ListItem
    \inqmlmodule org.asteroid.controls

    \brief A delegate to display a icon and text combo.

    An example is shown below which display three icons
    with their associated text and allows the user to select
    one.  Note that both highlighting and processing of the
    \l ListItem::clicked signal should typically be explicitly
    set.

    \qml
    import QtQuick
    import org.asteroid.controls

    Item {

        ListModel {
            id: powerModel
            ListElement { text: "off"; icon: "ios-power-outline" }
            ListElement { text: "reboot"; icon: "ios-sync" }
            ListElement { text: "fire"; icon: "ios-bonfire-outline" }
        }

        ListView {
            id: powerItems
            model: powerModel
            anchors {
                top: parent.top
                topMargin: parent.height * 0.20
            }
            height: parent.height
            width: parent.width
            delegate: ListItem {
                title: text
                iconName: icon
                highlight: powerItems.currentIndex == index ? 0.2 : 0
                onClicked: powerItems.currentIndex = index
            }
        }
    }
    \endqml
*/
Item {
    id: listItem

    /*! alias to recieve string label.text */
    property alias title: label.text
    /*! alias to recieve string icon.name */
    property alias iconName: icon.name
    /*! alias to recieve boolean highlight.forceOn */
    property alias highlight: highlight.forceOn
    /*! size of the icon/s */
    property int iconSize: Math.min(height - Dims.h(6), Dims.h(15))
    /*! size of the label text */
    property int labelFontSize: Dims.l(9)
    /*!
        Shrink and fade the item near the top and bottom of a round screen
        while it scrolls in a list, as Wear OS lists do (see \l EdgeEffect).
    */
    property alias edgeEffect: edge.enabled

    /*! forward the clicked() signal to parent */
    signal clicked()

    width: parent.width
    // Wear OS touch targets are at least 48 dp: 96 px on the 384 px round
    // screen (25%), where a row was 21% (80 px); the icon keeps its size
    height: DeviceSpecs.hasRoundScreen ? Dims.h(25) : Dims.h(21)

    EdgeEffect { id: edge; item: listItem }
    transform: Scale {
        origin.x: listItem.width / 2
        origin.y: listItem.height / 2
        xScale: edge.scale
        yScale: edge.scale
    }

    HighlightBar {
        id: highlight
        opacity: edge.alpha

        onClicked: parent.clicked()
    }

    Icon {
        id: icon

        opacity: edge.alpha
        width: iconSize
        height: width

        anchors {
            verticalCenter: parent.verticalCenter
            left: parent.left
            leftMargin: DeviceSpecs.hasRoundScreen ? Dims.w(18) : Dims.w(12)
        }
    }

    Label {
        id: label

        opacity: edge.alpha
        anchors {
            leftMargin: DeviceSpecs.hasRoundScreen ? Dims.w(6) : Dims.w(10)
            left: icon.right
            verticalCenter: parent.verticalCenter
        }
        font {
            pixelSize: labelFontSize
            styleName: "SemiCondensed Light"
        }
    }
}
