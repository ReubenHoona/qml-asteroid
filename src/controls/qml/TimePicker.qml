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
    \qmltype TimePicker
    \inqmlmodule org.asteroid.controls

    \brief The Wear OS Material 3 time picker (E16), for Settings' Set time,
    alarms, the timer and setup.

    Stock CP3A (androidx.wear.compose.material3 TimePicker; TimePickerKt.java
    and $$ExternalSyntheticLambda6.java, PickerLocaleConfig.java):
    \list
    \li \l type "auto" (stock's default): 24 hours when the system format is
        24 h (TimeFormat.use24h, from /org/asteroidos/settings/use-12h-format),
        else hours (01-12), minutes and the period (TimePickerKt.java:445).
        "24h", "12h", and "hms" (hours, minutes, seconds; the timer) force one.
    \li Hours and minutes repeat; the period (the locale's AM/PM text, or
        "AM"/"PM" when that does not fit) does not, and comes first where the
        locale writes the marker first.
    \li Heading = the focused column: "Hour", "Minute", "Second", "Period"
        (wear_m3c_time_picker_*); empty on the confirm button.
    \li ":" separators 12 dp wide in OnSurfaceVariant with 8 dp each side
        (24 h) or 2 dp (12 h, h:m:s); beside the period the pattern's space,
        as wide.
    \li Two digit columns 2 x the widest digit + 1 dp, at least 48 dp.
    \li Focus starts on the first column; tap another to focus it, tap the
        focused one to move right, then to the confirm button; the crown
        turns the focused column; Confirm (56 dp, PrimaryDim with a 24 dp
        OnPrimary check) confirms from any focus.
    \endlist

    \qml
    TimePicker {
        anchors.fill: parent
        hour: 7; minute: 30
        onConfirmed: (h, m, s) => alarm.set(h, m)
    }
    \endqml
*/
PickerGroup {
    id: tp

    /*! "auto", "24h", "12h" or "hms". */
    property string type: "auto"
    /*! The time shown at first (0-23, 0-59, 0-59); setting one later moves there. */
    property int hour: 0
    property int minute: 0
    property int second: 0
    /*! The locale (period texts, marker position). */
    property var locale: TimeFormat.locale

    readonly property bool twelveHour: type === "12h" || (type === "auto" && !TimeFormat.use24h)
    readonly property bool withSeconds: type === "hms"
    readonly property bool periodFirst: twelveHour && TimeFormat.markerFirst

    /*! The time picked now. */
    readonly property int selectedHour: {
        var h = _v("hour")
        if (!twelveHour)
            return h
        return ((h + 1) % 12) + 12 * _v("period")
    }
    readonly property int selectedMinute: _v("minute")
    readonly property int selectedSecond: withSeconds ? _v("second") : 0

    /*! Confirm was pressed. */
    signal confirmed(int hour, int minute, int second)
    onAccepted: confirmed(selectedHour, selectedMinute, selectedSecond)

    /*! Moves the columns to \a h : \a m : \a s. */
    function setTime(h, m, s, animate) {
        var o = _options(h, m, s || 0)
        for (var i = 0; i < _keys.length; i++)
            setValue(i, o[_keys[i]], animate)
    }

    readonly property var _keys: {
        var k = withSeconds ? ["hour", "minute", "second"] : ["hour", "minute"]
        if (twelveHour)
            k = periodFirst ? ["period"].concat(k) : k.concat(["period"])
        return k
    }
    function _v(key) {
        var i = _keys.indexOf(key)
        return i >= 0 && values && values[i] !== undefined ? values[i] : 0
    }
    function _options(h, m, s) {
        h = ((h % 24) + 24) % 24
        // 12 h: options 0..11 are 1..12 (PickerLocaleConfig hourValueOffset 1)
        return { hour: twelveHour ? (h + 11) % 12 : h, minute: m, second: s, period: h >= 12 ? 1 : 0 }
    }

    // stock: the locale's AM/PM text, or "AM"/"PM" when it is wider than the
    // room left by the two digit columns and separators (Lambda6.java:213-216)
    readonly property var _periodTexts: {
        var am = locale ? locale.amText : "AM", pm = locale ? locale.pmText : "PM"
        var room = width / Theme.density - ((separatorPadding / Theme.density * 2 + 12) * 2) - 2 * digitsWidth(2) / Theme.density
        if ((Math.max(textWidth(am), textWidth(pm)) / Theme.density + 1) > room && width > 0)
            return ["AM", "PM"]
        return [am, pm]
    }

    separatorPadding: (twelveHour || withSeconds) ? Theme.dp(2) : Theme.dp(8)
    columns: {
        var self = tp
        var specs = {
            hour: twelveHour
                ? { label: qsTr("Hour"), count: 12, repeat: true, width: function() { return self.digitsWidth(2) },
                    text: function(o) { var v = o + 1; return v < 10 ? "0" + v : String(v) },
                    initial: function() { return self._options(self.hour, self.minute, self.second).hour } }
                : twoDigitColumn(qsTr("Hour"), 24, function() { return self._options(self.hour, 0, 0).hour }),
            minute: twoDigitColumn(qsTr("Minute"), 60, function() { return self.minute }),
            second: twoDigitColumn(qsTr("Second"), 60, function() { return self.second }),
            period: { label: qsTr("Period"), count: 2, repeat: false,
                      width: function() { return self.textsWidth(self._periodTexts) },
                      text: function(o) { return self._periodTexts[o] },
                      initial: function() { return self.hour >= 12 ? 1 : 0 } }
        }
        var out = []
        for (var i = 0; i < _keys.length; i++) {
            var c = specs[_keys[i]]
            // the locale pattern's space beside the period ("h:mm a") is a
            // separator part too: same width and padding, no glyph
            if (i > 0 && (_keys[i] === "period" || _keys[i - 1] === "period"))
                c.separatorBefore = " "
            out.push(c)
        }
        return out
    }

    property bool _done: false
    Component.onCompleted: _done = true
    onHourChanged: if (_done) setTime(hour, minute, second)
    onMinuteChanged: if (_done) setTime(hour, minute, second)
    onSecondChanged: if (_done) setTime(hour, minute, second)
}
