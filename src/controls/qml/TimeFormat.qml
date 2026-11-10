/*
 * Copyright (C) 2026 Reuben Horner <reubarb.scons@gmail.com>
 * SPDX-License-Identifier: BSD-3-Clause
 */

pragma Singleton

import QtQuick
import Nemo.Configuration
import org.asteroid.utils

/*!
    \qmltype TimeFormat
    \inqmlmodule org.asteroid.controls

    \brief The one 12/24 hour time formatter every surface uses.

    Stock Wear OS has one system flag (DateFormat.is24HourFormat) and four
    ways of writing a time with it. Every app here uses this singleton
    instead of its own pattern, so the setting and the locale are followed
    the same way everywhere:

    \list
    \li clock(d), pattern A, no AM/PM: the curved TimeText and Pixel-style
        faces. The locale's best "h:mm" or "HH:mm" with the day period
        removed (M3 TimeTextKt.java:91): "1:05" / "13:05".
    \li time(d), pattern B, with the marker: alarms, tiles, Settings rows,
        notifications, messages, health readings. The locale's "hm" / "Hm"
        (DateFormat.getTimeFormat): "1:05 PM" (en_US), "1:05 pm" (en_GB),
        "13:05".
    \li hour(d), pattern C, hour labels: chart axes and hourly forecasts.
        The locale's "ha" / "H": "6 AM" / "06".
    \li range(a, b), pattern D, a span of time: calendar events. ICU's
        DateIntervalFormat like DateUtils.formatDateRange: "2:30 - 3:30 PM".
    \endlist

    timeParts(d) splits pattern B for screens that draw the marker apart
    (the alarm firing screen). No 12 hour time has a leading zero. The AM/PM
    text and its case come from the locale, never forced.

    The 12/24 hour flag is \c{/org/asteroidos/settings/use-12h-format}
    (Settings > System > Date & time > Use 24-hour format; the image sets
    12 hour, the user's choice). With "Automatic time format"
    (\c{time-format-from-phone}) on, the phone's flag is written into it
    while time sync is on; this singleton only reads.

    Functions are plain bindings: \c{text: TimeFormat.time(clock.time)}
    updates when the setting changes. Nothing runs on its own.
*/
QtObject {
    id: tf

    property ConfigurationValue _use12h: ConfigurationValue {
        key: "/org/asteroidos/settings/use-12h-format"
        defaultValue: false
    }
    property ConfigurationValue _fromPhone: ConfigurationValue {
        key: "/org/asteroidos/settings/time-format-from-phone"
        defaultValue: false
    }

    // the raw key value (tests replace this instead of writing dconf)
    property var _use12hValue: _use12h.value

    /*! True for 24 hour time (use-12h-format false). */
    readonly property bool use24h: !(_use12hValue === true || _use12hValue === "true")
    /*! "Automatic time format": the phone sets the 12/24 hour flag. */
    readonly property bool fromPhone: _fromPhone.value === true

    /*! The locale used; the system locale unless set (tests, previews). */
    property var locale: Qt.locale()
    readonly property string _loc: locale ? locale.name : ""

    /*! Qt format string of pattern A, B and C for the current flag and locale. */
    readonly property string clockFormat: DateFormat.clockPattern(use24h, _loc)
    readonly property string timeFormat: DateFormat.timePattern(use24h, _loc)
    readonly property string hourFormat: DateFormat.hourPattern(use24h, _loc)
    /*! The locale writes the marker before the time ("a h:mm"). */
    readonly property bool markerFirst: DateFormat.markerFirst(_loc)

    function _date(d) {
        return d === undefined || d === null ? new Date() : d
    }

    // Qt's "h" is a 12 hour field only next to an AM/PM field; pattern A
    // has none, so its hour is written as quoted text (1-12, no leading
    // zero unless the locale's pattern has "hh")
    function _hours12(fmt, d) {
        var h = d.getHours() % 12
        if (h === 0)
            h = 12
        var out = "", quoted = false
        for (var i = 0; i < fmt.length; i++) {
            var c = fmt[i]
            if (c === "'") {
                quoted = !quoted
                out += c
                continue
            }
            if (!quoted && c === "h") {
                var n = 1
                while (fmt[i + n] === "h")
                    n++
                i += n - 1
                var s = String(h)
                out += "'" + (n >= 2 && s.length < 2 ? "0" + s : s) + "'"
                continue
            }
            out += c
        }
        return out
    }

    /*! Pattern A: the time with no AM/PM ("1:05", "13:05"). */
    function clock(d) {
        var t = _date(d)
        return t.toLocaleString(locale, use24h ? clockFormat : _hours12(clockFormat, t))
    }

    /*! Pattern B: the time with the locale's marker in 12 hour mode. */
    function time(d) {
        return _date(d).toLocaleString(locale, timeFormat)
    }

    /*! The locale's AM or PM text for \a d; empty in 24 hour mode. */
    function marker(d) {
        if (use24h)
            return ""
        return _date(d).getHours() < 12 ? locale.amText : locale.pmText
    }

    /*! Pattern C: an hour label ("6 AM", "06"). */
    function hour(d) {
        return _date(d).toLocaleString(locale, hourFormat)
    }

    /*!
        Pattern D: a range of times. The marker is written once when both
        share it ("2:30 - 3:30 PM"), on each side otherwise.
    */
    function range(a, b) {
        return DateFormat.formatRange(a, b, use24h ? "Hm" : "hm", _loc)
    }

    /*!
        Pattern B in parts, for screens that draw the marker as its own
        text: { time: "7:30", marker: "AM", markerFirst: false }.
    */
    function timeParts(d) {
        return { time: clock(d), marker: marker(d), markerFirst: markerFirst && !use24h }
    }

    /*!
        A date or time in the locale's own order for a skeleton
        ("MMMd", "EEEMMMd", "yMMMd"...), as getBestDateTimePattern.
    */
    function date(d, skeleton) {
        return DateFormat.format(_date(d), skeleton, _loc)
    }
}
