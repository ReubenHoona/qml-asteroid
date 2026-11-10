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
    \qmltype ProgressDialog
    \inqmlmodule org.asteroid.controls

    \brief A full-screen progress screen (E21): the determinate ring at the
    screen edge with a centred title and message.

    Stock: the ring (\l CircularProgressIndicator, 5 dp stroke, 2 dp from the
    edge, from 12 o'clock) and a title in titleLarge with a message in
    bodyMedium, 12 dp apart, centred.

    \qml
    ProgressDialog { anchors.fill: parent; title: qsTr("Installing"); message: "42 %"; progress: 0.42 }
    \endqml
*/
Item {
    id: dialog

    property real progress: 0
    property alias title: titleLabel.text
    property alias message: messageLabel.text
    readonly property alias ring: ring

    Rectangle {
        anchors.fill: parent
        color: Theme.color.background
        radius: width / 2
    }

    CircularProgressIndicator {
        id: ring
        anchors.fill: parent
        progress: dialog.progress
    }

    Column {
        anchors.centerIn: parent
        width: parent.width - 2 * Theme.margin.titleSide
        spacing: Theme.space.l
        Label {
            id: titleLabel
            width: parent.width
            visible: text !== ""
            role: "titleLarge"
            color: Theme.color.onBackground
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            maximumLineCount: 3
        }
        Label {
            id: messageLabel
            width: parent.width
            visible: text !== ""
            role: "bodyMedium"
            color: Theme.color.onSurfaceVariant
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            maximumLineCount: 3
        }
    }
}
