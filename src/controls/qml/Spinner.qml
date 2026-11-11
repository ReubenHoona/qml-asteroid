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
import org.asteroid.controls


/*!
    \qmltype Spinner
    \inqmlmodule org.asteroid.controls

    \brief Simple spinner to select values from collection.

    Here is a short that shows a \l Spinner containing three items
    and using a \l SpinnerDelegate to display them.

    \qml
    import QtQuick
    import org.asteroid.controls

    Spinner {
        id: rating
        model: ["Larry", "Moe", "Curly"]
        delegate: SpinnerDelegate{
            text: rating.model[index]
            MouseArea {
                anchors.fill: parent
                onClicked: rating.currentIndex = index
            }
        }
        highlight: Rectangle { color: "orange" }
        highlightFollowsCurrentItem: true
        focus: true
    }
    \endqml
*/
ListView {
    /*!
        Kept for older callers; the stock picker has no divider lines, so
        nothing is drawn (dialogs-pickers-feedback-12).
    */
    property bool showSeparator: false
    /*! The stock picker fade: the top and bottom 33 % (PickerKt.java:531). */
    property real gradientRatio: 0.33

    id: lv
    // the option (36 dp) centred, 4 dp apart: an 80 px pitch
    preferredHighlightBegin: height / 2 - Theme.dp(18)
    preferredHighlightEnd: height / 2 + Theme.dp(18)
    highlightRangeMode: ListView.StrictlyEnforceRange
    highlightMoveDuration: Motion.duration(100)
    highlightMoveVelocity: -1
    spacing: Theme.dp(4)
    clip: true
    delegate: SpinnerDelegate { }

    // the stock fade into the background over the top and bottom 33 %
    // (on the view itself, not its content, so it does not scroll)
    Rectangle {
        parent: lv
        z: 1000
        width: lv.width
        height: lv.height * lv.gradientRatio
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.color.background }
            GradientStop { position: 1; color: "transparent" }
        }
    }
    Rectangle {
        parent: lv
        z: 1000
        y: lv.height - height
        width: lv.width
        height: lv.height * lv.gradientRatio
        gradient: Gradient {
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 1; color: Theme.color.background }
        }
    }
}
