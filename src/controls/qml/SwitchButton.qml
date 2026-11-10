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

    \brief The Wear OS switch row: a button whose container, label and icon
    change with its \l Switch.

    Stock (SwitchButtonTokens.java:50-97, SwitchButtonDefaults.java:11):
    \list
    \li On: container primaryContainer, label onPrimaryContainer, second line
        onPrimaryContainer at 90 %, icon primary.
    \li Off: container surfaceContainer, label onSurface, second line
        onSurfaceVariant, icon primary.
    \li Disabled: container onSurface at 12 %, content onSurface at 38 %.
    \li Padding 14/8/14/8 dp; the switch in a 32 x 24 dp slot 6 dp after the
        label; colours change with the slow effects spring (about 412 ms).
    \li Tapping toggles \l checked and plays the toggle haptic (TOGGLE_ON /
        TOGGLE_OFF) when the Haptics vocabulary has it.
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
    trailingWidth: Theme.dp(32)

    readonly property color _checkedContainer: Theme.color.primaryContainer
    readonly property color _checkedContent: Theme.color.onPrimaryContainer

    containerColor: !enabled ? _a(Theme.color.onSurface, Theme.alpha.disabledContainer)
        : checked ? _checkedContainer : Theme.color.surfaceContainer
    contentColor: !enabled ? _a(Theme.color.onSurface, Theme.alpha.disabledContent)
        : checked ? _checkedContent : Theme.color.onSurface
    secondaryContentColor: !enabled ? _a(Theme.color.onSurface, Theme.alpha.disabledContent)
        : checked ? _a(_checkedContent, Theme.alpha.secondaryOnChecked) : Theme.color.onSurfaceVariant
    iconColor: !enabled ? _a(Theme.color.onSurface, Theme.alpha.disabledContent) : Theme.color.primary

    // the slow effects spring: stiffness 260, about 412 ms
    readonly property int colorDuration: Motion.springDuration(Motion.standard.slowEffects.stiffness)
    Behavior on containerColor { ColorAnimation { duration: row.colorDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.springEasing } }
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

    Switch {
        id: _switch
        anchors.centerIn: parent
        checked: row.checked
        enabled: row.enabled
        toggleOnClick: false
    }
}
