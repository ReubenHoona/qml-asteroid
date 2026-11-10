/*
 * Copyright (C) 2026 - Timo Könnecke <github.com/moWerk>
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
    \qmltype LabeledActionButton
    \inqmlmodule org.asteroid.controls

    \brief A \l ListRow with an icon on the right: a Wear OS button row whose
    icon (26 dp, primary) marks what a tap does.

    \qml
    LabeledActionButton {
        text: qsTr("Check for updates")
        icon: "ios-refresh"
        onClicked: updater.check()
    }
    \endqml
*/
ListRow {
    /*!
        \qmlproperty string LabeledActionButton::icon
        The icon name to display on the right side of the row.
    */
    property string icon: ""

    Connections {
        target: actionArea
        function onStatusChanged() {
            if (actionArea.status === Loader.Ready)
                actionArea.item.name = Qt.binding(function() { return icon })
        }
    }

    iconSize: Theme.size.icon

    actionComponent: Item {
        property string name: ""
        onNameChanged: icon.name = name
        Icon {
            id: icon
            anchors.centerIn: parent
            width: Theme.size.icon
            height: width
            color: enabled ? Theme.color.primary : Qt.rgba(Theme.color.onSurface.r, Theme.color.onSurface.g, Theme.color.onSurface.b, Theme.alpha.disabledContent)
        }
    }
}
