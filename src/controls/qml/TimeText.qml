/*
 * Copyright (C) 2026 Reuben Horner <reubarb.scons@gmail.com>
 * SPDX-License-Identifier: BSD-3-Clause
 */

import QtQuick
import Nemo.Configuration
import org.asteroid.utils

/*!
    \qmltype TimeText
    \inqmlmodule org.asteroid.controls

    \brief The time, curved along the top edge of a round screen.

    Wear OS shows the time at the top of every screen, its letters set on
    the arc of the screen's edge (TimeText). Put one on top of a page:

    \qml
    TimeText { }
    \endqml

    It fills its parent and draws only the few letters of the time, each a
    small Text item turned to the tangent of the circle; on a rectangular
    screen the time is a straight line at the top. The clock ticks once a
    minute and only while the item is visible, so a still screen with the
    time on it draws one frame a minute. The 12/24 hour setting is followed.
*/
Item {
    id: timeText

    /*! The text shown; the time (hh:mm, or h:mm AP) by default */
    property string text: _clock.time.toLocaleString(Qt.locale(), _use12h.value ? "h:mm AP" : "HH:mm")
    /*! The text colour */
    property color color: "#ffffff"
    /*! Letter size in pixels; Wear OS arc small, 14 sp */
    property real pixelSize: Math.round(Math.min(width, height) * 0.073)
    /*! Distance of the letters from the edge of the screen */
    property real edgeMargin: Math.round(Math.min(width, height) * 0.03)

    anchors.fill: parent
    enabled: false

    WallClock {
        id: _clock
        enabled: timeText.visible
        updateFrequency: WallClock.Minute
    }

    ConfigurationValue {
        id: _use12h
        key: "/org/asteroidos/settings/use-12h-format"
        defaultValue: false
    }

    readonly property real _radius: Math.min(width, height) / 2 - edgeMargin - _metrics.ascent * 0.8
    readonly property var _chars: text.split("")

    FontMetrics {
        id: _metrics
        font.pixelSize: timeText.pixelSize
        font.styleName: "SemiCondensed Medium"
    }

    // the advance of each letter and where its middle sits along the arc
    readonly property var _layout: {
        var widths = []
        var total = 0
        for (var i = 0; i < _chars.length; i++) {
            var w = _metrics.advanceWidth(_chars[i])
            widths.push(w)
            total += w
        }
        var mids = []
        var x = -total / 2
        for (var j = 0; j < widths.length; j++) {
            mids.push(x + widths[j] / 2)
            x += widths[j]
        }
        return mids
    }

    Repeater {
        model: timeText._chars.length
        delegate: Text {
            readonly property real along: timeText._layout[index] !== undefined ? timeText._layout[index] : 0
            // radians from the top of the circle; straight on a square screen
            readonly property real angle: DeviceSpecs.hasRoundScreen && timeText._radius > 0 ? along / timeText._radius : 0
            text: timeText._chars[index]
            color: timeText.color
            font.pixelSize: timeText.pixelSize
            font.styleName: "SemiCondensed Medium"
            x: timeText.width / 2 + (DeviceSpecs.hasRoundScreen ? timeText._radius * Math.sin(angle) : along) - width / 2
            y: DeviceSpecs.hasRoundScreen
               ? timeText.height / 2 - timeText._radius * Math.cos(angle) - height / 2
               : timeText.edgeMargin
            rotation: angle * 180 / Math.PI
        }
    }
}
