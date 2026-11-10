/*
 * Copyright (C) 2026 Reuben Horner <reubarb.scons@gmail.com>
 * SPDX-License-Identifier: BSD-3-Clause
 */

import QtQuick
import QtQuick.Shapes
import org.asteroid.controls
import org.asteroid.utils

/*!
    \qmltype ArcPageIndicator
    \inqmlmodule org.asteroid.controls

    \brief Page dots on the bottom arc of a round screen.

    Wear OS's HorizontalPageIndicator (PageIndicator.kt; E38): 6 dp dots
    4 dp apart along the bottom edge of the screen, the current one
    onBackground, the others onBackground at 30 %, on a background band 12 dp
    wide with round caps in black at 85 %. Dot centres are 8 dp from the
    edge (2 dp edge padding, PaddingDefaults.java:8, plus half the band). At
    most 6 dots show: with more pages the window of dots follows the current
    page and an end dot with more pages beyond it shrinks to 0.66 and fades.
    \l position may be fractional (0.5 = half way between the first and the
    second page) so the highlight follows a finger dragging the pages. It
    fills its parent.

    \qml
    ArcPageIndicator { count: 5; position: pager.contentX / pager.width }
    \endqml

    The dots are still Rectangles; only the highlight moves, and only when
    \l position changes.
*/
Item {
    id: indicator

    /*! Number of pages */
    property int count: 0
    /*! Current page, fractional while moving */
    property real position: 0
    /*! Dot colour */
    property color color: Theme.color.onBackground
    /*! Alpha of the other dots: 0.3 */
    property real unselectedAlpha: Theme.alpha.pageDotUnselected
    /*! Draw the background band */
    property bool band: true

    anchors.fill: parent
    enabled: false

    readonly property real _dot: Theme.size.pageDot
    readonly property real _spacing: Theme.size.pageDotSpacing
    /*! Dot centres: 8 dp from the edge. */
    readonly property real _radius: Math.min(width, height) / 2 - Theme.size.pageIndicatorEdge
    readonly property real _step: DeviceSpecs.hasRoundScreen && _radius > 0 ? (_dot + _spacing) / _radius : 0

    /*! Dots shown: at most 6. */
    readonly property int shownCount: Math.min(count, Theme.size.pageDotsMax)
    /*! The first page shown when there are more than 6. */
    readonly property int windowStart: count <= shownCount ? 0
        : Math.max(0, Math.min(count - shownCount, Math.round(position) - 2))
    /*! Scale of the dot in \a slot: 0.66 at an end with more pages beyond. */
    function slotScale(slot) {
        if (slot === 0 && windowStart > 0)
            return Theme.size.pageDotEndScale
        if (slot === shownCount - 1 && windowStart + shownCount < count)
            return Theme.size.pageDotEndScale
        return 1
    }

    function _pointAt(p) {
        var off = p - (shownCount - 1) / 2
        if (!DeviceSpecs.hasRoundScreen)
            return Qt.point(width / 2 + off * (_dot + _spacing), height - Theme.size.pageIndicatorEdge)
        // angle from the bottom of the circle, growing to the right
        var a = off * _step
        return Qt.point(width / 2 + _radius * Math.sin(a), height / 2 + _radius * Math.cos(a))
    }

    // the band behind the dots: 12 dp, round caps, black at 85 %
    Shape {
        id: bandShape
        anchors.fill: parent
        visible: indicator.band && indicator.shownCount > 0 && DeviceSpecs.hasRoundScreen
        readonly property real half: (indicator.shownCount - 1) / 2 * indicator._step * 180 / Math.PI
        ShapePath {
            strokeWidth: Theme.size.pageIndicatorBand
            strokeColor: Qt.rgba(0, 0, 0, Theme.alpha.pageIndicatorBand)
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: indicator.width / 2
                centerY: indicator.height / 2
                radiusX: indicator._radius
                radiusY: indicator._radius
                startAngle: 90 - bandShape.half
                sweepAngle: Math.max(0.01, 2 * bandShape.half)
            }
        }
    }
    Rectangle {
        // the band on a square screen
        visible: indicator.band && indicator.shownCount > 0 && !DeviceSpecs.hasRoundScreen
        readonly property point a: indicator._pointAt(0)
        x: a.x - height / 2
        y: a.y - height / 2
        height: Theme.size.pageIndicatorBand
        width: (indicator.shownCount - 1) * (indicator._dot + indicator._spacing) + height
        radius: height / 2
        color: Qt.rgba(0, 0, 0, Theme.alpha.pageIndicatorBand)
    }

    Repeater {
        model: indicator.shownCount
        delegate: Rectangle {
            readonly property point c: indicator._pointAt(index)
            x: c.x - width / 2
            y: c.y - height / 2
            width: indicator._dot
            height: width
            radius: width / 2
            color: indicator.color
            scale: indicator.slotScale(index)
            opacity: indicator.unselectedAlpha * scale
        }
    }
    Rectangle {
        readonly property real slot: Math.max(0, Math.min(indicator.shownCount - 1, indicator.position - indicator.windowStart))
        readonly property point c: indicator._pointAt(slot)
        visible: indicator.count > 0
        x: c.x - width / 2
        y: c.y - height / 2
        width: indicator._dot
        height: width
        radius: width / 2
        color: indicator.color
    }
}
