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
    \qmltype Picker
    \inqmlmodule org.asteroid.controls

    \brief One Wear OS Material 3 picker column (E15): the scroll wheel of
    the time, date and number pickers.

    Stock CP3A (androidx.wear.compose.material3 Picker, Settings decomp):
    \list
    \li Options repeat: the list holds many copies of the options and starts
        in the middle (PickerState.java:31-37, 100,000,000 items there; a
        smaller multiple here, which no hand reaches the end of). Set
        \l repeatItems false for a column that does not wrap (AM/PM, year).
    \li Option height 36 dp, spacing 4 dp: an 80 px pitch (\l pitch;
        TimePickerKt$$ExternalSyntheticLambda6.java:117-125, 181).
    \li numeralSmall (30 sp) with tabular digits.
    \li Options scale with their distance from the centre down to 0.45 at
        the edge, over a transition of 45 % of the half height, easing
        CubicBezier(0.25, 0, 0.75, 1), no alpha change (PickerKt.java:538-544;
        SpinnerDelegate does the sums).
    \li The top and bottom 33 % fade into the background (PickerKt.java:531).
    \li A fling ends on an option; a crown step glides to the next option in
        about 100 ms.
    \li Focused column OnBackground (#ffffff), others SecondaryDim (#d1d4e1)
        (TimePickerTokens.java).
    \li No divider lines.
    \endlist

    \qml
    Picker {
        anchors.fill: parent
        count: 60
        selectedOption: 30
        onSelectedOptionChanged: console.log(selectedOption)
    }
    \endqml

    A group of columns with a heading, focus and a confirm button is
    \l PickerGroup (\l TimePicker, \l DatePicker, \l NumberPicker).
*/
Item {
    id: picker

    /*! Number of options. */
    property int count: 1
    /*! The options repeat (wrap) as the column turns. */
    property bool repeatItems: true
    /*! The option at the centre, 0 .. count - 1. Setting it moves there at once. */
    property int selectedOption: 0
    /*! This column is the focused one of its group (colour, crown). */
    property bool focused: true
    /*! function(option) returning the option's text; null: two digits. */
    property var textFor: null
    /*! function(option) returning true for an option that cannot be picked
        now (a day past the month's end): drawn in OnSurface at 38 %. */
    property var invalidFor: null

    /*! Option height: 36 dp (72 px). */
    readonly property real optionHeight: Theme.dp(36)
    /*! Space between options: 4 dp (8 px). */
    readonly property real optionSpacing: Theme.dp(4)
    /*! Option pitch: 80 px. */
    readonly property real pitch: optionHeight + optionSpacing
    /*! Share of the height that fades at the top and at the bottom. */
    property real gradientRatio: 0.33
    /*! Duration of the glide of one crown step (ms). */
    property int stepDuration: 100

    property color selectedColor: Theme.color.onBackground
    property color unselectedColor: Theme.color.secondaryDim
    property color invalidColor: Qt.rgba(Theme.color.onSurface.r, Theme.color.onSurface.g, Theme.color.onSurface.b, Theme.alpha.disabledContent)
    /*! The text colour of the column now. */
    readonly property color contentColor: focused ? selectedColor : unselectedColor

    /*! The view the crown turns (RotaryInput steps it). */
    readonly property alias view: _lv
    /*! A finger or a glide is moving the column. */
    readonly property bool scrolling: _lv.moving || _gliding.running

    /*! The column was tapped. */
    signal tapped()
    /*! A finger started to drag the column. */
    signal touched()

    /*! Copies of the options in the list (1 when they do not repeat). */
    readonly property int cycles: repeatItems ? Math.max(3, Math.floor(100000 / Math.max(1, count))) : 1

    /*! Moves to \a option, gliding when \a animate (as a crown step does). */
    function scrollToOption(option, animate) {
        if (count < 1)
            return
        option = Math.max(0, Math.min(count - 1, option))
        var idx = _indexFor(option)
        if (animate) {
            _lv.currentIndex = idx
        } else {
            _instant = true
            _lv.currentIndex = idx
            _lv.positionViewAtIndex(idx, ListView.Center)
            _instant = false
        }
        if (selectedOption !== option) {
            _syncing = true
            selectedOption = option
            _syncing = false
        }
    }

    property bool _instant: false
    property bool _syncing: false
    property bool _ready: false

    function _mod(i) { return ((i % count) + count) % count }
    function _indexFor(option) {
        var total = count * cycles
        var cur = _lv.currentIndex
        if (!_ready || cur < 0 || cur >= total)
            return Math.floor(cycles / 2) * count + option
        var base = cur - _mod(cur)
        var best = base + option
        if (repeatItems) {
            if (Math.abs(best - count - cur) < Math.abs(best - cur)) best -= count
            if (Math.abs(best + count - cur) < Math.abs(best - cur)) best += count
        }
        return Math.max(0, Math.min(total - 1, best))
    }
    function _fromView() {
        if (!_ready || count < 1 || _lv.currentIndex < 0)
            return
        var o = _mod(_lv.currentIndex)
        if (o !== selectedOption) {
            _syncing = true
            selectedOption = o
            _syncing = false
        }
    }
    onSelectedOptionChanged: if (_ready && !_syncing) scrollToOption(selectedOption, false)
    // the model is (re)built: the middle copy, same option. The model is set
    // here, not bound, so the view resetting its current index to 0 on the
    // new model is not taken for a pick.
    function _reposition() {
        var o = Math.max(0, Math.min(count - 1, selectedOption))
        _ready = false
        _lv.model = Math.max(0, count) * cycles
        if (count < 1)
            return
        _instant = true
        _lv.currentIndex = Math.floor(cycles / 2) * count + o
        _lv.positionViewAtIndex(_lv.currentIndex, ListView.Center)
        _instant = false
        _ready = true
        _fromView()
        if (selectedOption !== o) {
            _syncing = true
            selectedOption = o
            _syncing = false
        }
    }
    property bool _completed: false
    onCountChanged: if (_completed) _reposition()
    onCyclesChanged: if (_completed) _reposition()
    Component.onCompleted: { _completed = true; _reposition() }

    Accessible.role: Accessible.SpinBox
    Accessible.name: textFor ? textFor(selectedOption) : String(selectedOption)

    ListView {
        id: _lv
        anchors.fill: parent
        clip: true
        spacing: picker.optionSpacing
        preferredHighlightBegin: height / 2 - picker.optionHeight / 2
        preferredHighlightEnd: height / 2 + picker.optionHeight / 2
        highlightRangeMode: ListView.StrictlyEnforceRange
        snapMode: ListView.SnapToItem
        highlightMoveDuration: picker._instant ? 0 : Motion.duration(picker.stepDuration)
        highlightMoveVelocity: -1
        boundsBehavior: Flickable.StopAtBounds
        delegate: SpinnerDelegate {
            readonly property int option: picker.count > 0 ? index % picker.count : 0
            readonly property bool invalid: picker.invalidFor ? picker.invalidFor(option) === true : false
            text: picker.textFor ? picker.textFor(option) : zeroPadding(option)
            color: invalid ? picker.invalidColor : picker.contentColor
            // in the delegate, so the view keeps its drags (the view steals
            // the grab past the drag threshold)
            TapHandler {
                onTapped: picker.tapped()
            }
        }
        onCurrentIndexChanged: {
            if (!picker._instant)
                _gliding.restart()
            picker._fromView()
        }
        onMovementStarted: picker.touched()
    }

    // a crown step or a scrollToOption glide is running
    Timer {
        id: _gliding
        interval: Math.max(1, Motion.duration(picker.stepDuration))
    }


    // the stock fade into the background over the top and bottom 33 %
    Rectangle {
        width: picker.width
        height: picker.height * picker.gradientRatio
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.color.background }
            GradientStop { position: 1; color: "transparent" }
        }
    }
    Rectangle {
        y: picker.height - height
        width: picker.width
        height: picker.height * picker.gradientRatio
        gradient: Gradient {
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 1; color: Theme.color.background }
        }
    }
}
