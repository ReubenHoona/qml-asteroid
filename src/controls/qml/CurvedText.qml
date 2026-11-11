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
    \qmltype CurvedText
    \inqmlmodule org.asteroid.controls

    \brief Text along the bottom edge of the round screen, read left to
    right, centred at 6 o'clock (stock CurvedLayout anchor 90 degrees), as
    the confirmation and open-on-phone dialogs show their message.

    The letters sit \l edgeMargin from the screen edge (their bottom). Past
    \l maxSweep degrees the text ends in an ellipsis; \l fits tells whether
    it fits whole. Fill the screen with it (anchors.fill).
*/
Item {
    id: curved

    property string text: ""
    property color color: Theme.color.onBackground
    /*! A Theme type role: arcLarge (18 sp, weight 599) by default. */
    property string role: "arcLarge"
    /*! The widest the text may be, in degrees. */
    property real maxSweep: 120
    /*! Distance of the letters from the screen edge, px. */
    property real edgeMargin: Theme.dp(2)

    readonly property var _role: Theme.type[role] || Theme.type.arcLarge
    readonly property real pixelSize: _role.pixelSize
    readonly property real lineHeight: _role.lineHeight
    /*! The radius of the middle of the letters. */
    readonly property real radius: Math.min(width, height) / 2 - edgeMargin - lineHeight / 2
    readonly property var _chars: text.split("")
    readonly property string _styleName: {
        var names = { 100: "Thin", 200: "ExtraLight", 300: "Light", 400: "", 500: "Medium",
                      600: "SemiBold", 700: "Bold", 800: "ExtraBold", 900: "Black" }
        var w = Math.max(100, Math.min(900, Math.round(_role.weight / 100) * 100))
        return (_role.width < 95 ? "SemiCondensed " + names[w] : names[w]).trim()
    }

    readonly property var _widths: {
        var widths = []
        for (var i = 0; i < _chars.length; i++) {
            var item = _letters.count > i ? _letters.itemAt(i) : null
            widths.push(item ? item.advance : 0)
        }
        return widths
    }
    readonly property real _maxLength: maxSweep * Math.PI / 180 * Math.max(1, radius)
    /*! The whole text along the arc, px. */
    readonly property real naturalLength: {
        var t = 0
        for (var i = 0; i < _widths.length; i++)
            t += _widths[i]
        return t
    }
    /*! The text fits in \l maxSweep without an ellipsis. */
    readonly property bool fits: naturalLength <= _maxLength
    readonly property int _shown: {
        if (fits)
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
    readonly property real _length: {
        var t = 0
        for (var i = 0; i < _shown; i++)
            t += _widths[i]
        return t + (_elided ? _ellipsis.advance : 0)
    }
    /*! The angle the drawn text spans, degrees. */
    readonly property real sweep: radius > 0 ? _length / radius * 180 / Math.PI : 0
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

    component Letter: Text {
        readonly property real advance: implicitWidth
        property real along: 0
        // radians from 6 o'clock, positive to the reader's right
        readonly property real angle: curved.radius > 0 ? along / curved.radius : 0
        color: curved.color
        font.family: Theme.fontFamily
        font.pixelSize: curved.pixelSize
        font.weight: curved._role.weight
        font.styleName: curved._styleName
        font.letterSpacing: curved._role.letterSpacingBottom
        font.variableAxes: curved._role.axes
        x: curved.width / 2 + curved.radius * Math.sin(angle) - width / 2
        y: curved.height / 2 + curved.radius * Math.cos(angle) - height / 2
        rotation: -angle * 180 / Math.PI
    }

    Repeater {
        id: _letters
        model: curved._chars.length
        delegate: Letter {
            visible: index < curved._shown
            text: curved._chars[index] !== undefined ? curved._chars[index] : ""
            along: curved._mids[index] !== undefined ? curved._mids[index] : 0
        }
    }
    Letter {
        id: _ellipsis
        visible: curved._elided
        text: "…"
        along: curved._mids.length > 0 ? curved._mids[curved._mids.length - 1] : 0
    }
}
