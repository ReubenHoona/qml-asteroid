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
    \qmltype TitleCard
    \inqmlmodule org.asteroid.controls

    \brief The Wear OS title card (E14): a title row with the time at its
    end, content and an optional subtitle.

    Stock (E14): title titleMedium (16 sp, onSurface), the time in
    bodyMedium (onSurfaceVariant) at the end of the title row 4 dp after the
    title; 2 dp to the content (bodyLarge, onSurfaceVariant); 6 dp to the
    subtitle (labelMedium, tertiary). Container, padding and ripple as
    \l Card.
*/
Card {
    id: titleCard

    property string title: ""
    property string time: ""
    property string text: ""
    property string subtitle: ""
    property int maximumLineCount: 5

    Accessible.name: title

    Item {
        width: parent.width
        height: Math.max(titleLabel.implicitHeight, timeLabel.implicitHeight)
        Label {
            id: titleLabel
            anchors {
                left: parent.left
                right: timeLabel.left
                rightMargin: timeLabel.text !== "" ? Theme.dp(4) : 0
                top: parent.top
            }
            text: titleCard.title
            role: "titleMedium"
            color: Theme.color.onSurface
            wrapMode: Text.Wrap
            maximumLineCount: 3
        }
        Label {
            id: timeLabel
            anchors {
                right: parent.right
                top: parent.top
            }
            width: text !== "" ? Math.min(implicitWidth, parent.width / 2) : 0
            text: titleCard.time
            role: "bodyMedium"
            color: Theme.color.onSurfaceVariant
            maximumLineCount: 1
        }
    }
    Item { width: 1; height: Theme.dp(2); visible: contentLabel.visible }
    Label {
        id: contentLabel
        width: parent.width
        visible: text !== ""
        text: titleCard.text
        role: "bodyLarge"
        color: Theme.color.onSurfaceVariant
        wrapMode: Text.Wrap
        maximumLineCount: titleCard.maximumLineCount
    }
    Item { width: 1; height: Theme.space.s; visible: subtitleLabel.visible }
    Label {
        id: subtitleLabel
        width: parent.width
        visible: text !== ""
        text: titleCard.subtitle
        role: "labelMedium"
        color: Theme.color.tertiary
        maximumLineCount: 1
    }
}
