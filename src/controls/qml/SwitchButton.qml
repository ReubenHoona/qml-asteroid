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
    \qmltype SwitchButton
    \inqmlmodule org.asteroid.controls

    \brief The Wear OS switch row: a button with a \l Switch whose checked
    state lays a gradient over the row.

    The Wear OS 6 emulator (Settings S18-b, S20, S20-b, S21, S23, S23-b,
    S24; Alarm S29-b in Material 2):
    \list
    \li The container stays surfaceContainer; checked, the row's gradient
        (\l{Button}{checkedGradient}: primary from 0 at the top left to
        32.5 % at the bottom right, #35363D at x 30 and #636671 at x 355 on
        #2F3036) comes in on the slow effects spring (about 412 ms), and the
        label stays onSurface.
    \li Second line and icon primary ('Will turn on at 10%' #DBE2F9); the
        content colour (onSurface) in a Material 2 application.
    \li Disabled: the container stays, label, second line and icon
        #80868B (S23-b).
    \li The small switch (24 x 10 dp track, 14 dp thumb) in a 24 dp slot
        6 dp after the label and 14 dp from the end (its right end 28 px in
        from the row's end); its track lies translucent over the gradient.
    \li Padding 14/8/14/8 dp. Tapping toggles \l checked and plays the
        toggle haptic (TOGGLE_ON / TOGGLE_OFF) when the Haptics vocabulary
        has it.
    \endlist

    \qml
    SwitchButton { text: "Wi-Fi"; secondaryText: "Connected"; checked: true }
    \endqml
*/
Button {
    id: row

    /*! The switch is on. */
    property bool checked: false

    /*! Emitted after a tap changed \l checked. */
    signal toggled(bool checked)

    variant: "tonal"
    verticalPadding: Theme.space.m
    maximumLineCount: 3
    trailingWidth: Theme.size.switchTrackWidth

    containerColor: Theme.color.surfaceContainer
    contentColor: !enabled ? Theme.color.disabledContentFlat : Theme.color.onSurface
    secondaryContentColor: !enabled ? Theme.color.disabledContentFlat
        : _m2 ? contentColor : Theme.color.primary
    iconColor: !enabled ? Theme.color.disabledContentFlat
        : _m2 ? contentColor : Theme.color.primary

    // the gradient on the slow effects spring (stiffness 260, about 412 ms)
    // (written by the spring below, which sets the first value as it is: no binding here)
    WearSpring {
        target: row
        property: "checkedGradient"
        to: row.checked ? 1 : 0
        stiffness: Motion.standard.slowEffects.stiffness
        dampingRatio: 1.0
        visibilityThreshold: 0.001
    }

    // the slow effects spring: stiffness 260, about 412 ms
    readonly property int colorDuration: Motion.springDuration(Motion.standard.slowEffects.stiffness)
    Behavior on contentColor { ColorAnimation { duration: row.colorDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.springEasing } }
    Behavior on secondaryContentColor { ColorAnimation { duration: row.colorDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.springEasing } }

    Accessible.role: Accessible.CheckBox
    Accessible.checkable: true
    Accessible.checked: checked

    onClicked: {
        checked = !checked
        if (typeof Haptics.toggle === "function")
            Haptics.toggle()
        toggled(checked)
    }

    /*! The switch (for tests). */
    readonly property alias switchItem: _switch

    Switch {
        id: _switch
        anchors.centerIn: parent
        checked: row.checked
        enabled: row.enabled
        toggleOnClick: false
        // translucent over the row and its gradient, as stock
        containerColor: "transparent"
    }
}
