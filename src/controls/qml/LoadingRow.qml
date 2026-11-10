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
    \qmltype LoadingRow
    \inqmlmodule org.asteroid.controls

    \brief The stock inline loading row (E20 of the dialogs audit): a small
    indeterminate \l CircularProgressIndicator, 4 dp, and a short text
    ("Verifying...", "Connecting..."), centred. The spinner runs only while
    the row is visible and the display is on.

    \qml
    LoadingRow { anchors.horizontalCenter: parent.horizontalCenter; text: qsTr("Checking for updates") }
    \endqml
*/
Row {
    id: row

    property alias text: label.text
    readonly property alias indicator: spinner

    spacing: Theme.dp(4)

    CircularProgressIndicator {
        id: spinner
        indeterminate: true
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.dp(24)
        height: width
    }
    Label {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        role: "bodyMedium"
        color: Theme.color.onSurface
    }
}
