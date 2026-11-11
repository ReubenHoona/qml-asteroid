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
    \qmltype CircularSpinner
    \inqmlmodule org.asteroid.controls

    \brief A simplified vertical circular spinner, handy for selecting values.

    Creating a vertical spinner to allow the user to select a value from a 
    list is simple with \l CircularSpinner.  A short example is shown below.
    By default, it uses the current index as the data value and pads the number 
    to two digits.  This is particularly convenient for setting times and dates

    \qml
    import QtQuick
    import org.asteroid.controls

    CircularSpinner {
        id: rating
        anchors.centerIn: parent
        width: parent.width * 0.5
        height: parent.height
        model: 10
    }
    \endqml

    A slightly more complex version uses a \l SpinnerDelegate to allow
    a user to select an animal.

    \qml
    import QtQuick
    import org.asteroid.controls

    CircularSpinner {
        id: animals
        anchors.centerIn: parent
        width: parent.width * 0.5
        height: parent.height
        model: 6
        delegate: SpinnerDelegate{
            text: ["aardvark", "bear", "camel", "dog", "elephant", "fox"][index]
        }
    }
    \endqml
*/
PathView {
    /*!
        Kept for older callers; the stock picker has no divider lines, so
        nothing is drawn (dialogs-pickers-feedback-12).
    */
    property bool showSeparator: false
    /*! The stock pitch between options: 36 dp + 4 dp = 80 px. */
    readonly property real pitch: Theme.dp(36) + Theme.dp(4)
    /*! The stock picker fade: the top and bottom 33 % (PickerKt.java:531). */
    property real gradientRatio: 0.33

    id: pv
    preferredHighlightBegin: 0.5
    preferredHighlightEnd: 0.5
    highlightRangeMode: PathView.StrictlyEnforceRange
    // a crown step glides to the next option in about 100 ms (stock snap)
    highlightMoveDuration: Motion.duration(100)
    snapMode: PathView.SnapToItem
    dragMargin: width/2
    clip: true
    delegate: SpinnerDelegate { }
    path: Path {
        startX: pv.width/2; startY: pv.height/2 - pv.count * pv.pitch / 2
        PathLine { x: pv.width/2; y: pv.height/2 + pv.count * pv.pitch / 2 }
    }

    // the stock fade into the background over the top and bottom 33 %
    Rectangle {
        z: 1000
        width: pv.width
        height: pv.height * pv.gradientRatio
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.color.background }
            GradientStop { position: 1; color: "transparent" }
        }
    }
    Rectangle {
        z: 1000
        y: pv.height - height
        width: pv.width
        height: pv.height * pv.gradientRatio
        gradient: Gradient {
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 1; color: Theme.color.background }
        }
    }
}
