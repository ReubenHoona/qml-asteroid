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
    readonly property real _halfThickness: 2.5 * _dp
    readonly property real _midRadius: Math.min(width, height) / 2 - 2 * _dp - _halfThickness
    readonly property real _halfLength: 25 * _dp
    readonly property real _halfSweep: _halfLength / _midRadius

    ShaderEffect {
        id: arc
        // only the band at the right edge that holds the arc
        width: indicator.width / 2 - indicator._midRadius * Math.cos(indicator._halfSweep) + indicator._halfThickness + 2
        height: 2 * (indicator._midRadius + indicator._halfThickness) * Math.sin(indicator._halfSweep) + 2 * indicator._halfThickness + 4
        x: indicator.width - width
        y: (indicator.height - height) / 2

        property size itemSize: Qt.size(width, height)
        property point center: Qt.point(indicator.width / 2 - x, indicator.height / 2 - y)
        property real midRadius: indicator._midRadius
        property real halfThickness: indicator._halfThickness
        property real halfLength: indicator._halfLength
        property real thumbStart: -halfLength + (2 * halfLength) * (1 - indicator._thumbFraction) * indicator._position
        property real thumbEnd: thumbStart + 2 * halfLength * indicator._thumbFraction
        // Wear OS: the track is the foreground at 30%; Qt premultiplies
        property color trackColor: Qt.rgba(1, 1, 1, 0.3)
        property color thumbColor: "white"

        fragmentShader: "positionindicator.frag.qsb"
    }
}
