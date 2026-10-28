/*
 * Copyright (C) 2026 Reuben Horner <reubarb.scons@gmail.com>
 * SPDX-License-Identifier: BSD-3-Clause
 */

import QtQuick
import org.asteroid.utils

/*!
    \qmltype PositionIndicator
    \inqmlmodule org.asteroid.controls

    \brief The curved scroll indicator at the right edge of a round screen.

    Shows where a vertically scrolling \l Flickable (or ListView) is, as a
    thumb on a short track bent along the right edge of the screen, the way
    Wear OS does. It shows up while the view moves or the crown turns and
    fades out two seconds later.

    Every application gets one for free: the crown support of
    org.asteroid.controls puts one on top of the window and points it at the
    view the crown or a finger scrolls. Set the dconf key
    /org/asteroidos/ux/position-indicator to false to turn that off. An
    application can also place its own:

    \qml
    PositionIndicator { flickable: myListView }
    \endqml

    The arc is made of short rounded rectangles along the circle, so it needs
    no shader of its own (a first use compiled one, a 50 ms frame); the thumb
    is one item turned about the middle of the screen, so a scroll changes
    one rotation per frame.
*/
Item {
    id: indicator

    /*! The view whose position is shown */
    property Item flickable: null
    /*! True while the indicator is (fading) in */
    property bool shown: false

    anchors.fill: parent
    enabled: false

    readonly property real _content: flickable ? flickable.contentHeight + flickable.topMargin + flickable.bottomMargin : 0
    readonly property real _view: flickable ? flickable.height : 0
    readonly property bool _scrollable: _content > _view + 1
    /* Wear OS: the thumb is the visible fraction of the content, kept
     * between 30% and 70% of the track */
    readonly property real _thumbFraction: _scrollable ? Math.max(0.3, Math.min(0.7, _view / _content)) : 1
    readonly property real _position: _scrollable
        ? Math.max(0, Math.min(1, (flickable.contentY - flickable.originY + flickable.topMargin) / (_content - _view)))
        : 0

    /*! Show the indicator now and hide it two seconds after the last call */
    function flash() {
        shown = true
        hideTimer.restart()
    }

    opacity: shown && _scrollable ? 1 : 0
    visible: opacity > 0
    Behavior on opacity {
        NumberAnimation {
            duration: indicator.shown ? 150 : 500
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]
        }
    }

    Timer {
        id: hideTimer
        interval: 2000
        onTriggered: {
            if (indicator.flickable && indicator.flickable.moving)
                restart()
            else
                indicator.shown = false
        }
    }

    Connections {
        target: indicator.flickable
        ignoreUnknownSignals: true
        function onMovingChanged() {
            if (indicator.flickable.moving)
                indicator.flash()
        }
    }

    // Wear OS ScrollIndicator: 50 x 5 dp, 2 dp from the edge; the Pixel
    // Watch 2 has 2 px per dp on 384 px (192 dp)
    readonly property real _dp: Math.min(width, height) / 192
    readonly property real _thickness: 5 * _dp
    readonly property real _radius: Math.min(width, height) / 2 - 2 * _dp - _thickness / 2
    readonly property real _length: 50 * _dp

    // an arc of `length` px centred on the right edge, as rounded segments
    // (each one thickness longer than its share, so they join smoothly)
    component Arc: Item {
        id: arc
        property real length: 0
        property color color: "white"
        readonly property int count: Math.max(2, Math.ceil(length / (indicator._thickness * 1.2)))
        anchors.fill: parent
        Repeater {
            model: arc.count
            delegate: Rectangle {
                readonly property real share: arc.length / arc.count
                // radians, 0 at the right edge, positive downwards
                readonly property real angle: (-arc.length / 2 + share * (index + 0.5)) / indicator._radius
                width: indicator._thickness
                height: share + indicator._thickness
                radius: width / 2
                color: arc.color
                x: arc.width / 2 + indicator._radius * Math.cos(angle) - width / 2
                y: arc.height / 2 + indicator._radius * Math.sin(angle) - height / 2
                rotation: angle * 180 / Math.PI
            }
        }
    }

    // Wear OS: the track is the foreground at 30%: opaque here, so the
    // segments' overlaps do not show
    Arc {
        length: indicator._length
        color: "#5a5a5a"
    }

    Arc {
        id: thumb
        length: indicator._length * indicator._thumbFraction
        color: "white"
        // along the track, turned about the middle of the screen
        rotation: ((indicator._length - length) * (indicator._position - 0.5)) / indicator._radius * 180 / Math.PI
    }
}
