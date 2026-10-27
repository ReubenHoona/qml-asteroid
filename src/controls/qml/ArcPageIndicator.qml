/*
 * Copyright (C) 2026 Reuben Horner <reubarb.scons@gmail.com>
 * SPDX-License-Identifier: BSD-3-Clause
 */

import QtQuick
import org.asteroid.utils

/*!
    \qmltype ArcPageIndicator
    \inqmlmodule org.asteroid.controls

    \brief Page dots on the bottom arc of a round screen.

    Wear OS's HorizontalPageIndicator: one 6 dp dot per page, 4 dp apart,
    set along the bottom edge of the screen; the current one is white, the
    others dim. \l position may be fractional (0.5 = half way between the
    first and the second page) so the highlight follows a finger dragging
    the pages. It fills its parent.

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
    property color color: "#ffffff"

    anchors.fill: parent
    enabled: false

    readonly property real _dp: Math.min(width, height) / 192
    readonly property real _dot: 6 * _dp
    readonly property real _spacing: 4 * _dp
    readonly property real _radius: Math.min(width, height) / 2 - 6 * _dp - _dot / 2
    readonly property real _step: DeviceSpecs.hasRoundScreen ? (_dot + _spacing) / _radius : 0

    function _pointAt(p) {
        var off = p - (count - 1) / 2
        if (!DeviceSpecs.hasRoundScreen)
            return Qt.point(width / 2 + off * (_dot + _spacing), height - 6 * _dp - _dot / 2)
        // angle from the bottom of the circle, growing to the left (the
        // first page is on the left, as the pages move)
        var a = off * _step
        return Qt.point(width / 2 + _radius * Math.sin(a), height / 2 + _radius * Math.cos(a))
    }

    Repeater {
        model: indicator.count
        delegate: Rectangle {
            readonly property point c: indicator._pointAt(index)
            x: c.x - width / 2
            y: c.y - height / 2
            width: indicator._dot
            height: width
            radius: width / 2
            color: indicator.color
            opacity: 0.3
        }
    }

    Rectangle {
        readonly property point c: indicator._pointAt(Math.max(0, Math.min(indicator.count - 1, indicator.position)))
        visible: indicator.count > 0
        x: c.x - width / 2
        y: c.y - height / 2
        width: indicator._dot
        height: width
        radius: width / 2
        color: indicator.color
    }
}
