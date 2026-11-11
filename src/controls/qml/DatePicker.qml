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
    \qmltype DatePicker
    \inqmlmodule org.asteroid.controls

    \brief The Wear OS Material 3 date picker (E17), for Settings' Set date
    and setup.

    Stock CP3A (androidx.wear.compose.material3 DatePicker; DatePickerKt.java,
    DatePickerState.java, DatePickerTokens.java):
    \list
    \li Column order from the locale's date format: the first of d / M / y;
        M: month-day-year, y: year-month-day, else day-month-year
        (DatePickerKt.java:91, DateFormat.getDateFormatOrder; here the
        locale's short date format).
    \li Range 1900-01-01 .. 2100-12-31 (DatePickerKt.java:142-144). Day
        two digits and month repeat; the year (four digits) does not
        (DatePickerKt.java:146-148). Month: the locale's short name.
    \li The day column has the month's days. While the month or year column
        shows a shorter month, the days past its end are drawn in OnSurface
        at 38 %; once no column scrolls, the day moves to the last valid one
        and the column takes the new month's length
        (DatePickerKt$DatePicker$3$1.java:40, DatePickerState.java:42-64).
    \li Heading "Day" / "Month" / "Year" (wear_m3c_date_picker_*), columns
        8 dp apart (Lambda11.java:343), no separators; day 2 x the widest
        digit + 1 dp, month the widest short name + 1 dp, year 4 digits + 1 dp,
        each at least 48 dp (Lambda7.java:163-181); the focused column is
        centred (PickerGroup autoCenter), so a row wider than the screen
        shows the column being set.
    \li Edge button: Next (arrow, SurfaceContainer / Primary) until the last
        column has the focus, then Confirm (check, PrimaryDim / OnPrimary),
        disabled while the day is invalid (DatePickerKt$$ExternalSyntheticLambda4.java:260, 363).
    \endlist

    \qml
    DatePicker {
        anchors.fill: parent
        date: new Date()
        onConfirmed: (y, m, d) => setDate(y, m, d)
    }
    \endqml
*/
PickerGroup {
    id: dp

    /*! The date shown at first. */
    property date date: new Date()
    /*! The locale (column order, month names). */
    property var locale: Qt.locale()
    /*! The stock range. */
    readonly property int minimumYear: 1900
    readonly property int maximumYear: 2100

    /*! "dmy", "mdy" or "ymd" (from the locale). */
    readonly property string order: {
        var f = locale ? locale.dateFormat(Locale.ShortFormat) : "d/M/y"
        for (var i = 0; i < f.length; i++) {
            var c = f.charAt(i)
            if (c === "M") return "mdy"
            if (c === "y") return "ymd"
            if (c === "d") return "dmy"
        }
        return "dmy"
    }

    /*! The date picked now. */
    readonly property int selectedYear: minimumYear + _v("y")
    readonly property int selectedMonth: _v("m") + 1
    readonly property int selectedDay: _v("d") + 1
    /*! Days in the month picked now. */
    readonly property int monthLength: daysInMonth(selectedYear, selectedMonth)
    /*! The day picked now exists in that month. */
    readonly property bool dayValid: selectedDay <= monthLength

    /*! Confirm was pressed (month 1-12). */
    signal confirmed(int year, int month, int day)
    onAccepted: if (dayValid) confirmed(selectedYear, selectedMonth, selectedDay)

    function daysInMonth(y, m) { return new Date(y, m, 0).getDate() }

    /*! Moves the columns to \a d. */
    function setDate(d, animate) {
        var y = Math.max(minimumYear, Math.min(maximumYear, d.getFullYear()))
        _dayCount = daysInMonth(y, d.getMonth() + 1)
        setValue(order.indexOf("y"), y - minimumYear, animate)
        setValue(order.indexOf("m"), d.getMonth(), animate)
        setValue(order.indexOf("d"), d.getDate() - 1, animate)
    }

    function _v(key) {
        var i = order.indexOf(key)
        return values && values[i] !== undefined ? values[i] : 0
    }
    // the day column's length: the month shown when it last settled
    property int _dayCount: daysInMonth(date.getFullYear(), date.getMonth() + 1)

    autoCenter: true
    nextButton: true
    // columns without the focus: PrimaryDim, not TimePicker's SecondaryDim
    // (DatePickerTokens.java UnselectedContentColor = PrimaryDim, used at
    // DatePickerKt.java:97 inactivePickerContentColor)
    unselectedColor: Theme.color.primaryDim
    confirmFocusable: false
    confirmEnabled: dayValid
    separatorText: ""
    columnSpacing: Theme.dp(8)

    readonly property var _monthNames: {
        var a = []
        for (var i = 0; i < 12; i++)
            a.push(locale ? locale.monthName(i, Locale.ShortFormat) : String(i + 1))
        return a
    }
    columns: {
        var self = dp
        var specs = {
            d: { label: qsTr("Day"), count: function() { return self._dayCount }, repeat: true, width: function() { return self.digitsWidth(2) },
                 text: function(o) { var v = o + 1; return v < 10 ? "0" + v : String(v) },
                 invalid: function(o) { return o + 1 > self.monthLength },
                 initial: function() { return self.date.getDate() - 1 } },
            m: { label: qsTr("Month"), count: 12, repeat: true, width: function() { return self.textsWidth(self._monthNames) },
                 text: function(o) { return self._monthNames[o] },
                 initial: function() { return self.date.getMonth() } },
            y: { label: qsTr("Year"), count: maximumYear - minimumYear + 1, repeat: false, width: function() { return self.digitsWidth(4) },
                 text: function(o) { return String(self.minimumYear + o) },
                 initial: function() { return Math.max(0, Math.min(self.maximumYear - self.minimumYear, self.date.getFullYear() - self.minimumYear)) } }
        }
        return [specs[order.charAt(0)], specs[order.charAt(1)], specs[order.charAt(2)]]
    }

    // stock adjustDayOptionIfInvalid once nothing scrolls: glide to the last
    // valid day, then the column takes the month's length
    function _adjustDay() {
        if (scrolling)
            return
        var p = pickerAt(order.indexOf("d"))
        if (!p)
            return
        if (selectedDay > monthLength) {
            p.scrollToOption(monthLength - 1, true)
            return
        }
        if (_dayCount !== monthLength)
            _dayCount = monthLength
    }
    onScrollingChanged: if (!scrolling) Qt.callLater(_adjustDay)
    onValuesChanged: if (!scrolling) Qt.callLater(_adjustDay)
    onDateChanged: if (_done) setDate(date)
    property bool _done: false
    Component.onCompleted: _done = true
}
