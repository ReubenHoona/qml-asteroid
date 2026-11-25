/*
 * Copyright (C) 2026 eos-mainline contributors
 * SPDX-License-Identifier: BSD-3-Clause
 */

import QtQuick
import org.asteroid.controls

/*!
    \qmltype InlineSlider
    \inqmlmodule org.asteroid.controls

    \brief The Wear OS stepper row: a decrease segment, a bar and an increase
    segment in one pill (Settings' volume and brightness sliders).

    The Wear OS 6 emulator (Settings S21-d volumes, S24 Brightness; measured
    from the PNGs), px on the 384 px screen:
    \list
    \li The pill: 52 dp (104 px) tall, the row's width (344 px at x
        20-363), surfaceContainer #2F3036.
    \li The decrease and increase segments 36 dp (72 px) wide at the ends,
        each cut from the middle by a 1 dp (2 px) black divider the pill's
        height (x 92-93 and 290-291).
    \li The glyphs pure white with square ends, 12 dp (24 px) in from the
        pill's ends: the minus 32 x 4 px (x 44-75), the plus 32 x 32 px with
        4 px strokes (x 308-339), centred on the pill.
    \li The bar 7 dp (14 px) inside the dividers (x 108-275), 6 dp (12 px)
        tall, fully round, centred: unselected \c{Theme.color.sliderTrack}
        #202124, selected \c{Theme.color.sliderFill} (tertiary #D4C7FF),
        from the start, its far end square.
    \li \l segmented (Brightness, 5 steps): 1 px black gaps between the
        steps' segments (33.6 px apart), no dots; not segmented (volumes):
        one bar.
    \li The selected fraction animates over 150 ms on (0, 0, 0, 1), as
        CP3A. At its limit, or when not \l active, a glyph is at 38 %.
    \li A tap on a segment steps by \l stepSize between \l lowest and \l to
        and emits \l moved: the step onto the first or last value plays
        GESTURE_END, every other one SEGMENT_FREQUENT_TICK (CP3A
        SliderKt$$ExternalSyntheticLambda8.java:20-40); a tap that moves
        nothing plays nothing. A bounded ripple in the glyph colour.
    \endlist

    In a list the row shrinks with its packed neighbours (\l EdgeEffect,
    packed; \l edgeEffect turns it off). Inside a row that has an
    EdgeEffect of its own (Settings' SettingsSlider) it stays at rest.

    \qml
    InlineSlider { from: 0; to: 100; stepSize: 10; value: level; onMoved: (v) => level = v }
    InlineSlider { segmented: true; from: 0; to: 5; stepSize: 1; lowest: 1; value: 3 }
    \endqml
*/
Item {
    id: slider

    property real from: 0
    property real to: 100
    property real stepSize: 10
    property real value: 0
    /*! The lowest value the decrease segment reaches (Brightness: step 1). */
    property real lowest: from
    /*! false: greyed out, taps do nothing. */
    property bool active: true
    /*! Segments with gaps between the steps (Brightness); false: one bar. */
    property bool segmented: false
    /*! Screen reader names of the segments ("Decrease brightness") and the
        state ("50 percent screen brightness"). */
    property string decreaseDescription: ""
    property string increaseDescription: ""
    property string valueDescription: ""
    /*! The row shrinks with its packed list neighbours. */
    property alias edgeEffect: edge.enabled

    readonly property int steps: Math.max(1, Math.round((to - from) / stepSize))
    readonly property real position: to > from ? Math.max(0, Math.min(1, (value - from) / (to - from))) : 0
    /*! The bar's segments: one when not segmented. */
    readonly property int segments: segmented ? steps : 1

    /*! A segment was tapped: the value it asks for. */
    signal moved(real newValue)

    /*! Steps \a n steps from the value (clamped to \l lowest .. \l to). */
    function stepBy(n) {
        var v = Math.max(lowest, Math.min(to, Math.round((value - from) / stepSize + n) * stepSize + from))
        if (v === value)
            return
        if (v === lowest || v === to) {
            if (typeof Haptics.gestureEnd === "function")
                Haptics.gestureEnd()
        } else if (typeof Haptics.segmentTick === "function") {
            Haptics.segmentTick()
        }
        moved(v)
    }

    /*! Geometry (px): end segments 36 dp, dividers 1 dp, the bar 7 dp inside
        them and 6 dp tall, the glyphs 16 dp with 2 dp strokes, 12 dp from the
        pill's ends; the gaps of a segmented bar 1 px. */
    readonly property real segmentWidth: Theme.dp(36)
    readonly property real dividerWidth: Theme.dp(1)
    readonly property real barInset: Theme.dp(7)
    readonly property real barHeight: Theme.dp(6)
    readonly property real glyphSize: Theme.dp(16)
    readonly property real glyphStroke: Theme.dp(2)
    readonly property real glyphInset: Theme.dp(12)
    readonly property real gapWidth: 1

    function _a(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
    /*! The glyphs: pure white (#FFFFFF), at 38 % at their limit or inactive. */
    property color glyphColor: "#FFFFFF"
    readonly property color _glyphDim: _a(glyphColor, Theme.alpha.disabledContent)
    readonly property color decreaseColor: active && value > lowest ? glyphColor : _glyphDim
    readonly property color increaseColor: active && value < to ? glyphColor : _glyphDim
    /*! The selected part: sliderFill (tertiary); #80868B inactive. */
    readonly property color fillColor: active ? Theme.color.sliderFill : Theme.color.disabledContentFlat
    readonly property color trackColor: Theme.color.sliderTrack

    width: parent ? parent.width : Theme.dp(172)
    implicitHeight: Theme.size.slider
    height: implicitHeight

    Accessible.role: Accessible.Slider
    Accessible.description: slider.valueDescription

    // the row is measured and packed at its own height
    EdgeEffect { id: edge; item: slider; packed: true }
    transform: [
        Scale {
            origin.x: slider.width / 2
            origin.y: edge.originY
            xScale: edge.scale
            yScale: edge.scale
        },
        Translate { y: edge.translateY }
    ]

    readonly property bool _mirrored: LayoutMirroring.enabled

    Rectangle {
        id: container
        objectName: "sliderContainer"
        anchors.fill: parent
        radius: Math.min(Theme.shape.large, height / 2)
        color: Theme.color.surfaceContainer
        opacity: edge.alpha
    }

    // a bounded ripple in one end segment: the pill's round end outside, cut
    // square at the divider
    component SegmentRipple: Item {
        id: segmentRipple
        property bool start: true
        property MouseArea area
        anchors.fill: parent
        clip: true
        Item {
            id: rippleBox
            x: segmentRipple.start ? 0 : -container.radius
            width: segmentRipple.width + container.radius
            height: segmentRipple.height
            Ripple {
                radius: container.radius
                color: slider.glyphColor
                pressed: segmentRipple.area ? segmentRipple.area.pressed : false
                pressX: segmentRipple.area ? segmentRipple.area.mouseX - rippleBox.x : 0
                pressY: segmentRipple.area ? segmentRipple.area.mouseY : 0
            }
        }
    }

    Item {
        anchors.fill: parent
        opacity: edge.alpha

        MouseArea {
            id: minus
            objectName: "sliderMinus"
            enabled: slider.active
            width: slider.segmentWidth
            height: parent.height
            anchors.left: parent.left
            onClicked: slider.stepBy(-1)
            Accessible.role: Accessible.Button
            Accessible.name: slider.decreaseDescription
            SegmentRipple { start: !slider._mirrored; area: minus }
            Rectangle {
                objectName: "sliderMinusGlyph"
                x: slider._mirrored ? parent.width - slider.glyphInset - width : slider.glyphInset
                anchors.verticalCenter: parent.verticalCenter
                width: slider.glyphSize
                height: slider.glyphStroke
                color: slider.decreaseColor
            }
        }

        MouseArea {
            id: plus
            objectName: "sliderPlus"
            enabled: slider.active
            width: slider.segmentWidth
            height: parent.height
            anchors.right: parent.right
            onClicked: slider.stepBy(1)
            Accessible.role: Accessible.Button
            Accessible.name: slider.increaseDescription
            SegmentRipple { start: slider._mirrored; area: plus }
            Item {
                objectName: "sliderPlusGlyph"
                x: slider._mirrored ? slider.glyphInset : parent.width - slider.glyphInset - width
                anchors.verticalCenter: parent.verticalCenter
                width: slider.glyphSize
                height: width
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width
                    height: slider.glyphStroke
                    color: slider.increaseColor
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: slider.glyphStroke
                    height: parent.height
                    color: slider.increaseColor
                }
            }
        }

        // the dividers: black (the background), the pill's height
        Rectangle {
            objectName: "sliderDividerStart"
            x: slider.segmentWidth
            width: slider.dividerWidth
            height: parent.height
            color: Theme.color.background
        }
        Rectangle {
            objectName: "sliderDividerEnd"
            x: parent.width - slider.segmentWidth - width
            width: slider.dividerWidth
            height: parent.height
            color: Theme.color.background
        }

        Item {
            id: bar
            objectName: "sliderBar"
            x: slider.segmentWidth + slider.dividerWidth + slider.barInset
            width: Math.max(0, parent.width - 2 * x)
            height: slider.barHeight
            anchors.verticalCenter: parent.verticalCenter
            // the selected fraction animates (CP3A animateFloatAsState, 150 ms,
            // EasingStandardDecelerate)
            property real shownPosition: slider.position
            Behavior on shownPosition {
                NumberAnimation {
                    duration: Motion.duration(150)
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.easing.standardDecelerate
                }
            }
            readonly property real r: height / 2
            readonly property real shownWidth: width * shownPosition

            Rectangle {
                objectName: "sliderUnselected"
                anchors.fill: parent
                radius: bar.r
                color: slider.trackColor
            }
            // from the start, the far end square until it reaches the bar's round end
            Rectangle {
                objectName: "sliderSelected"
                readonly property real _endRadius: Math.max(0, bar.r - (bar.width - width))
                x: slider._mirrored ? bar.width - width : 0
                width: bar.shownWidth
                height: parent.height
                visible: width > 0
                color: slider.fillColor
                topLeftRadius: slider._mirrored ? _endRadius : bar.r
                bottomLeftRadius: slider._mirrored ? _endRadius : bar.r
                topRightRadius: slider._mirrored ? bar.r : _endRadius
                bottomRightRadius: slider._mirrored ? bar.r : _endRadius
            }
            Repeater {
                objectName: "sliderGaps"
                model: slider.segments - 1
                Rectangle {
                    required property int index
                    x: bar.width * (index + 1) / slider.segments - width / 2
                    width: slider.gapWidth
                    height: bar.height
                    color: Theme.color.background
                }
            }
        }
    }
}
