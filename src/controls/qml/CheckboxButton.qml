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

    Stock (E27): the row is coloured as the CP3A switch row (checked
    primaryContainer / onPrimaryContainer). Box 18 dp, corner 2 dp, stroke
    2 dp; checked = filled primary with a primaryContainer check mark (drawn
    as the switch tick); unchecked = an outline box. Padding 14/8/14/8 dp.

    In a Material 2 application (\l{Theme}{Theme.materialVersion} 2) the
    row is a Wear Material 2 toggle chip, as \l SwitchButton there: the
    container stays surfaceContainer with the checked gradient
    (\l{Button}{checkedGradient}), label, second line and icon onSurface
    (#80868B disabled); the box secondary with an onSecondary check, and
    onSurface at 60 % unchecked. No emulator capture shows a checkbox row.
*/
Button {
    id: row

    /*! The item is checked. */
    property bool checked: false
    /*! Emitted after a tap changed \l checked. */
    signal toggled(bool checked)

    /*! Tick progress, 0 to 1 (fast effects spring, about 177 ms). */
    // (written by the spring below, which sets the first value as it is: no binding here)
    property real progress: 0
    // on the fast effects spring, 1.0/1400 (androidx CheckboxButton; not in the stock Settings copy, motion G6): toggled again
    // mid-way, it keeps its speed
    WearSpring {
        target: row
        property: "progress"
        to: row.checked ? 1 : 0
        stiffness: Motion.standard.fastEffects.stiffness
        dampingRatio: 1.0
        visibilityThreshold: 0.001
    }

    variant: "tonal"
    verticalPadding: Theme.space.m
    maximumLineCount: 3
    trailingWidth: Theme.dp(32)

    containerColor: _m2 ? Theme.color.surfaceContainer
        : !enabled ? _a(Theme.color.onSurface, Theme.alpha.disabledContainer)
        : checked ? Theme.color.primaryContainer : Theme.color.surfaceContainer
    contentColor: _m2 ? (enabled ? Theme.color.onSurface : Theme.color.disabledContentFlat)
        : !enabled ? _a(Theme.color.onSurface, Theme.alpha.disabledContent)
        : checked ? Theme.color.onPrimaryContainer : Theme.color.onSurface
    secondaryContentColor: _m2 ? contentColor
        : !enabled ? _a(Theme.color.onSurface, Theme.alpha.disabledContent)
        : checked ? _a(Theme.color.onPrimaryContainer, Theme.alpha.secondaryOnChecked) : Theme.color.onSurfaceVariant
    iconColor: _m2 ? contentColor
        : !enabled ? _a(Theme.color.onSurface, Theme.alpha.disabledContent) : Theme.color.primary
    // Material 2: the checked gradient on the slow effects spring, as SwitchButton
    WearSpring {
        target: row
        property: "checkedGradient"
        to: row._m2 && row.checked ? 1 : 0
        stiffness: Motion.standard.slowEffects.stiffness
        dampingRatio: 1.0
        visibilityThreshold: 0.001
    }
    /*! Box colour: primary checked, outline unchecked, onSurface 12 % disabled
        (Material 2: secondary checked, onSurface 60 % unchecked). */
    readonly property color boxColor: !enabled ? _a(Theme.color.onSurface, 0.12)
        : checked ? (_m2 ? Theme.color.secondary : Theme.color.primary)
        : _m2 ? _a(Theme.color.onSurface, 0.6) : Theme.color.outline
    /*! Check mark colour: primaryContainer (Material 2: onSecondary). */
    readonly property color checkColor: !enabled ? _a(Theme.color.onSurface, 0.38)
        : _m2 ? Theme.color.onSecondary : Theme.color.primaryContainer

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
