/*
 * Copyright (C) 2017 Florent Revest <revestflo@gmail.com>
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
import QtQuick.VirtualKeyboard

/*!
    \qmltype HandWritingKeyboard
    \inqmlmodule org.asteroid.controls

    \brief A hand writing keyboard for AsteroidOS.

    The HandWritingKeyboard is a virtual keyboard that allows 
    a user to input text without a physical keyboard.
    The HandWritingKeyboard is the default virtual keyboard for 
    AsteroidOS.

    Handwriting needs a handwriting recognition engine in Qt Virtual
    Keyboard. Without one (Qt 6 ships no free engine), the
    HandWritingKeyboard shows the on-screen keyboard instead.
   
    In this example, a simple \l TextField is created in the center 
    of the screen with preview text "sample text".  

    \qml
    import QtQuick
    import org.asteroid.controls

    Item {
        HandWritingKeyboard {
            anchors.fill: parent
        }
        
        TextField {
            width: parent.width * 0.8
            textWidth: parent.width *0.75
            anchors {
                horizontalCenter: parent.horizontalCenter
                verticalCenter: parent.verticalCenter
            }
            previewText: "sample text"
        }
    }
    \endqml

*/
Item {
    id: handWritingKeyboard
    z: 99
    anchors.fill: parent

    HandwritingInputPanel {
        id: handwritingPanel
        anchors.fill: parent
        inputPanel: inputPanel
        Component.onCompleted: {
            active = true
            available = true
        }

        Rectangle {
            z: -1
            anchors.fill: parent
            color: "black"
            opacity: 0.7
            transitions: Transition {
                PropertyAnimation { properties: "opacity"; easing.type: Easing.InOutQuad }
            }
        }

        IconButton {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: parent.height/28

            iconName: "ios-checkmark-circle-outline"

            onClicked: Qt.inputMethod.hide()
        }
    }

    // The handwriting panel is only enabled with a handwriting engine
    // (HandwritingInputPanel.enabled is isHandwritingAvailable()); without
    // one it stays hidden, and so would this keyboard inside it: show the
    // keyboard instead, narrow enough for a round screen and low enough to
    // leave the text fields in the upper part of the screen visible
    InputPanel {
        id: inputPanel
        visible: !handwritingPanel.enabled && active
        width: parent.width * 0.82
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.4
    }
}
