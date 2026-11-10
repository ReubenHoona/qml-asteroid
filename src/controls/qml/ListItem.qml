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

    Drawn as the Wear OS navigation row (FilledTonalButton, E19): a
    surfaceContainer container with CornerLarge corners inside the list's
    5.2 % side padding, 52 dp (104 px) tall, the icon 26 dp in primary, 6 dp
    to the label in labelMedium (onSurface), 14 dp padding, a bounded ripple
    on press. Rows are 4 dp apart: the item is 112 px tall (the row and 2 dp
    above and below). \l highlight shows the selected colours
    (primaryContainer / onPrimaryContainer), as a selected radio row.

    An example is shown below which display three icons
    with their associated text and allows the user to select
    one.

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
                highlight: powerItems.currentIndex == index
                onClicked: powerItems.currentIndex = index
            }
        }
    }
    \endqml
*/
Item {
    id: listItem

    /*! alias to recieve string label.text */
    property alias title: row.text
    /*! alias to recieve string icon.name */
    property alias iconName: row.iconName
    /*! show the item as selected */
    property bool highlight: false
    /*! size of the icon: 26 dp */
    property int iconSize: Theme.size.icon
    /*! size of the label text: labelMedium, 15 sp */
    property int labelFontSize: Theme.type.labelMedium.pixelSize
    /*!
        Shrink and fade the item near the top and bottom of a round screen
        while it scrolls in a list, as Wear OS lists do (see \l EdgeEffect).
    */
    property alias edgeEffect: edge.enabled
    /*! The row button (for tests). */
    readonly property alias button: row

    /*! forward the clicked() signal to parent */
    signal clicked()

    width: parent ? parent.width : Theme.dp(192)
    // the 52 dp row plus the 4 dp list spacing (ScalingLazyColumnKt.java:167)
    height: Theme.size.button + Theme.space.xs

    EdgeEffect { id: edge; item: listItem }
    transform: Scale {
        origin.x: listItem.width / 2
        origin.y: listItem.height / 2
        xScale: edge.scale
        yScale: edge.scale
    }

    Button {
        id: row
        opacity: edge.alpha
        anchors {
            fill: parent
            leftMargin: Theme.margin.listSide
            rightMargin: Theme.margin.listSide
            topMargin: Theme.space.xs / 2
            bottomMargin: Theme.space.xs / 2
        }
        variant: "tonal"
        iconSize: listItem.iconSize
        containerColor: !enabled ? _a(Theme.color.onSurface, Theme.alpha.disabledContainer)
            : listItem.highlight ? Theme.color.primaryContainer : Theme.color.surfaceContainer
        contentColor: !enabled ? _a(Theme.color.onSurface, Theme.alpha.disabledContent)
            : listItem.highlight ? Theme.color.onPrimaryContainer : Theme.color.onSurface
        maximumLineCount: 2
        onClicked: listItem.clicked()
        Binding {
            target: row.label
            property: "font.pixelSize"
            value: listItem.labelFontSize
        }
    }
}
