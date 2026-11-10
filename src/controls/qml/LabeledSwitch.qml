/*
 * Copyright (C) 2026 - Timo Könnecke  <github.com/moWerk>
 *               2022 - Ed Beroset     <github.com/beroset>
 *               2020 - Darrel Griët   <idanlcontact@gmail.com>
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

/*!
    \qmltype LabeledSwitch
    \inqmlmodule org.asteroid.controls

    \brief A \l ListRow with a \l Switch on the right: the Wear OS switch row.

    Tapping anywhere in the row toggles the switch and plays the toggle
    haptic when the Haptics vocabulary has it. As stock (E22), the whole row
    takes the checked colours when the switch is on (primaryContainer,
    onPrimaryContainer); the switch sits in a 32 x 24 dp slot 6 dp after the
    label and 14 dp from the end.

    \qml
    LabeledSwitch {
        text: qsTr("Enable feature")
        checked: true
        onCheckedChanged: console.log("Switch is", checked)
    }
    \endqml
*/
ListRow {
    /*!
        \qmlproperty bool LabeledSwitch::checked
        The toggle state of the switch. Toggled by tapping anywhere in the row.
    */
    property bool checked: false

    checkedStyle: checked

    onClicked: {
        checked = !checked
        if (typeof Haptics.toggle === "function")
            Haptics.toggle()
    }

    Connections {
        target: actionArea
        function onStatusChanged() {
            if (actionArea.status === Loader.Ready)
                actionArea.item.checked = Qt.binding(function() { return checked })
        }
    }

    actionComponent: Item {
        property alias checked: toggle.checked
        Switch {
            id: toggle
            anchors.centerIn: parent
            toggleOnClick: false
        }
    }
}
