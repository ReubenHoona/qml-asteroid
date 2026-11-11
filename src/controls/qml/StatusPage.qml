/*
 * Copyright (C) 2017 - Florent Revest <revestflo@gmail.com>
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
    \qmltype StatusPage
    \inqmlmodule org.asteroid.controls

    \brief The Wear OS empty and error states (E26, E27): an icon, one
    centred message and, for an error, one action button.

    Stock CP3A (SysUI kvn.java:73-74 "You're all caught up", Weather
    hiq.java:232-272 "Can't download weather data." + "Retry", SysUI
    jde.java:105-141), px on the 384 px screen:
    \list
    \li the icon 28 dp (56 px) in onSurfaceVariant #CECDD4, no disc;
    \li the message 6 dp (12 px) below it, centred, at most 140 dp (280 px)
        wide, in the same muted colour, bodyMedium 28 px (inferred: the
        stock token is not resolved in the obfuscated code);
    \li an optional action (\l actionText, e.g. "Retry", "Open settings"):
        a filled tonal button 8 dp (16 px) below the message;
    \li the group centred on the screen.
    \endlist

    The application chooses the words: one plain line, not a heading.

    \qml
    StatusPage {
        text: qsTr("Can't download weather data.")
        icon: "ios-cloud-outline"
        actionText: qsTr("Retry")
        onActionClicked: weather.refresh()
    }
    \endqml
*/
Item {
    id: statusPage

    /*! The message. */
    property alias text: statusLabel.text
    /*! The icon name. */
    property alias icon: statusIcon.name
    /*! The icon itself can be tapped (\l clicked). Default false. */
    property bool clickable: false
    /*! Kept for older applications; stock has no disc behind the icon, so it changes nothing. */
    property bool activeBackground: false
    /*! The label of the action button; empty: no button. */
    property string actionText: ""
    /*! The muted colour of the icon and the message. */
    property color color: Theme.color.onSurfaceVariant

    /*! Emitted when the icon is tapped (\l clickable). */
    signal clicked()
    /*! Emitted when the action button is tapped. */
    signal actionClicked()

    /* ---- stock numbers (px) ---- */
    readonly property real iconSize: Theme.dp(28)
    readonly property real textGap: Theme.dp(6)
    readonly property real textMaxWidth: Theme.dp(140)
    readonly property real actionGap: Theme.dp(8)

    readonly property alias iconItem: statusIcon
    readonly property alias label: statusLabel
    readonly property alias actionButton: statusAction

    anchors.fill: parent

    Column {
        id: group
        anchors.centerIn: parent
        width: Math.min(statusPage.width - 2 * Theme.margin.side, statusPage.textMaxWidth)
        spacing: 0

        Icon {
            id: statusIcon
            anchors.horizontalCenter: parent.horizontalCenter
            width: statusPage.iconSize
            height: width
            color: statusPage.color
            visible: statusPage.icon !== ""
            MouseArea {
                id: statusMA
                enabled: statusPage.clickable
                anchors.fill: parent
                anchors.margins: -Theme.dp(10)
                onClicked: statusPage.clicked()
            }
        }
        Item { width: 1; height: statusPage.icon !== "" && statusPage.text !== "" ? statusPage.textGap : 0 }
        Label {
            id: statusLabel
            width: parent.width
            role: "bodyMedium"
            color: statusPage.color
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            visible: statusPage.text !== ""
        }
        Item { width: 1; height: statusPage.actionText !== "" ? statusPage.actionGap : 0 }
        FilledTonalButton {
            id: statusAction
            visible: statusPage.actionText !== ""
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(implicitWidth, statusPage.width - 2 * Theme.margin.side)
            text: statusPage.actionText
            centered: true
            onClicked: statusPage.actionClicked()
        }
    }
}
