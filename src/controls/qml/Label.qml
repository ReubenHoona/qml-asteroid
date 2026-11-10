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
   \qmltype Label
   \inqmlmodule org.asteroid.controls

   \brief Provides a way to get a text label sized for AsteroidOS.

   This is a simple wrapper for \l Text that by default has white text in the
   Wear OS bodyLarge type role (\l Theme): 16 sp (32 px) on a fixed 18 sp
   (36 px) line, weight 450, width 90, +0.4 sp tracking. Set \c role to any
   of the 21 type roles (\c titleMedium, \c labelMedium, \c numeralLarge...).
   A caller's own font.pixelSize keeps Qt's natural line spacing and no
   tracking (as before); a caller's proportional lineHeight (a ratio below
   4), font.bold and font.weight keep working.

   Here is a short example that shows some text in a blue rectangle on a yellow background:

    \qml
    import QtQuick
    import org.asteroid.controls

    Rectangle {
        anchors.fill: parent
        color: "yellow"
        Rectangle {
            anchors.centerIn: parent
            width: Dims.w(50)
            height: Dims.h(10)
            color: "blue"

            Label {
                text:"This is a label."
            }
        }
    }
    \endqml

    The result looks like this on a round watch \image labelExample.jpg "label example screen"


*/
Text {
    id: _label

    /*!
        The type role (Theme.type): bodyLarge by default, as stock's
        unstyled text (MaterialThemeKt LocalTextStyle = bodyLarge).
    */
    property string role: "bodyLarge"
    readonly property var _role: Theme.type[role] || Theme.type.bodyLarge
    // the role size (QFont pixel sizes are integers); a caller font.pixelSize means Qt natural
    // line spacing and no tracking, as before the type roles
    readonly property bool _styled: font.pixelSize === Math.round(_role.pixelSize)
    // a fixed line box as stock (GoogleTypographyKt.java:19); a ratio set
    // by a caller (lineHeight: 0.9) keeps the proportional mode
    readonly property bool _lineBox: _styled && lineHeight >= 4

    color: Theme.color.content
    font.family: Theme.fontFamily
    font.pixelSize: _role.pixelSize
    font.letterSpacing: _styled ? _role.letterSpacing : 0
    // wght follows font.weight, so a caller's font.bold keeps working
    font.variableAxes: _styled ? { "wdth": _role.width, "ROND": _role.roundness, "opsz": _role.opsz } : {}
    lineHeightMode: _lineBox ? Text.FixedHeight : Text.ProportionalHeight
    lineHeight: _styled ? _role.lineHeight : 1.0
    // Compose centres the glyphs in the line box; Qt puts the ascent at the
    // top of it. Half the difference above the first line moves every
    // baseline to Compose's place. Nothing is taken off the bottom so the
    // descenders of the last line are not clipped.
    topPadding: _lineBox ? (lineHeight - _metrics.height) / 2 : 0
    elide: Text.ElideRight
    clip: true

    FontMetrics {
        id: _metrics
        font: _label.font
    }

    /*
     * The role weight (with Bold text) is set here rather than bound, so a
     * caller's font.bold or font.weight keeps winning: both write the same
     * QFont weight and a binding would overwrite them. A weight a caller
     * changed is left alone from then on.
     */
    readonly property int _roleWeight: _role.weight
    property int _appliedWeight: -1
    function _applyWeight() {
        if (_appliedWeight === -2)
            return
        var expected = _appliedWeight === -1 ? Font.Normal : _appliedWeight
        if (font.weight !== expected) {
            _appliedWeight = -2
            return
        }
        font.weight = _roleWeight
        _appliedWeight = _roleWeight
    }
    on_RoleWeightChanged: if (_appliedWeight !== -1) _applyWeight()
    Component.onCompleted: _applyWeight()
}
