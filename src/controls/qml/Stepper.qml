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
    \qmltype Stepper
    \inqmlmodule org.asteroid.controls

    \brief The Wear OS full-screen stepper (E33), for a page that picks one
    number.

    Stock (M3 Stepper): the increase button at the top and the decrease
    button at the bottom, each 60 x 48 dp, primaryContainer with 24 dp
    primary icons, morphing from a circle to small corners while pressed;
    the content (by default the value in numeralMedium) in the middle, 8 dp
    from the buttons, 5.2 % side padding. A segment tick haptic per step and
    the gesture-end haptic at the limits, when the Haptics vocabulary has
    them. No CP3A system screen uses it; inline values use the slider
    (\l IntSelector).

    \qml
    Stepper { anchors.fill: parent; from: 1; to: 10; value: 5 }
    \endqml
*/
Item {
    id: stepper

    property real value: 0
    property real from: 0
    property real to: 100
    property real stepSize: 1
    /*! Text shown for the value. */
    property string valueText: Math.round(value * 100) / 100
    /*! Replace the default value text. */
    default property alias content: _middle.data

    signal stepped(real value)

    function step(d) {
        var v = Math.max(from, Math.min(to, value + d))
        if (v === value) {
            if (typeof Haptics.gestureEnd === "function")
                Haptics.gestureEnd()
            return
        }
        value = v
        if (typeof Haptics.segmentTick === "function")
            Haptics.segmentTick()
        stepped(v)
    }

    component StepButton: MouseArea {
        id: sb
        property string iconName
        property bool atLimit: false
        width: Theme.dp(60)
        height: Theme.dp(48)
        anchors.horizontalCenter: parent.horizontalCenter
        Rectangle {
            id: box
            anchors.fill: parent
            color: sb.atLimit ? Qt.rgba(Theme.color.onSurface.r, Theme.color.onSurface.g, Theme.color.onSurface.b, Theme.alpha.disabledContainer)
                              : Theme.color.primaryContainer
            radius: height / 2 + (Theme.shape.small - height / 2) * morph.value
            WearSpring {
                id: morph
                to: sb.pressed ? 1 : 0
                stiffness: sb.pressed ? Motion.pressMorph.press.stiffness : Motion.pressMorph.release.stiffness
                dampingRatio: 1.0
            }
            Ripple { radius: box.radius; color: Theme.color.primary; pressed: sb.pressed; pressX: sb.mouseX; pressY: sb.mouseY }
        }
        Icon {
            anchors.centerIn: parent
            width: Theme.size.iconSmall
            height: width
            name: sb.iconName
            color: sb.atLimit ? Qt.rgba(Theme.color.onSurface.r, Theme.color.onSurface.g, Theme.color.onSurface.b, Theme.alpha.disabledContent)
                              : Theme.color.primary
        }
    }

    StepButton {
        id: increase
        iconName: "ios-add"
        atLimit: stepper.value >= stepper.to
        anchors.top: parent.top
        anchors.topMargin: Theme.margin.scaffoldVertical
        onClicked: stepper.step(stepper.stepSize)
    }
    StepButton {
        id: decrease
        iconName: "ios-remove"
        atLimit: stepper.value <= stepper.from
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.margin.scaffoldVertical
        onClicked: stepper.step(-stepper.stepSize)
    }
    Item {
        id: _middle
        anchors {
            top: increase.bottom
            bottom: decrease.top
            left: parent.left
            right: parent.right
            topMargin: Theme.space.m
            bottomMargin: Theme.space.m
            leftMargin: Theme.margin.side
            rightMargin: Theme.margin.side
        }
        Label {
            anchors.centerIn: parent
            visible: _middle.children.length <= 1
            text: stepper.valueText
            role: "numeralMedium"
            color: Theme.color.onSurface
        }
    }
}
