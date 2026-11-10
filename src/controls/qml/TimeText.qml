/*
 * Copyright (C) 2026 Reuben Horner <reubarb.scons@gmail.com>
 * SPDX-License-Identifier: BSD-3-Clause
 */

import QtQuick
import QtQuick.Shapes
import org.asteroid.utils

/*!
    \qmltype TimeText
    \inqmlmodule org.asteroid.controls

    \brief The time, curved along the top edge of a round screen.

    Wear OS shows the time at the top of every screen, its letters set on
    the arc of the screen's edge (M3 TimeText). Put one on top of a page:

    \qml
    TimeText { }
    \endqml

    It fills its parent and draws only the few letters of the time, each a
    small Text item turned to the tangent of the circle, over one black arc
    band (85 %); on a rectangular screen the time is a straight line at the
    top. The clock ticks once a minute and only while the item is visible,
    so a still screen with the time on it draws one frame a minute.

    As stock (TimeTextKt.java:89-91,130, TimeTextDefaults.java:16-20):
    \list
    \li the text is \l TimeFormat pattern A, the locale's best "h:mm" or
        "HH:mm" with the AM/PM marker removed: "1:05" in 12 hour mode;
    \li type arcMedium (15 sp, line 18 sp, weight 599, width 90, tracking
        0.6 sp), colour onBackground at tone 80 (\c{Theme.color.timeText});
    \li 2 dp from the screen edge (letter centres 22 px from it on the
        Pixel Watch 2), at most 70 degrees of the circle.
    \endlist
*/
Item {
    id: timeText

    /*! The text shown; the time (TimeFormat.clock: "1:05" / "13:05") by default */
    property string text: TimeFormat.clock(_clock.time)
    /*! The text colour: onBackground at tone 80 */
    property color color: Theme.color.timeText
    /*! The band drawn behind the letters: black at 85 % */
    property color backgroundColor: Theme.color.timeTextScrim
    /*! Letter size in pixels: arcMedium, 15 sp */
    property real pixelSize: Theme.type.arcMedium.pixelSize
    /*! The line (and band) height in pixels: arcMedium, 18 sp */
    property real lineHeight: Theme.type.arcMedium.lineHeight
    /*! Distance of the band from the edge of the screen: 2 dp */
    property real edgeMargin: Theme.space.xxs
    /*! The widest the text may be, in degrees of the circle: 70 */
    property real maxSweep: Theme.size.timeTextSweep

    anchors.fill: parent
    enabled: false

    WallClock {
        id: _clock
        enabled: timeText.visible
        updateFrequency: WallClock.Minute
    }

    readonly property var _role: Theme.type.arcMedium
    readonly property bool _round: DeviceSpecs.hasRoundScreen
    // the middle of the band and of the letters
    readonly property real _radius: Math.min(width, height) / 2 - edgeMargin - lineHeight / 2
    readonly property var _chars: text.split("")
    // static Noto Sans instances: the role weight and width as a style name
    // (wdth 90 ~ SemiCondensed); a variable font reads the axes instead
    readonly property string _styleName: {
        var names = { 100: "Thin", 200: "ExtraLight", 300: "Light", 400: "", 500: "Medium",
                      600: "SemiBold", 700: "Bold", 800: "ExtraBold", 900: "Black" }
        var w = Math.max(100, Math.min(900, Math.round(_role.weight / 100) * 100))
        return ("SemiCondensed " + names[w]).trim()
    }

    // the advance of each letter, as the letters themselves measure it
    // (FontMetrics with the same font gave narrower advances: on the watch
    // the letters of "4:43 PM" ran into each other)
    readonly property var _widths: {
        var widths = []
        for (var i = 0; i < _chars.length; i++) {
            var item = _letters.count > i ? _letters.itemAt(i) : null
            widths.push(item ? item.advance : 0)
        }
        return widths
    }
    // the most the text may take along the arc (70 degrees), pixels
    readonly property real _maxLength: _round ? maxSweep * Math.PI / 180 * _radius : width
    // the letters that fit in the sweep; the rest give way to an ellipsis
    readonly property int _shown: {
        var total = 0
        for (var i = 0; i < _widths.length; i++)
            total += _widths[i]
        if (total <= _maxLength)
            return _widths.length
        var room = _maxLength - _ellipsis.advance
        var t = 0, n = 0
        while (n < _widths.length && t + _widths[n] <= room) {
            t += _widths[n]
            n++
        }
        return n
    }
    readonly property bool _elided: _shown < _chars.length
    // the length of what is drawn and where the middle of each letter sits
    readonly property real _length: {
        var t = 0
        for (var i = 0; i < _shown; i++)
            t += _widths[i]
        return t + (_elided ? _ellipsis.advance : 0)
    }
    readonly property var _mids: {
        var mids = []
        var x = -_length / 2
        for (var j = 0; j < _shown; j++) {
            mids.push(x + _widths[j] / 2)
            x += _widths[j]
        }
        mids.push(x + _ellipsis.advance / 2)
        return mids
    }

    function _angle(along) {
        return _round && _radius > 0 ? along / _radius : 0
    }

    // the band: one arc stroke as long as the text plus 8 px, round ends
    // (the caps are inside that length), black at 85 %
    Shape {
        id: _band
        anchors.fill: parent
        visible: timeText._round && timeText._chars.length > 0 && timeText.backgroundColor.a > 0
        preferredRendererType: Shape.CurveRenderer
        readonly property real visibleLength: timeText._length + 8
        readonly property real arcLength: Math.max(0, visibleLength - timeText.lineHeight)
        ShapePath {
            strokeColor: timeText.backgroundColor
            strokeWidth: timeText.lineHeight
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: timeText.width / 2
                centerY: timeText.height / 2
                radiusX: timeText._radius
                radiusY: timeText._radius
                // degrees, clockwise from 3 o'clock: centred on 12 o'clock
                startAngle: -90 - sweepAngle / 2
                sweepAngle: timeText._radius > 0 ? _band.arcLength / timeText._radius * 180 / Math.PI : 0
            }
        }
    }

    // a square screen: the same band, straight
    Rectangle {
        visible: !timeText._round && timeText._chars.length > 0
        width: timeText._length + 8
        height: timeText.lineHeight
        radius: height / 2
        x: (timeText.width - width) / 2
        y: timeText.edgeMargin
        color: timeText.backgroundColor
    }

    Repeater {
        id: _letters
        model: timeText._chars.length
        delegate: Text {
            readonly property real advance: implicitWidth
            readonly property real along: timeText._mids[index] !== undefined ? timeText._mids[index] : 0
            // radians from the top of the circle; straight on a square screen
            readonly property real angle: timeText._angle(along)
            visible: index < timeText._shown
            text: timeText._chars[index] !== undefined ? timeText._chars[index] : ""
            color: timeText.color
            font.family: Theme.fontFamily
            font.pixelSize: timeText.pixelSize
            font.weight: timeText._role.weight
            font.styleName: timeText._styleName
            font.letterSpacing: timeText._role.letterSpacing
            font.variableAxes: timeText._role.axes
            x: timeText.width / 2 + (timeText._round ? timeText._radius * Math.sin(angle) : along) - width / 2
            y: timeText._round
               ? timeText.height / 2 - timeText._radius * Math.cos(angle) - height / 2
               : timeText.edgeMargin + timeText.lineHeight / 2 - height / 2
            rotation: angle * 180 / Math.PI
        }
    }

    Text {
        id: _ellipsis
        readonly property real advance: implicitWidth
        readonly property real along: timeText._mids.length > 0 ? timeText._mids[timeText._mids.length - 1] : 0
        readonly property real angle: timeText._angle(along)
        visible: timeText._elided
        text: "…"
        color: timeText.color
        font.family: Theme.fontFamily
        font.pixelSize: timeText.pixelSize
        font.weight: timeText._role.weight
        font.styleName: timeText._styleName
        font.letterSpacing: timeText._role.letterSpacing
        font.variableAxes: timeText._role.axes
        x: timeText.width / 2 + (timeText._round ? timeText._radius * Math.sin(angle) : along) - width / 2
        y: timeText._round
           ? timeText.height / 2 - timeText._radius * Math.cos(angle) - height / 2
           : timeText.edgeMargin + timeText.lineHeight / 2 - height / 2
        rotation: angle * 180 / Math.PI
    }
}
