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
    \qmltype ListSubHeader
    \inqmlmodule org.asteroid.controls

    \brief A category header inside a list (E16).

    Stock (ListSubHeaderTokens.java:6-8): titleSmall (14 sp, weight 550,
    16 sp line) in onSurface, start-aligned at the bottom of an at least
    48 dp tall box; 4.16 % of the screen width each side (16 px), 12 dp
    above (0 for a page's first item, \l first) and 8 dp below.
*/
Item {
    id: header

    /*! The header text. */
    property alias text: label.text
    /*! The first item of the page: no space above. */
    property bool first: false
    property real horizontalPadding: Theme.margin.subtitleSide
    readonly property real topPadding: first ? 0 : Theme.space.l
    readonly property real bottomPadding: Theme.space.m
    readonly property alias label: label

    width: parent ? parent.width : Theme.dp(192)
    implicitHeight: Math.max(Theme.size.listHeader, label.implicitHeight + topPadding + bottomPadding)
    height: implicitHeight

    Accessible.role: Accessible.Heading
    Accessible.name: text

    Label {
        id: label
        anchors {
            left: parent.left
            right: parent.right
            leftMargin: header.horizontalPadding
            rightMargin: header.horizontalPadding
            bottom: parent.bottom
            bottomMargin: header.bottomPadding
        }
        role: "titleSmall"
        color: Theme.color.onSurface
        horizontalAlignment: Text.AlignLeft
        wrapMode: Text.Wrap
        maximumLineCount: 2
    }
}
