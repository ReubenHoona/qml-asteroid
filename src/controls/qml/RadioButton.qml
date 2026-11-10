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
    \qmltype RadioButton
    \inqmlmodule org.asteroid.controls

    \brief The Wear OS radio row: one choice of a list.

    Stock (RadioButtonTokens.java:36-66, RadioButtonKt.java:348-352,423):
    \list
    \li Selected: container primaryContainer, label onPrimaryContainer, second
        line at 90 %, icon primary. Unselected: surfaceContainer / onSurface /
        onSurfaceVariant. Disabled: container onSurface 12 %, content 38 %,
        control 12 %.
    \li Padding 14/8/14/8 dp; the control in a 32 x 24 dp slot 6 dp after the
        label.
    \li Ring 20 dp outside, 2 dp stroke: primary when selected, outline when
        not. Dot 10 dp in primary, growing with the fast effects spring
        (about 177 ms).
    \li A tap selects (never unselects) and plays the select haptic
        (CONTEXT_CLICK) when the Haptics vocabulary has it.
    \endlist
*/
Button {
    id: row

    /*! This choice is selected. */
    property bool checked: false
    /*! Dot scale, 0 to 1. */
    property real dotScale: checked ? 1 : 0
    Behavior on dotScale {
        NumberAnimation {
            duration: Motion.springDuration(Motion.standard.fastEffects.stiffness)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.springEasing
        }
    }

    variant: "tonal"
    verticalPadding: Theme.space.m
    maximumLineCount: 3
    trailingWidth: Theme.dp(32)

    containerColor: !enabled ? _a(Theme.color.onSurface, Theme.alpha.disabledContainer)
        : checked ? Theme.color.primaryContainer : Theme.color.surfaceContainer
    contentColor: !enabled ? _a(Theme.color.onSurface, Theme.alpha.disabledContent)
        : checked ? Theme.color.onPrimaryContainer : Theme.color.onSurface
    secondaryContentColor: !enabled ? _a(Theme.color.onSurface, Theme.alpha.disabledContent)
        : checked ? _a(Theme.color.onPrimaryContainer, Theme.alpha.secondaryOnChecked) : Theme.color.onSurfaceVariant
    iconColor: !enabled ? _a(Theme.color.onSurface, Theme.alpha.disabledContent) : Theme.color.primary
    /*! Ring and dot colour. */
    readonly property color controlColor: !enabled ? _a(Theme.color.onSurface, 0.12)
        : checked ? Theme.color.primary : Theme.color.outline

    readonly property int colorDuration: Motion.springDuration(Motion.standard.slowEffects.stiffness)
    Behavior on containerColor { ColorAnimation { duration: row.colorDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.springEasing } }
    Behavior on contentColor { ColorAnimation { duration: row.colorDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.springEasing } }

    Accessible.role: Accessible.RadioButton
    Accessible.checkable: true
    Accessible.checked: checked

    onClicked: {
        if (!checked) {
            checked = true
            if (typeof Haptics.select === "function")
                Haptics.select()
        }
    }

    Item {
        anchors.centerIn: parent
        width: Theme.dp(32)
        height: Theme.dp(24)
        Rectangle {
            id: ring
            anchors.centerIn: parent
            width: Theme.size.radio
            height: width
            radius: width / 2
            color: "transparent"
            border.width: Theme.size.radioStroke
            border.color: row.controlColor
        }
        Rectangle {
            id: dot
            anchors.centerIn: parent
            width: Theme.size.radioDot
            height: width
            radius: width / 2
            color: row.controlColor
            scale: row.dotScale
            visible: row.dotScale > 0
        }
    }
}
