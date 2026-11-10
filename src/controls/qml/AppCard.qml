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
    \qmltype AppCard
    \inqmlmodule org.asteroid.controls

    \brief The Wear OS app card (E13): an app header, a title and content.

    Stock (CardDefaults, E13): header = app image 18 dp, 4 dp, app name in
    titleSmall (14 sp, onSurface), 6 dp, and the time in bodyMedium (14 sp,
    onSurfaceVariant) at the end; 6 dp to the title (titleMedium 16 sp,
    onSurface); 2 dp to the content (bodyLarge 16 sp, onSurfaceVariant).
    Container, padding and ripple as \l Card.
*/
Card {
    id: appCard

    property string appName: ""
    /*! An icon name for the app image (18 dp). */
    property string appIcon: ""
    property string time: ""
    property string title: ""
    property string text: ""
    /*! Lines of content before the ellipsis. */
    property int maximumLineCount: 5

    Accessible.name: appName + " " + title

    Item {
        id: header
        width: parent.width
        height: Math.max(appImage.height, nameLabel.implicitHeight, timeLabel.implicitHeight)
        Icon {
            id: appImage
            visible: appCard.appIcon !== ""
            name: appCard.appIcon
            width: visible ? Theme.dp(18) : 0
            height: width
            color: Theme.color.onSurface
            anchors.verticalCenter: parent.verticalCenter
        }
        Label {
            id: nameLabel
            anchors {
                left: appImage.right
                leftMargin: appImage.visible ? Theme.dp(4) : 0
                right: timeLabel.left
                rightMargin: Theme.space.s
                verticalCenter: parent.verticalCenter
            }
            text: appCard.appName
            role: "titleSmall"
            color: Theme.color.onSurface
            maximumLineCount: 1
        }
        Label {
            id: timeLabel
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            width: Math.min(implicitWidth, parent.width / 2)
            text: appCard.time
            role: "bodyMedium"
            color: Theme.color.onSurfaceVariant
            maximumLineCount: 1
        }
    }
    Item { width: 1; height: Theme.space.s; visible: titleLabel.visible }
    Label {
        id: titleLabel
        width: parent.width
        visible: text !== ""
        text: appCard.title
        role: "titleMedium"
        color: Theme.color.onSurface
        wrapMode: Text.Wrap
        maximumLineCount: 3
    }
    Item { width: 1; height: Theme.dp(2); visible: contentLabel.visible }
    Label {
        id: contentLabel
        width: parent.width
        visible: text !== ""
        text: appCard.text
        role: "bodyLarge"
        color: Theme.color.onSurfaceVariant
        wrapMode: Text.Wrap
        maximumLineCount: appCard.maximumLineCount
    }
}
