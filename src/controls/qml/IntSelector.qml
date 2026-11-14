/*
 * Copyright (C) 2026 - Timo Könnecke  <github.com/eLtMosen>
 *               2022 - Ed Beroset     <github.com/beroset>
 *               2020 - Darrel Griët   <idanlcontact@gmail.com>
 *               2015 - Florent Revest <revestflo@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
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
    \qmltype IntSelector
    \inqmlmodule org.asteroid.controls

    \brief An integer value control in a list row, drawn as the Wear OS
    slider (E29, E30, E33).

    The row is the slider container (surfaceContainer, CornerLarge, at least
    52 dp). Minus and plus buttons are 48 dp wide at each end with 24 dp
    icons in onSurface (38 % at the limits); between them the bar: the
    selected part 12 dp tall and fully round in primary, the rest 4 dp tall
    in black at 30 % over the container (#212226); the selected length
    animates 150 ms with (0, 0, 0, 1). The value text sits above the bar.
    Drag along the bar to scrub; tap the buttons to step.

    \qml
    IntSelector {
        width: parent.width
        height: Dims.l(20)
        min: 0; max: 100; stepSize: 10
        value: 50
        onValueChanged: console.log("value:", value)
    }
    \endqml
*/
ListRow {
    id: selector

    /*!
        \qmlproperty int IntSelector::min
        Minimum allowed value. Default is 0.
    */
    property int min: 0
    /*!
        \qmlproperty int IntSelector::max
        Maximum allowed value. Default is 100.
    */
    property int max: 100
    /*!
        \qmlproperty int IntSelector::stepSize
        Step size per button actuation. Default is 10.
    */
    property int stepSize: 10
    /*!
        \qmlproperty string IntSelector::unitMarker
        Unit string appended to the value label. Default is %.
    */
    property string unitMarker: "%"
    /*!
        \qmlproperty int IntSelector::value
        Current value of the control. Default is 0.
    */
    property int value: 0
    /*!
        \qmlproperty bool IntSelector::valueLabelVisible
        Whether the value label and indicator are shown. Default is true.
    */
    property bool valueLabelVisible: true

    /*! The selected fraction, 0..1. */
    readonly property real fraction: max > min ? Math.max(0, Math.min(1, (value - min) / (max - min))) : 0

    highlightBarEnabled: false

    /*! The decrease button, the increase button and the selected bar, for tests. */
    readonly property Item _minusButton: buttonMinus
    readonly property Item _plusButton: buttonPlus
    readonly property Item _selectedBar: selected
    readonly property Item _dragArea: dragArea

    function _step(d) {
        var v = Math.max(min, Math.min(max, value + d))
        if (v === value)
            return
        value = v
        if (typeof Haptics.segmentTick === "function")
            Haptics.segmentTick()
    }

    Item {
        id: slider
        parent: selector.container
        anchors.fill: parent

        readonly property real buttonWidth: Theme.size.sliderButtonWidth
        readonly property color iconOn: Theme.color.onSurface
        readonly property color iconOff: Qt.rgba(Theme.color.onSurface.r, Theme.color.onSurface.g, Theme.color.onSurface.b, Theme.alpha.disabledContent)

        MouseArea {
            id: buttonMinus
            anchors.left: parent.left
            width: slider.buttonWidth
            height: parent.height
            enabled: selector.enabled
            onClicked: selector._step(-selector.stepSize)
            Ripple { radius: selector.container.radius; color: slider.iconOn; pressed: buttonMinus.pressed; pressX: buttonMinus.mouseX; pressY: buttonMinus.mouseY }
            Icon {
                anchors.centerIn: parent
                width: Theme.size.iconSmall
                height: width
                name: "ios-remove"
                color: selector.value <= selector.min ? slider.iconOff : slider.iconOn
            }
        }
        MouseArea {
            id: buttonPlus
            anchors.right: parent.right
            width: slider.buttonWidth
            height: parent.height
            enabled: selector.enabled
            onClicked: selector._step(selector.stepSize)
            Ripple { radius: selector.container.radius; color: slider.iconOn; pressed: buttonPlus.pressed; pressX: buttonPlus.mouseX; pressY: buttonPlus.mouseY }
            Icon {
                anchors.centerIn: parent
                width: Theme.size.iconSmall
                height: width
                name: "ios-add"
                color: selector.value >= selector.max ? slider.iconOff : slider.iconOn
            }
        }

        Column {
            id: middle
            anchors {
                left: buttonMinus.right
                right: buttonPlus.left
                verticalCenter: parent.verticalCenter
            }
            spacing: Theme.space.xs
            Label {
                id: valueLabel
                width: parent.width
                visible: selector.valueLabelVisible
                text: selector.value + selector.unitMarker
                role: "labelMedium"
                color: Theme.color.onSurface
                horizontalAlignment: Text.AlignHCenter
                font.weight: dragArea.tracking ? Font.Bold : Font.Medium
            }
            Item {
                id: bar
                width: parent.width
                height: Theme.size.sliderSelectedBar
                readonly property real selectedWidth: selector.fraction > 0 ? Math.max(height, width * selector.fraction) : 0
                property real shownWidth: selectedWidth
                Behavior on shownWidth {
                    enabled: !dragArea.tracking
                    NumberAnimation { duration: Motion.duration(150); easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.easing.standardDecelerate }
                }
                Rectangle {
                    id: unselected
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    width: Math.max(0, bar.width - bar.shownWidth)
                    height: Theme.size.sliderUnselectedBar
                    radius: Theme.dp(2)
                    color: Theme.color.sliderTrackOnSurface
                }
                Rectangle {
                    id: selected
                    anchors.left: parent.left
                    width: bar.shownWidth
                    height: parent.height
                    radius: height / 2
                    visible: width > 0
                    color: selector.enabled ? Theme.color.primary
                                            : Qt.rgba(Theme.color.onSurface.r, Theme.color.onSurface.g, Theme.color.onSurface.b, Theme.alpha.disabledContent)
                }
            }
        }

        MouseArea {
            id: dragArea
            anchors.fill: middle
            enabled: selector.enabled
            propagateComposedEvents: true
            preventStealing: false
            property int startX: 0
            property int startY: 0
            property bool tracking: false
            property int threshold: Theme.dp(8)

            onPressed: {
                startX = mouseX
                startY = mouseY
                tracking = false
            }
            onPositionChanged: (mouse) => {
                if (!tracking) {
                    var dx = Math.abs(mouseX - startX)
                    var dy = Math.abs(mouseY - startY)
                    if (dx < threshold && dy < threshold) return
                    if (dx >= dy) {
                        tracking = true
                        preventStealing = true
                    } else {
                        mouse.accepted = false
                        return
                    }
                }
                updateValue(mouseX)
            }
            onReleased: {
                preventStealing = false
                tracking = false
            }
            onPressAndHold: {
                tracking = true
                preventStealing = true
                updateValue(mouseX)
            }
            onCanceled: {
                preventStealing = false
                tracking = false
            }
            function updateValue(mx) {
                var f = Math.max(0, Math.min(1, mx / Math.max(1, width)))
                if (dragArea.LayoutMirroring.enabled)
                    f = 1 - f   // the value grows from the right
                var v = Math.max(selector.min, Math.min(selector.max,
                        Math.round((selector.min + f * (selector.max - selector.min)) / selector.stepSize) * selector.stepSize))
                if (v !== selector.value)
                    selector._step(v - selector.value)
            }
        }
    }
}
