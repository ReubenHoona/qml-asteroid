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
    \qmltype ListHeader
    \inqmlmodule org.asteroid.controls

    \brief The page title as the first item of a scrolling list (E15).

    Stock pages put the title in the list, so it scrolls away with the
    content (ItemLazyColumnKt, ListHeaderTokens.java:6-8): titleMedium
    (16 sp, weight 550, 18 sp line, 0.2 sp tracking) in onBackground,
    centred, up to 3 lines with an ellipsis, at least 48 dp tall; 12 % of the
    screen width each side (46 px on the Pixel Watch 2), 4 dp above and
    12 dp below. Use it as a ListView header or the first item of a
    Flickable's Column instead of \l PageHeader:

    \qml
    ListView {
        header: ListHeader { text: qsTr("Display") }
        ...
    }
    \endqml
*/
Item {
    id: header

    /*! The title. */
    property alias text: label.text
    /*! 12 % of the screen width each side. */
    property real horizontalPadding: Theme.margin.titleSide
    /*! 4 dp above, 12 dp below. */
    property real topPadding: Theme.dp(4)
    property real bottomPadding: Theme.space.l
    /*! The label (for tests). */
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
            top: parent.top
            topMargin: header.topPadding
            bottom: parent.bottom
            bottomMargin: header.bottomPadding
        }
        role: "titleMedium"
        color: Theme.color.onBackground
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.Wrap
        maximumLineCount: 3
        elide: Text.ElideRight
    }
}
