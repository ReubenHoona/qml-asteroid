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
    \qmltype CheckboxButton
    \inqmlmodule org.asteroid.controls

    \brief The Wear OS checkbox row, for lists where several items can be
    chosen (for example the repeat days of an alarm).

    Stock (E27): the row is coloured as the switch row (checked
    primaryContainer / onPrimaryContainer). Box 18 dp, corner 2 dp, stroke
    2 dp; checked = filled primary with a primaryContainer check mark (drawn
    as the switch tick); unchecked = an outline box. Padding 14/8/14/8 dp.
*/
Button {
    id: row

    /*! The item is checked. */
    property bool checked: false
    /*! Emitted after a tap changed \l checked. */
    signal toggled(bool checked)

    /*! Tick progress, 0 to 1 (fast effects spring, about 177 ms). */
    property real progress: checked ? 1 : 0
    Behavior on progress {
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
    /*! Box colour: primary checked, outline unchecked, onSurface 12 % disabled. */
    readonly property color boxColor: !enabled ? _a(Theme.color.onSurface, 0.12)
        : checked ? Theme.color.primary : Theme.color.outline
    /*! Check mark colour: primaryContainer. */
    readonly property color checkColor: enabled ? Theme.color.primaryContainer : _a(Theme.color.onSurface, 0.38)

    readonly property int colorDuration: Motion.springDuration(Motion.standard.slowEffects.stiffness)
    Behavior on containerColor { ColorAnimation { duration: row.colorDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.springEasing } }
    Behavior on contentColor { ColorAnimation { duration: row.colorDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.springEasing } }

    Accessible.role: Accessible.CheckBox
    Accessible.checkable: true
    Accessible.checked: checked

    onClicked: {
        checked = !checked
        if (typeof Haptics.toggle === "function")
            Haptics.toggle()
        toggled(checked)
    }

    Item {
        anchors.centerIn: parent
        width: Theme.dp(32)
        height: Theme.dp(24)
        Rectangle {
            id: box
            anchors.centerIn: parent
            width: Theme.dp(18)
            height: width
            radius: Theme.dp(2)
            color: row.checked ? row.boxColor : "transparent"
            border.width: Theme.dp(2)
            border.color: row.boxColor
        }
        Shape {
            anchors.centerIn: parent
            width: Theme.dp(24)
            height: width
            scale: 1 - Math.pow(1 - row.progress, 3)
            visible: row.progress > 0
            ShapePath {
                strokeWidth: Theme.dp(2)
                strokeColor: row.checkColor
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathMove { x: Theme.dp(7.4); y: Theme.dp(13) }
                PathLine { x: Theme.dp(9.9); y: Theme.dp(15.5) }
                PathMove { x: Theme.dp(10.5); y: Theme.dp(15.1) }
                PathLine { x: Theme.dp(16.5); y: Theme.dp(9.1) }
            }
        }
    }
}
