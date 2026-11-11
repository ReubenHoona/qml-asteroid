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
    \qmltype NumberPicker
    \inqmlmodule org.asteroid.controls

    \brief The stock number picker dialog content (E18): a title, one or
    more \l Picker columns and a Confirm edge button; with \l duration, an
    hours, minutes, seconds picker (the timer).

    Stock CP3A (Settings v2 ui/composable/dialog/NumberPickerDialogKt.java,
    HeightPickerDialogKt.java, WeightPickerDialogKt.java; Clock dhq.java:
    250-254, fpv.java:2676-2678, 3100-3102):
    \list
    \li The title 14 dp from the top, a plain Text in bodySmall (12 sp)
        with the default content colour (white, OnBackground), centred, on its
        own line height (NumberPickerDialogKt$$ExternalSyntheticLambda1.java:
        64, 88); the column(s) fill the rest with 4 dp of vertical padding
        (:89); a 56 dp edge button in the default button colours, Primary /
        OnPrimary (:136, EdgeButtonKt.java:146-153, FilledButtonTokens.java:6),
        with a 24 dp check, named "Confirm".
    \li The options are a plain Text in displaySmall (24 sp, weight 500, no
        tabular digits) in the default content colour
        (NumberPickerDialogKt$$ExternalSyntheticLambda4.java:25), sized to
        their line (26 sp) with stock Picker's default spacing of 0
        (PickerKt.java:235-236). The single column is always the crown's.
    \li Height and weight use two columns (\l columns with two entries).
    \li \l duration: columns hour (0-23), minute, second (two digits,
        repeating, ":" between, 2 dp each side) and the heading is the
        focused column: "Hour", "Minute", "Second".
    \endlist

    \qml
    NumberPicker {
        anchors.fill: parent
        title: qsTr("Weight")
        count: 300
        value: 70
        textFor: function(o) { return o + " kg" }
        onConfirmed: (values) => save(values[0])
    }
    \endqml
*/
PickerGroup {
    id: np

    /*! Hours, minutes, seconds (the heading follows the focus). */
    property bool duration: false
    /*! One column: number of options, the option shown first, its text. */
    property int count: 100
    property int value: 0
    property var textFor: null
    /*! One column: the options repeat. */
    property bool repeatItems: false
    /*! Duration: the time shown first. */
    property int hours: 0
    property int minutes: 0
    property int seconds: 0

    /*! The duration picked now, in seconds. */
    readonly property int selectedSeconds: duration
        ? (values[0] || 0) * 3600 + (values[1] || 0) * 60 + (values[2] || 0) : 0
    /*! The value picked now (one column). */
    readonly property int selectedValue: values[0] || 0

    /*! Confirm was pressed: the option of each column. */
    signal confirmed(var values)
    onAccepted: confirmed(values.slice())

    title: ""
    separatorPadding: Theme.dp(2)

    // the Settings number picker dialog style (not the duration picker,
    // which is the Clock timer's TimePicker style)
    headingRole: duration ? "titleMedium" : "bodySmall"
    headingColor: duration ? Theme.color.primary : Theme.color.onBackground
    headingHeight: duration ? Theme.dp(24) : Theme.type.bodySmall.lineHeight
    headingSide: duration ? Theme.dp(Math.ceil(Theme.screenWidthDp * 30 / 100)) : 0
    optionRole: duration ? "numeralSmall" : "displaySmall"
    optionHeight: duration ? Theme.dp(36) : Theme.type.displaySmall.lineHeight
    optionSpacing: duration ? Theme.dp(4) : 0
    optionFeatures: duration ? Theme.tabularNumerals : ({})
    unselectedColor: duration ? Theme.color.secondaryDim : Theme.color.onBackground
    confirmFocusable: duration
    confirmContainerColor: duration ? Theme.color.primaryDim : Theme.color.primary
    confirmContentColor: Theme.color.onPrimary
    separatorText: duration ? ":" : ""
    columnSpacing: Theme.dp(8)

    columns: {
        var self = np
        if (duration)
            return [twoDigitColumn(qsTr("Hour"), 24, function() { return self.hours }),
                    twoDigitColumn(qsTr("Minute"), 60, function() { return self.minutes }),
                    twoDigitColumn(qsTr("Second"), 60, function() { return self.seconds })]
        return [{ label: title, count: count, repeat: repeatItems,
                  width: function() { return self.width - 2 * Theme.dp(8) },
                  text: textFor, initial: function() { return self.value } }]
    }
}
