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
    \qmltype ScrollAway
    \inqmlmodule org.asteroid.controls

    \brief The stock scroll-away of the time text (E46): it shrinks, moves up
    and fades as the list scrolls, and comes back when the screen is idle.

    Stock (ScrollAwayModifierNode$$ExternalSyntheticLambda1.java:31-61,
    $animateAlpha$1.java:48, $animateProgress$1.java:48, ScreenStage):
    \list
    \li offset = how far the first item has scrolled. Up to 36 dp:
        progress p = offset / 36 dp, alpha 1; beyond: p = 1, alpha 0.
    \li While the screen stage is not Scrolling (New, or Idle 2 s after the
        list stops), a time text that is gone (alpha 0) or more than 55 %
        away comes back: p = 0, alpha 1.
    \li Alpha going to 0 snaps; going to 1 animates 250 ms (standard
        easing). Progress snaps while it follows a scroll (both the old and
        the new target are non-zero, stage not New) and when it comes back at
        idle; otherwise it animates 200 ms (standard easing).
    \li Drawn: scale = 1 - 0.5 p about the top centre, moved up by p x 24 dp,
        opacity = alpha x scale.
    \endlist

    Apply \l scale, \l translateY and \l opacity to the time text;
    \l Application does this for its own TimeText.
*/
Item {
    id: sa

    /*! The scrolling view of the page. */
    property Item flickable: null

    /*! Threshold: 36 dp. */
    readonly property real threshold: Theme.dp(36)
    /*! Upward shift at p = 1: 24 dp. */
    readonly property real maxShift: Theme.dp(24)
    /*! Screen stage: 0 New, 1 Idle, 2 Scrolling (ScreenStage). */
    property int stage: 0
    /*! Time after the list stops before the stage is Idle (ms). */
    readonly property int idleDelay: 2000

    property real alphaTarget: 1
    property real progressTarget: 0
    property real alphaValue: 1
    property real progressValue: 0

    readonly property real scale: 1 - 0.5 * progressValue
    readonly property real translateY: -progressValue * maxShift
    readonly property real alpha: alphaValue * scale

    readonly property bool _valid: flickable !== null && flickable.visible && flickable.contentHeight > 0
    /*! How far the first item has scrolled (px). */
    readonly property real offset: flickable ? flickable.contentY - flickable.originY + flickable.topMargin : 0

    visible: false
    width: 0
    height: 0

    onOffsetChanged: evaluate()
    onStageChanged: evaluate()
    on_ValidChanged: evaluate()
    onFlickableChanged: {
        stage = 0
        _idle.restart()
        evaluate()
    }

    Connections {
        target: sa.flickable
        ignoreUnknownSignals: true
        function onMovingChanged() {
            if (sa.flickable.moving) {
                _idle.stop()
                sa.stage = 2
            } else {
                _idle.restart()
            }
        }
    }
    Timer {
        id: _idle
        interval: sa.idleDelay
        onTriggered: sa.stage = 1
    }

    NumberAnimation {
        id: _alphaAnim
        target: sa
        property: "alphaValue"
        duration: Motion.duration(250)
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Motion.easing.standard
    }
    NumberAnimation {
        id: _progressAnim
        target: sa
        property: "progressValue"
        duration: Motion.duration(200)
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Motion.easing.standard
    }

    /*! Stock's per-frame rule, run when the offset or the stage changes. */
    function evaluate() {
        var p, a
        if (!_valid) {
            p = 0; a = 1
        } else if (isNaN(offset) || offset > threshold) {
            p = 1; a = 0
        } else {
            p = Math.max(0, Math.min(1, offset / threshold)); a = 1
        }
        var z = stage !== 2 && (a === 0 || p > 0.55)
        if (z) {
            p = 0; a = 1
        }
        if (a !== alphaTarget) {
            alphaTarget = a
            _alphaAnim.stop()
            if (a === 0) {
                alphaValue = 0
            } else {
                _alphaAnim.from = alphaValue
                _alphaAnim.to = a
                _alphaAnim.start()
            }
        }
        if (p !== progressTarget) {
            var snap = !(p === 0 || progressTarget === 0 || stage === 0) || (z && stage !== 0)
            progressTarget = p
            _progressAnim.stop()
            if (snap) {
                progressValue = p
            } else {
                _progressAnim.from = progressValue
                _progressAnim.to = p
                _progressAnim.start()
            }
        }
    }
}
