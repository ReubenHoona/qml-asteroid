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
    \qmltype Card
    \inqmlmodule org.asteroid.controls

    \brief The Wear OS Material 3 card (E12): a tappable container for a
    group of content.

    Stock (CardTokens): at least 64 dp tall, 12 dp padding, CornerLarge
    (26 dp) corners, surfaceContainer, a bounded ripple on press. Children
    are stacked in a Column inside the padding.

    \qml
    Card {
        width: parent.width
        Label { text: "Card content"; color: Theme.color.onSurfaceVariant }
    }
    \endqml

    \sa AppCard, TitleCard
*/
MouseArea {
    id: card

    /*! 12 dp inside the container. */
    property real padding: Theme.space.l
    /*! Space between the children. */
    property alias spacing: _column.spacing
    property color containerColor: Theme.color.surfaceContainer
    /*! The content colour (ripple). */
    property color contentColor: Theme.color.onSurface
    /*! The container (for tests). */
    readonly property alias container: _container
    readonly property alias ripple: _ripple
    /*! The children. */
    default property alias content: _column.data

    implicitWidth: Theme.dp(160)
    implicitHeight: Math.max(Theme.size.cardMin, _column.implicitHeight + 2 * padding)

    Accessible.role: Accessible.Button

    Rectangle {
        id: _container
        anchors.fill: parent
        radius: Math.min(Theme.shape.large, height / 2)
        color: card.containerColor

        Ripple {
            id: _ripple
            radius: _container.radius
            color: card.contentColor
            pressed: card.pressed
            pressX: card.mouseX
            pressY: card.mouseY
        }
    }

    Column {
        id: _column
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: card.padding
        }
    }
}
