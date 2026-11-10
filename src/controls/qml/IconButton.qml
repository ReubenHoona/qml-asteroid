/*
 * Copyright (C) 2017 - Florent Revest <revestflo@gmail.com>
 *               2015 - Tim Süberkrüb <tim.sueberkrueb@web.de>
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
    \qmltype IconButton
    \inqmlmodule org.asteroid.controls

    \brief Provides a virtual button with settable icon.

    This control provides a virtual button which can then be used to
    do things via the \l MouseArea::clicked signal

    Set \l size to get the Wear OS Material 3 icon button (E05,
    IconButtonDefaults.java:18,48, FilledIconButtonTokens.java:6-18,
    FilledTonalIconButtonTokens.java:6-18):
    \list
    \li sizes 32 / 48 / 52 / 60 dp (\c{Theme.size.iconButtonExtraSmall},
        \c iconButtonSmall, \c iconButton (default), \c iconButtonLarge);
    \li icon max(24 dp, size / 2), 32 dp from 60 dp up;
    \li a circle that morphs to Theme.shape.small while pressed (fast spring
        12600 in, slow 260 out, IconButtonKt.java:207) with a bounded ripple;
    \li \c variant: \c plain (transparent, primary content), \c filled
        (primary / onPrimary), \c tonal (surfaceContainer / primary),
        \c outlined (transparent, primary, 1 dp outlineVariant border);
    \li disabled: content onSurface 38 %, container onSurface 12 %.
    \endlist

    Without \l size (the default, -1) the button keeps its old look for the
    applications that have not moved yet: a white icon filling a
    Dims.l(20) square that dims to 70 % while pressed.

    Here is an example which displays a blue square filling the screen and a button at
    the bottom of the screen.  When the button is pressed, the square turns green.

    \qml
    import QtQuick
    import org.asteroid.controls

    Rectangle {
        id: square
        color: "blue"
        IconButton {
            iconName: "ios-checkmark-circle-outline"
            size: Theme.size.iconButton
            variant: "filled"
            anchors {
                bottom: parent.bottom
                horizontalCenter: parent.horizontalCenter
                bottomMargin: Dims.iconButtonMargin
            }

            onClicked: {
                square.color = "green"
            }
        }
    }
    \endqml
*/
MouseArea {
    id: iconButton

    /*! The button size in px; -1 keeps the old (pre Material 3) button. */
    property real size: -1
    /*! "plain", "filled", "tonal" or "outlined" (with \l size). */
    property string variant: "plain"
    readonly property bool _m3: size >= 0

    function _a(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    /*! Color of the icon */
    property color iconColor: !_m3 ? "#FFFFFFFF"
        : !enabled ? _a(Theme.color.onSurface, Theme.alpha.disabledContent)
        : variant === "filled" ? Theme.color.onPrimary : Theme.color.primary
    /*! Color of the icon once pressed*/
    property color pressedIconColor: _m3 ? iconColor : "#FFFFFFFF"
    /*! The name of the icon */
    property alias iconName: icon.name
    /*! The container colour (with \l size). */
    property color containerColor: !_m3 ? "transparent"
        : !enabled ? ((variant === "filled" || variant === "tonal") ? _a(Theme.color.onSurface, Theme.alpha.disabledContainer) : "transparent")
        : variant === "filled" ? Theme.color.primary
        : variant === "tonal" ? Theme.color.surfaceContainer : "transparent"
    /*! Icon size: max(24 dp, size / 2), 32 dp from 60 dp. */
    readonly property real iconSize: !_m3 ? width
        : size >= Theme.size.iconButtonLarge ? Theme.size.iconLarge
        : Math.max(Theme.size.iconSmall, size / 2)

    width: _m3 ? size : Dims.l(20)
    height: width

    Accessible.role: Accessible.Button
    Accessible.name: icon.name

    Rectangle {
        id: _container
        visible: iconButton._m3
        anchors.fill: parent
        color: iconButton.containerColor
        border.width: iconButton.variant === "outlined" ? Theme.dp(1) : 0
        border.color: iconButton.enabled ? Theme.color.outlineVariant : iconButton._a(Theme.color.onSurface, Theme.alpha.disabledContainer)
        // circle -> Theme.shape.small while pressed (IconButtonKt.java:207)
        radius: width / 2 + (Theme.shape.small - width / 2) * _morph.value

        WearSpring {
            id: _morph
            to: iconButton.pressed ? 1 : 0
            stiffness: iconButton.pressed ? Motion.pressMorph.press.stiffness : Motion.pressMorph.release.stiffness
            dampingRatio: 1.0
        }

        Ripple {
            radius: _container.radius
            color: iconButton.iconColor
            pressed: iconButton._m3 && iconButton.pressed
            pressX: iconButton.mouseX
            pressY: iconButton.mouseY
        }
    }

    Icon {
        id: icon
        name: "ios-circle-outline"
        anchors.centerIn: parent
        width: iconButton.iconSize
        height: width
        color: pressed ? pressedIconColor : iconColor
        opacity: !iconButton._m3 && iconButton.containsPress ? 0.7 : 1.0
    }
}
