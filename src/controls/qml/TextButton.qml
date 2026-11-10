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
    \qmltype TextButton
    \inqmlmodule org.asteroid.controls

    \brief The Wear OS round text button (E06).

    Stock (TextButtonDefaults.java:13, TextButtonTokens.java:12-17,
    FilledTextButtonTokens.java:6-21): a circle 52 dp across by default (48
    and 60 dp too), short text in labelMedium; \c variant \c plain
    (transparent, onSurface), \c filled (primary / onPrimary), \c tonal
    (surfaceContainer / onSurface) or \c outlined (1 dp outlineVariant
    border). Disabled: content onSurface 38 %, container 12 %. Pressed: the
    circle morphs to Theme.shape.small (spring 12600 in, 260 out) with a
    bounded ripple.
*/
MouseArea {
    id: textButton

    /*! The text (a few characters: "OK", "1", "AM"). */
    property string text: ""
    /*! "plain", "filled", "tonal" or "outlined". */
    property string variant: "plain"
    /*! Diameter in px: 52 dp by default (48 and 60 dp are the other sizes). */
    property real size: Theme.dp(52)

    function _a(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    property color contentColor: !enabled ? _a(Theme.color.onSurface, Theme.alpha.disabledContent)
        : variant === "filled" ? Theme.color.onPrimary : Theme.color.onSurface
    property color containerColor: !enabled
        ? ((variant === "filled" || variant === "tonal") ? _a(Theme.color.onSurface, Theme.alpha.disabledContainer) : "transparent")
        : variant === "filled" ? Theme.color.primary
        : variant === "tonal" ? Theme.color.surfaceContainer : "transparent"

    width: size
    height: size

    Accessible.role: Accessible.Button
    Accessible.name: text

    Rectangle {
        id: _container
        anchors.fill: parent
        color: textButton.containerColor
        border.width: textButton.variant === "outlined" ? Theme.dp(1) : 0
        border.color: textButton.enabled ? Theme.color.outlineVariant : textButton._a(Theme.color.onSurface, Theme.alpha.disabledContainer)
        // circle -> Theme.shape.small while pressed (IconButtonKt.java:207)
        radius: width / 2 + (Theme.shape.small - width / 2) * _morph.value

        WearSpring {
            id: _morph
            to: textButton.pressed ? 1 : 0
            stiffness: textButton.pressed ? Motion.pressMorph.press.stiffness : Motion.pressMorph.release.stiffness
            dampingRatio: 1.0
        }

        Ripple {
            radius: _container.radius
            color: textButton.contentColor
            pressed: textButton.pressed
            pressX: textButton.mouseX
            pressY: textButton.mouseY
        }
    }

    Label {
        anchors.centerIn: parent
        width: Math.min(implicitWidth, parent.width)
        text: textButton.text
        role: "labelMedium"
        color: textButton.contentColor
        horizontalAlignment: Text.AlignHCenter
    }
}
