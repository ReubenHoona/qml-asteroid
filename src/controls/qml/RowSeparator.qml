/*
 * Copyright (C) 2026 Timo Könnecke <github.com/moWerk>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as
 * published by the Free Software Foundation, either version 2.1 of the
 * License, or (at your option) any later version.
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
 *   \qmltype RowSeparator
 *   \inqmlmodule org.asteroid.controls
 *
 *   \brief The space between two rows of a list.
 *
 *   Wear OS Material 3 lists draw no dividers: rows are 4 dp apart
 *   (ScalingLazyColumn spacing, E18, E21). RowSeparator is therefore an
 *   empty 4 dp (8 px) gap by default; set \l color to draw a rule again.
 *
 *   \qml
 *   Column {
 *       width: parent.width
 *       Label { text: "Section A" }
 *       RowSeparator {}
 *       Label { text: "Section B" }
 *   }
 *   \endqml
 *
 *   Inside a list delegate where the gap should hug the bottom edge of the
 *   row, set \l pinToBottom to \c true.
 */
Rectangle {
    /*! the color of the separator: transparent (stock lists have no dividers) */
    color: "transparent"
    /*! the gap: 4 dp, the stock list spacing */
    height: Theme.space.xs
    /*! anchor the separator to the bottom edge of the parent, useful
     *       inside list delegates. Defaults to false for use in Column
     *       and Flickable layouts. */
    property bool pinToBottom: false

    anchors {
        bottom: pinToBottom ? parent.bottom : undefined
        left: parent.left
        right: parent.right
    }
}
