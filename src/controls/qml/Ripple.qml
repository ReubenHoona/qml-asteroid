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
import QtQuick.Shapes
import org.asteroid.controls

/*!
    \qmltype Ripple
    \inqmlmodule org.asteroid.controls

    \brief The Wear OS bounded press ripple.

    Stock buttons, switch rows, radio rows and slider buttons draw a ripple
    from the touch point in the content colour at 10 % (RippleAlpha
    pressedAlpha 0.1, RippleAlpha.java:17; ButtonKt.java:161,
    SwitchButtonKt.java:301), through the platform RippleDrawable: it grows
    over 450 ms with (0.4, 0, 0.2, 1) and fades out over 375 ms
    (RippleAnimationSession.java:42-48).

    Put it inside the control, above the container and below the content,
    and drive \l pressed and the press point from the control's MouseArea:

    \qml
    MouseArea {
        id: area
        Rectangle { id: box; anchors.fill: parent; radius: 52; color: Theme.color.surfaceContainer }
        Ripple { radius: box.radius; pressed: area.pressed; pressX: area.mouseX; pressY: area.mouseY }
    }
    \endqml

    The ripple is clipped to the control's rounded rectangle by its own
    shape (a radial gradient filling a rounded-rectangle path), so it needs
    no layer, and it is invisible (nothing drawn, no animation) at rest.
*/
Item {
    id: ripple

    anchors.fill: parent
    enabled: false

    /*! Corner radius of the control's shape (clamped to a pill). */
    property real radius: 0
    /*! The content colour; drawn at \l alpha. */
    property color color: Theme.color.content
    /*! The control is pressed. */
    property bool pressed: false
    /*! Where the press started, in this item's coordinates. */
    property real pressX: width / 2
    property real pressY: height / 2

    /*! Ripple alpha: the pressed state alpha, 0.10. */
    readonly property real alpha: Theme.alpha.pressed
    /*! Grow time in ms (RippleAnimationSession: 450 ms). */
    readonly property int growDuration: 450
    /*! Fade-out time in ms (375 ms). */
    readonly property int fadeDuration: 375
    /*! True while the ripple shows or animates. */
    readonly property bool running: pressed || _grow.running || _fade.running

    /*! The radius the circle grows to: the farthest corner from the press point. */
    readonly property real coverRadius: {
        var dx = Math.max(_cx, width - _cx)
        var dy = Math.max(_cy, height - _cy)
        return Math.sqrt(dx * dx + dy * dy)
    }

    property real _cx: width / 2
    property real _cy: height / 2
    /*! The current circle radius in px. */
    property real circleRadius: 0
    /*! The current fade (1 while held, to 0 on release). */
    property real fade: 0

    visible: fade > 0

    onPressedChanged: {
        if (pressed) {
            _fade.stop()
            _cx = Math.max(0, Math.min(width, pressX))
            _cy = Math.max(0, Math.min(height, pressY))
            fade = 1
            _grow.from = 0
            _grow.to = coverRadius
            _grow.duration = Motion.duration(growDuration)
            _grow.restart()
        } else if (fade > 0) {
            _fade.duration = Motion.duration(fadeDuration)
            _fade.restart()
        }
    }

    NumberAnimation {
        id: _grow
        target: ripple
        property: "circleRadius"
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Motion.easing.legacy
    }
    NumberAnimation {
        id: _fade
        target: ripple
        property: "fade"
        to: 0
        easing.type: Easing.Linear
    }

    Shape {
        anchors.fill: parent
        opacity: ripple.fade
        ShapePath {
            strokeWidth: -1
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: ripple._cx; centerY: ripple._cy
                focalX: ripple._cx; focalY: ripple._cy
                centerRadius: Math.max(0.01, ripple.circleRadius)
                focalRadius: 0
                GradientStop { position: 0; color: Qt.rgba(ripple.color.r, ripple.color.g, ripple.color.b, ripple.alpha) }
                GradientStop { position: 0.995; color: Qt.rgba(ripple.color.r, ripple.color.g, ripple.color.b, ripple.alpha) }
                GradientStop { position: 1; color: Qt.rgba(ripple.color.r, ripple.color.g, ripple.color.b, 0) }
            }
            PathRectangle {
                x: 0; y: 0
                width: ripple.width; height: ripple.height
                radius: Math.min(ripple.radius, ripple.width / 2, ripple.height / 2)
            }
        }
    }
}
