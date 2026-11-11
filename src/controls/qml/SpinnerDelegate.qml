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
    \qmltype SpinnerDelegate
    \inqmlmodule org.asteroid.controls

    \brief Provides a delegate for use with CircularSpinner.

    The SpinnerDelegate is primarily intended to be used with a \l CircularSpinner
    but may also be used with a plain \l ListView or \l PathView.  It is responsible 
    for displaying each value in the list model.  This example shows how a user can 
    select from list of 20 integers.  Here, a \l MouseArea is added to allow the user 
    to select a value.

    \qml
    import QtQuick
    import org.asteroid.controls

    ListView {
        id: rating
        anchors.centerIn: parent
        model: 20
        delegate: SpinnerDelegate{
            MouseArea {
                anchors.fill: parent
                onClicked: rating.currentIndex = index
            }
        }
        highlight: Rectangle { color: "green" }
        highlightFollowsCurrentItem: true
        focus: true
    }
    \endqml

    This somewhat more complex example shows a month and a year \l CircularSpinner 
    each with a \l SpinnerDelegate that overrides the \l SpinnerDelegate::text attribute.

    \qml
    import QtQuick
    import org.asteroid.controls

    Item {
        id: combinationSelector
        anchors.fill: parent 
        Row {
            anchors.fill: parent
            CircularSpinner {
                id: month
                height: parent.height
                width: parent.width/2
                model: 12
                showSeparator: true
                delegate: SpinnerDelegate{ text: Qt.locale().monthName(index, Locale.ShortFormat) }
            }
            CircularSpinner {
                id: year
                height: parent.height
                width: parent.width/2
                model: 100
                showSeparator: false
                delegate: SpinnerDelegate { text: index+2000 }
            }
        }
    }
    \endqml
    
    The effect on a round watch is shown below.
    \image SpinnerExample.jpg "Spinner example screenshot"
*/
Label {
    id: _delegate
    property bool isCircularSpinner: PathView.view !== null
    property bool isCurr: isCircularSpinner ? PathView.isCurrentItem : ListView.isCurrentItem
    width: isCircularSpinner ? PathView.view.width : ListView.view.width
    /*!
        The stock M3 picker option: the numeralSmall line (30 sp) held to
        36..48 dp, so 36 dp (72 px) on this screen; with the 4 dp (8 px)
        spacing a pitch of 80 px (TimePickerKt$$ExternalSyntheticLambda6.java:
        117-125, 181: small screen, optionHeight = line height coerced to
        36..48 dp, optionSpacing 4 dp).
    */
    height: Theme.dp(36)
    function zeroPadding(x) {
        if (x<10) return "0"+x;
        else      return x;
    }
    /*!
        Defaults to a zero-padded two-digit value.
     */
    text: zeroPadding(index)
    /*! numeralSmall (30 sp, weight 599) with tabular digits, as stock
        TimePickerTokens.ContentTypography + "tnum" (Lambda6.java:108). */
    role: "numeralSmall"
    font.features: Theme.tabularNumerals
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter

    /*!
        Stock M3 Picker scaling (PickerKt.java:538-544, a ScalingLazyColumn
        with DefaultScalingParams): edgeScale 0.45, edgeAlpha 1.0 (no fade
        of the option itself), transition area 0.45 of the distance from the
        viewport edge to its centre, scale interpolator
        CubicBezier(0.25, 0, 0.75, 1). The distance is from the option's
        edge nearest the viewport edge.
    */
    property real edgeScale: 0.45
    property real transitionArea: 0.45

    readonly property Item _view: isCircularSpinner ? PathView.view : ListView.view
    // the option's top in the viewport (PathView delegates sit in the view)
    readonly property real _top: !_view ? 0
        : isCircularSpinner ? y : y - _view.contentY
    /*! Distance from the option's nearer edge to the nearer viewport edge (px). */
    readonly property real edgeDistance: !_view ? 0 : Math.min(_top, _view.height - _top - height)
    /*! 0 at or inside the transition line, 1 at the viewport edge. */
    readonly property real scaleProgress: {
        var H = _view ? _view.height : 0
        if (H <= 0)
            return 0
        var line = transitionArea * H / 2
        return 1 - Math.max(0, Math.min(edgeDistance, line)) / line
    }
    // y of CubicBezier(0.25, 0, 0.75, 1) at x = t (bisection on x)
    function _ease(t) {
        if (t <= 0) return 0
        if (t >= 1) return 1
        var lo = 0, hi = 1, s = t
        for (var i = 0; i < 24; i++) {
            s = (lo + hi) / 2
            var x = 3 * (1 - s) * (1 - s) * s * 0.25 + 3 * (1 - s) * s * s * 0.75 + s * s * s
            if (x < t) lo = s
            else hi = s
        }
        return 3 * (1 - s) * s * s + s * s * s
    }
    scale: 1 - _ease(scaleProgress) * (1 - edgeScale)
}
