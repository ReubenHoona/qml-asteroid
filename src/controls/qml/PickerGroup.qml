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
    \qmltype PickerGroup
    \inqmlmodule org.asteroid.controls

    \brief The frame shared by the stock M3 time, date and number pickers:
    a heading, a row of \l Picker columns with one focused, and the edge
    button.

    Stock CP3A (androidx.wear.compose.material3 TimePicker / DatePicker,
    Settings decomp; small screen, 2 px per dp here):
    \list
    \li Heading: the focused column's name in titleMedium, Primary, in a
        24 dp band under 14 dp of top padding, 30 % of the screen width
        (ceil, in dp) of side padding (TimePickerKt.java:711-712,
        TimePickerKt$$ExternalSyntheticLambda6.java:233). Empty while the
        confirm button has the focus.
    \li 4 dp of vertical padding above and below the columns (Lambda6
        sectionVerticalPadding).
    \li The first column has the focus. A tap on another column (or a drag
        of it) focuses it; a tap on the focused column moves the focus right;
        after the last one the focus goes to the confirm button
        (\l confirmFocusable) or stays (DatePicker, with its Next button).
    \li The crown turns the focused column only (\c rotaryTarget, read by
        RotaryInput).
    \li Edge button 56 dp: Confirm, a 24 dp check, PrimaryDim / OnPrimary
        (EdgeButtonKt.java:147, TimePickerKt.java:784, TimePickerTokens);
        with \l nextButton, Next (an arrow, SurfaceContainer / Primary) until
        the last column has the focus (DatePickerTokens). Disabled: OnSurface
        at 12 % / 38 %.
    \endlist

    In a Material 2 application (\c{Theme.materialVersion} 2) the group
    takes the Clock's picker of the Wear OS 6 emulator (S28-c Timer, S29-c
    Alarm):
    \list
    \li heading secondary #FDE293 (titleMedium, weight 500);
    \li the focused column's value and its neighbours in secondary
        #FDE293: the column 200 px tall from y 61 to 262 (S29-c at rest:
        the 33 % fades run from y 62 to 128 and from 196 to 262), the
        selected value 2.5 dp under its centre (cap rows 141-184), the
        neighbours 68 px away (34 dp pitch: 32 dp options, 2 dp apart) at
        0.89 x 0.75 scale ('06' x 41-97, rows 79-111 under '07' x 37-100,
        rows 141-184);
    \li the other columns only their value, in #FFFFFF (onBackground), no
        neighbours;
    \li separators #FFFFFF; options weight 400 (\l optionWeight);
    \li a round 52 dp filled button (\l roundConfirm) centred 8.5 dp above
        the bottom (the disc y 263-366, between S28-c's 262-365 and S29-c's
        264-367; x 140-243) in place of the edge button:
        \l confirmContainerColor (Material 2 primary #AECBFA; the Timer and
        the Alarm set #FFFFFF) with an onPrimary #303133 26 dp check (ink
        34 x 25 px).
    \endlist

    \l columns is a list of column descriptions:
    \c{{ label, count, repeat, width, text: function(option),
    invalid: function(option), initial: function(), separatorBefore }}; \c count and \c width may be functions (read in
    the column's own bindings, so a change does not rebuild the row). Between two columns
    sits \l separatorText (":") \l separatorWidth wide with
    \l separatorPadding on each side, or with no separator text a
    \l columnSpacing gap.
*/
Item {
    id: group

    /*! The column descriptions (see above). */
    property var columns: []
    /*! The focused column; \c columns.length is the confirm button. */
    property int focusIndex: 0
    /*! The focus moves to the confirm button after the last column. */
    property bool confirmFocusable: true
    /*! A Next button until the last column has the focus. */
    property bool nextButton: false
    /*! The edge button can be pressed. */
    property bool confirmEnabled: true
    /*! The row moves so the focused column is at the centre (stock
        PickerGroup autoCenter, on in DatePicker: DatePickerKt$$ExternalSyntheticLambda7.java:239);
        off: the row is centred. */
    property bool autoCenter: false
    /*! A fixed heading (NumberPicker's title); empty: the focused column's name. */
    property string title: ""

    /*! Text between two columns. */
    property string separatorText: ":"
    /*! Width of the separator: 12 dp. */
    property real separatorWidth: Theme.dp(12)
    /*! Space each side of the separator: 8 dp (2 columns) or 2 dp. */
    property real separatorPadding: Theme.dp(8)
    /*! Gap between columns without a separator. */
    property real columnSpacing: 0

    /*! Heading geometry (px): 14 dp from the top, a 24 dp band, 30 % side
        padding (time and date pickers). */
    readonly property real headingTop: Theme.dp(14)
    property real headingHeight: Theme.dp(24)
    property real headingSide: Theme.dp(Math.ceil(Theme.screenWidthDp * 30 / 100))
    readonly property bool _m2: Theme.materialVersion === 2

    /*! Heading type role and colour: titleMedium in Primary (TimePickerTokens /
        DatePickerTokens LabelTypography, LabelColor); secondary in Material 2. */
    property string headingRole: "titleMedium"
    property color headingColor: _m2 ? Theme.color.secondary : Theme.color.primary
    /*! The heading's shift from its band (px): 4 dp up in Material 2 (the
        Clock's 'Hour' cap at y 31-53 on S28-c and S29-c; in the band it is
        at 39-61). The columns keep their place. */
    property real headingOffset: _m2 ? -Theme.dp(4) : 0

    /*! The columns' option style (see \l Picker): role, height, spacing,
        OpenType features. */
    property string optionRole: "numeralSmall"
    property real optionHeight: _m2 ? Theme.dp(32) : Theme.dp(36)
    property real optionSpacing: _m2 ? Theme.dp(2) : Theme.dp(4)
    property var optionFeatures: Theme.tabularNumerals
    /*! The options' weight; 0: the role's. 400 in Material 2 (the Clock's
        regular digits, whatever the role). */
    property int optionWeight: _m2 ? 400 : 0
    /*! Option colours: the focused column OnBackground; the others
        SecondaryDim (TimePickerTokens); DatePicker sets PrimaryDim.
        Material 2: secondary and onBackground (#FFFFFF). */
    property color selectedColor: _m2 ? Theme.color.secondary : Theme.color.onBackground
    property color unselectedColor: _m2 ? Theme.color.onBackground : Theme.color.secondaryDim
    /*! The columns without the focus show their neighbours (not in Material 2). */
    property bool unfocusedNeighbours: !_m2
    /*! The separators: OnSurfaceVariant; onBackground (#FFFFFF) in Material 2. */
    property color separatorColor: _m2 ? Theme.color.onBackground : Theme.color.onSurfaceVariant
    /*! The Confirm button colours: PrimaryDim / OnPrimary
        (TimePickerTokens, DatePickerTokens ConfirmButton*); Material 2
        primary (#AECBFA) / onPrimary (#303133). */
    property color confirmContainerColor: _m2 ? Theme.color.primary : Theme.color.primaryDim
    property color confirmContentColor: Theme.color.onPrimary
    /*! A round 52 dp confirm button in place of the edge button (Material 2). */
    property bool roundConfirm: _m2
    /*! The round button's size and its space to the bottom: 52 dp, 8.5 dp. */
    readonly property real roundConfirmSize: Theme.size.iconButton
    readonly property real roundConfirmBottom: Theme.dp(8.5)
    /*! The columns' top and their bottom's distance from the group's
        bottom (px). CP3A: under the heading band and 4 dp over the edge
        button. Material 2 (S29-c): from y 61 (30.5 dp) to y 262 (61 dp
        above the bottom), through the heading band; the fades keep the
        heading clear. The bottom follows the confirm button: 61 dp over
        the round one (52 + 9 dp, \l roundConfirm, also when a Material 3
        picker asks for it), else clear of the edge button. */
    property real columnsTop: _m2 ? Theme.dp(30.5) : headingTop + headingHeight + sectionPadding
    property real columnsBottomMargin: roundConfirm ? Theme.dp(61)
        : sectionPadding + buttonHeight + Theme.size.edgeButtonBottomGap
    /*! Material 2: the neighbours' scale one pitch away (\l Picker) and the
        selected value 2.5 dp under the columns' centre. */
    property real neighbourXScale: _m2 ? 0.89 : -1
    property real neighbourYScale: _m2 ? 0.75 : -1
    property real centerOffset: _m2 ? Theme.dp(2.5) : 0
    /*! Padding above and below the columns: 4 dp. */
    readonly property real sectionPadding: Theme.dp(4)
    /*! Edge button height: 56 dp. */
    readonly property real buttonHeight: Theme.dp(56)

    readonly property int columnCount: columns ? columns.length : 0
    readonly property bool confirmFocused: focusIndex >= columnCount
    readonly property bool lastColumnFocused: focusIndex >= columnCount - 1
    /*! The edge button shows Next now. */
    readonly property bool showsNext: nextButton && !lastColumnFocused
    /*! The heading text now. */
    readonly property string heading: title !== "" ? title
        : confirmFocused || !columns[focusIndex] ? "" : columns[focusIndex].label
    /*! The selected option of each column. */
    property var values: []
    /*! The column the crown turns (null: none). */
    readonly property Item rotaryTarget: {
        var c = _rep.count > 0 && !confirmFocused ? _rep.itemAt(focusIndex) : null
        return c ? c.picker.view : null
    }
    /*! Any column is moving. */
    readonly property bool scrolling: {
        var s = false
        for (var i = 0; i < _rep.count; i++) {
            var c = _rep.itemAt(i)
            if (c && c.picker.scrolling) s = true
        }
        return s
    }

    /*! The edge button was pressed on Confirm. */
    signal accepted()

    /*! The \l Picker of column \a i. */
    function pickerAt(i) {
        var c = _rep.itemAt(i)
        return c ? c.picker : null
    }
    /*! Moves column \a i to \a option. */
    function setValue(i, option, animate) {
        var p = pickerAt(i)
        if (p)
            p.scrollToOption(option, animate === true)
    }
    /*! Moves the focus one step right (to the confirm button after the last). */
    function advance() {
        if (focusIndex < columnCount - 1)
            focusIndex++
        else if (confirmFocusable)
            focusIndex = columnCount
    }
    function _setValue(i, v) {
        var a = values ? values.slice() : []
        while (a.length < columnCount) a.push(0)
        if (a[i] === v)
            return
        a[i] = v
        values = a
    }
    onColumnsChanged: focusIndex = 0

    // widths: stock measures the localized digits in the option style
    FontMetrics {
        id: _fm
        font.family: Theme.fontFamily
        font.pixelSize: (Theme.type[group.optionRole] || Theme.type.numeralSmall).pixelSize
        font.weight: group.optionWeight > 0 ? Theme.weight(group.optionWeight)
            : (Theme.type[group.optionRole] || Theme.type.numeralSmall).weight
        font.features: group.optionFeatures
    }
    /*! The widest of the digits 0-9 in the option style (px). */
    readonly property real widestDigit: {
        var f = _fm.font    // again once the font is set
        var w = 0
        for (var d = 0; d < 10; d++)
            w = Math.max(w, _fm.advanceWidth(String(d)))
        return w
    }
    /*! Width of \a s in the option style (px). */
    function textWidth(s) { return _fm.font.pixelSize > 0 ? _fm.advanceWidth(s) : 0 }
    /*! A column \a digits digits wide: the widest digit x digits + 1 dp,
        at least 48 dp (Lambda6.java:186-211). */
    function digitsWidth(digits) { return Math.max(Theme.dp(48), digits * widestDigit + Theme.dp(1)) }
    /*! A column as wide as the widest of \a texts + 1 dp, at least 48 dp. */
    function textsWidth(texts) {
        var w = 0
        for (var i = 0; i < texts.length; i++)
            w = Math.max(w, textWidth(texts[i]))
        return Math.max(Theme.dp(48), w + Theme.dp(1))
    }
    /*! A two digit numeric column description. */
    function twoDigitColumn(label, count, initial) {
        return { label: label, count: count, repeat: true, width: function() { return group.digitsWidth(2) },
                 text: function(o) { return o < 10 ? "0" + o : String(o) }, initial: initial }
    }

    // stock FadeLabel: the new heading fades in while the old one fades out,
    // on MotionScheme.standard defaultEffects (500, 1.0) (Lambda6.java:229, 248)
    property string _shownHeading: ""
    property string _oldHeading: ""
    onHeadingChanged: {
        _oldHeading = _shownHeading
        _shownHeading = heading
        _headingFade.restart()
    }
    Component.onCompleted: _shownHeading = heading
    NumberAnimation {
        id: _headingFade
        target: _heading
        property: "opacity"
        from: 0; to: 1
        duration: Motion.springDuration(Motion.standard.defaultEffects.stiffness)
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Motion.springEasing
    }
    Label {
        id: _headingOld
        x: _heading.x; y: _heading.y; width: _heading.width; height: _heading.height
        role: group.headingRole
        color: group.headingColor
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: group._oldHeading
        opacity: 1 - _heading.opacity
        visible: opacity > 0
    }
    Label {
        id: _heading
        x: group.headingSide
        y: group.headingTop + group.headingOffset
        width: Math.max(0, group.width - 2 * group.headingSide)
        height: group.headingHeight
        role: group.headingRole
        color: group.headingColor
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: group._shownHeading
    }

    Item {
        id: _area
        y: group.columnsTop
        width: group.width
        height: Math.max(0, group.height - y - group.columnsBottomMargin)

        Row {
            id: _row
            // centred; with autoCenter the focused column sits at the centre
            x: {
                if (group.autoCenter && !group.confirmFocused && _rep.count > group.focusIndex) {
                    var c = _rep.itemAt(group.focusIndex)
                    if (c)
                        return group.width / 2 - (c.x + c.picker.x + c.picker.width / 2)
                }
                return (parent.width - width) / 2
            }
            height: parent.height
            Repeater {
                id: _rep
                model: group.columns
                delegate: Row {
                    id: _col
                    required property var modelData
                    required property int index
                    readonly property alias picker: _picker
                    height: _row.height
                    // the separator before this column: its own text
                    // (separatorBefore: " " beside the period) or the group's
                    readonly property string separator: _col.modelData.separatorBefore !== undefined
                        ? _col.modelData.separatorBefore : group.separatorText
                    Item {
                        visible: _col.index > 0
                        width: _col.separator !== "" ? group.separatorWidth + 2 * group.separatorPadding : group.columnSpacing
                        height: parent.height
                        Label {
                            anchors.centerIn: parent
                            // level with the selected values
                            anchors.verticalCenterOffset: group.centerOffset
                            width: group.separatorWidth
                            visible: _col.separator !== ""
                            text: _col.separator
                            role: "numeralSmall"
                            weight: group.optionWeight
                            color: group.separatorColor
                            horizontalAlignment: Text.AlignHCenter
                            clip: false
                        }
                    }
                    Picker {
                        id: _picker
                        width: typeof _col.modelData.width === "function" ? _col.modelData.width()
                            : (_col.modelData.width || group.digitsWidth(2))
                        height: parent.height
                        count: typeof _col.modelData.count === "function" ? _col.modelData.count() : _col.modelData.count
                        repeatItems: _col.modelData.repeat !== false
                        textFor: _col.modelData.text || null
                        invalidFor: _col.modelData.invalid || null
                        focused: group.focusIndex === _col.index
                        role: group.optionRole
                        optionHeight: group.optionHeight
                        optionSpacing: group.optionSpacing
                        fontFeatures: group.optionFeatures
                        selectedColor: group.selectedColor
                        unselectedColor: group.unselectedColor
                        optionWeight: group.optionWeight
                        showNeighbours: focused || group.unfocusedNeighbours
                        neighbourXScale: group.neighbourXScale
                        neighbourYScale: group.neighbourYScale
                        centerOffset: group.centerOffset
                        Accessible.name: _col.modelData.label
                        Component.onCompleted: {
                            if (_col.modelData.initial)
                                selectedOption = _col.modelData.initial()
                            group._setValue(_col.index, selectedOption)
                        }
                        onSelectedOptionChanged: group._setValue(_col.index, selectedOption)
                        onTapped: {
                            if (group.focusIndex === _col.index)
                                group.advance()
                            else
                                group.focusIndex = _col.index
                        }
                        onTouched: group.focusIndex = _col.index
                    }
                }
            }
        }
    }

    EdgeButton {
        id: _button
        visible: !group.roundConfirm
        preferredHeight: group.buttonHeight
        enabled: group.confirmEnabled
        function _alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
        containerColor: !enabled ? _alpha(Theme.color.onSurface, Theme.alpha.disabledContainer)
            : group.showsNext ? Theme.color.surfaceContainer : group.confirmContainerColor
        contentColor: !enabled ? _alpha(Theme.color.onSurface, Theme.alpha.disabledContent)
            : group.showsNext ? Theme.color.primary : group.confirmContentColor
        Accessible.name: group.showsNext ? qsTr("Next") : qsTr("Confirm")
        Icon {
            anchors.centerIn: parent
            width: Theme.dp(24)
            height: width
            name: group.showsNext ? "ios-arrow-forward" : "ios-checkmark"
            color: _button.contentColor
        }
        onClicked: {
            if (group.showsNext)
                group.advance()
            else
                group.accepted()
        }
    }
    // Material 2: the round confirm button (the Clock's), 8.5 dp above the bottom
    IconButton {
        id: _round
        visible: group.roundConfirm
        size: group.roundConfirmSize
        variant: "filled"
        x: (group.width - width) / 2
        y: group.height - group.roundConfirmBottom - height
        enabled: group.confirmEnabled
        containerColor: !enabled ? _a(Theme.color.onSurface, Theme.alpha.disabledContainer)
            : group.showsNext ? Theme.color.surfaceContainer : group.confirmContainerColor
        iconColor: !enabled ? _a(Theme.color.onSurface, Theme.alpha.disabledContent)
            : group.showsNext ? Theme.color.primary : group.confirmContentColor
        iconName: group.showsNext ? "ios-arrow-forward" : "ms-check"
        function _a(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
        Accessible.name: group.showsNext ? qsTr("Next") : qsTr("Confirm")
        onClicked: {
            if (group.showsNext)
                group.advance()
            else
                group.accepted()
        }
    }
    /*! The edge button (for tests and callers). */
    readonly property alias button: _button
    /*! The round confirm button of the Material 2 picker. */
    readonly property alias roundButton: _round
    /*! The confirm button in use: \l roundButton or \l button. */
    readonly property Item confirmButton: roundConfirm ? _round : _button
    /*! The heading label. */
    readonly property alias headingItem: _heading
    /*! The row of columns. */
    readonly property alias columnsItem: _area
}
