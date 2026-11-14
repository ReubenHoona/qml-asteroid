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
import QtQuick.Window
import org.asteroid.controls

/*!
    \qmltype SwipeToReveal
    \inqmlmodule org.asteroid.controls

    \brief Swipe a card to the left to reveal its actions (E23 of the
    notification stream: Wear OS Material 3 SwipeToReveal).

    Stock (notif-stream-03): right-to-left only, with a partial reveal.
    \list
    \li Anchors: covered (0), revealing (-130 dp x card width / 192 dp; 116 dp
        for a 172 dp card) and revealed (the whole width, which runs the
        primary action: the card is cleared).
    \li Release: past 0.75 x 192 dp - 10 dp (134 dp) or a fling faster than
        800 dp/s to the left goes to revealed; otherwise the nearest of covered
        and revealing (half way between them).
    \li While covered, touches that start in the left 15 % of the screen are
        left alone (the back swipe and the list get them). Touch slop x 1.0
        (8 dp).
    \li A haptic on the partial and on the full reveal, at most once per
        500 ms. Opening one card's reveal covers any other open one under the
        same parent.
    \li Revealed: the primary pill (Close icon and "Clear", primaryDim /
        onPrimary, 84 dp tall at most) at the right and a round secondary
        button (gear, primaryContainer / onPrimaryContainer) before it; on a
        full swipe the pill grows to the whole width.
    \li Not swipeable when \l swipeEnabled is false (a notification that is
        not dismissible, or the screen reader is on).
    \endlist

    \qml
    SwipeToReveal {
        width: parent.width; height: card.height
        onPrimaryAction: model.remove()
        onSecondaryAction: blockingMenu.open()
        NotificationCard { id: card; width: parent.width }
    }
    \endqml
*/
Item {
    id: swipe

    /*! The card. */
    default property alias content: _content.data
    /*! The card can be swiped. */
    property bool swipeEnabled: true
    /*! A secondary (settings) action is shown. */
    property bool hasSecondaryAction: true
    property string primaryText: qsTr("Clear")
    property string primaryIcon: "ios-close"
    property string secondaryIcon: "ios-settings"

    /*! Full reveal or a tap on the primary pill. */
    signal primaryAction()
    /*! A tap on the round secondary button. */
    signal secondaryAction()

    readonly property bool _isSwipeToReveal: true
    readonly property real _screenWidth: Screen.desktopAvailableWidth > 0 ? Screen.desktopAvailableWidth : Theme.dp(192)
    /*! The partial anchor (px, positive): 130 dp x width / 192 dp. */
    readonly property real revealingOffset: Theme.dp(130) * width / Theme.dp(192)
    /*! Past this (px) a release goes to the full reveal: 0.75 x 192 dp - 10 dp. */
    readonly property real fullThreshold: 0.75 * Theme.dp(192) - Theme.dp(10)
    /*! A fling faster than this (px/s, to the left) goes to the full reveal: 800 dp/s. */
    readonly property real flingVelocity: Theme.dp(800)
    /*! Touches starting in this left part of the screen are ignored while covered: 15 %. */
    readonly property real edgeExclusion: 0.15 * _screenWidth
    readonly property real touchSlop: Theme.dp(8)

    /*! The card's offset (px, 0 or negative). */
    property real offset: 0
    /*! "covered", "revealing" or "revealed". */
    property string state_: "covered"
    readonly property bool dragging: _area.tracking

    property real _lastHaptic: -1e9
    function _haptic() {
        var now = Date.now()
        if (now - _lastHaptic < 500)
            return
        _lastHaptic = now
        if (typeof Haptics.gestureThreshold === "function")
            Haptics.gestureThreshold()
        else
            Haptics.click()
    }

    /*! Animate to an anchor: "covered", "revealing" or "revealed". */
    function settle(target) {
        var to = target === "revealed" ? -width : target === "revealing" ? -revealingOffset : 0
        if (target !== "covered" && state_ !== target)
            _haptic()
        if (target !== "covered")
            _coverOthers()
        state_ = target
        _anim.stop()
        _anim.to = to
        _anim.restart()
    }
    /*! Cover at once (another card opened, the list changed). */
    function reset() {
        _anim.stop()
        offset = 0
        state_ = "covered"
    }
    function _coverOthers() {
        if (!parent)
            return
        var kids = parent.children
        for (var i = 0; i < kids.length; i++) {
            var k = kids[i]
            if (k !== swipe && k._isSwipeToReveal === true && k.state_ !== "covered")
                k.settle("covered")
        }
    }

    NumberAnimation {
        id: _anim
        target: swipe
        property: "offset"
        duration: Motion.springDuration(Motion.standard.defaultSpatial.stiffness)
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Motion.springEasing
        onFinished: if (swipe.state_ === "revealed") swipe.primaryAction()
    }

    clip: true

    // the revealed actions, in the space the card leaves at the right
    Item {
        id: _actions
        // the swipe runs right to left in every language (as the back swipe is not mirrored): the
        // actions behind the card keep their physical places
        LayoutMirroring.enabled: false
        LayoutMirroring.childrenInherit: true
        anchors {
            right: parent.right
            top: parent.top
            bottom: parent.bottom
        }
        width: -swipe.offset
        visible: width > 0
        readonly property bool _full: -swipe.offset > swipe.revealingOffset + Theme.dp(4)
        readonly property real _gap: Theme.dp(4)

        MouseArea {
            id: _secondary
            readonly property real size: Math.min(Theme.size.iconButton, swipe.height)
            visible: swipe.hasSecondaryAction
            opacity: _actions._full ? 0 : 1
            width: visible ? size : 0
            height: size
            anchors {
                left: parent.left
                leftMargin: _actions._gap
                verticalCenter: parent.verticalCenter
            }
            enabled: swipe.state_ === "revealing"
            onClicked: { swipe.settle("covered"); swipe.secondaryAction() }
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Theme.color.primaryContainer
                Ripple { radius: parent.radius; color: Theme.color.onPrimaryContainer; pressed: _secondary.pressed; pressX: _secondary.mouseX; pressY: _secondary.mouseY }
            }
            Icon {
                anchors.centerIn: parent
                width: Theme.size.iconSmall
                height: width
                name: swipe.secondaryIcon
                color: Theme.color.onPrimaryContainer
            }
        }

        MouseArea {
            id: _primary
            anchors {
                right: parent.right
                rightMargin: _actions._gap
                verticalCenter: parent.verticalCenter
            }
            width: Math.max(0, _actions._full || !swipe.hasSecondaryAction
                               ? parent.width - 2 * _actions._gap
                               : parent.width - _secondary.width - 3 * _actions._gap)
            height: Math.min(Theme.dp(84), swipe.height)
            enabled: swipe.state_ === "revealing"
            onClicked: swipe.settle("revealed")
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Theme.color.primaryDim
                Ripple { radius: parent.radius; color: Theme.color.onPrimary; pressed: _primary.pressed; pressX: _primary.mouseX; pressY: _primary.mouseY }
            }
            Row {
                anchors.centerIn: parent
                spacing: Theme.space.s
                Icon {
                    width: Theme.size.iconSmall
                    height: width
                    name: swipe.primaryIcon
                    color: Theme.color.onPrimary
                    anchors.verticalCenter: parent.verticalCenter
                }
                Label {
                    text: swipe.primaryText
                    role: "labelMedium"
                    color: Theme.color.onPrimary
                    visible: _primary.width > Theme.dp(80)
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    Item {
        id: _content
        width: parent.width
        height: parent.height
        x: swipe.offset
    }

    MouseArea {
        id: _area
        anchors.fill: _content
        enabled: swipe.swipeEnabled
        propagateComposedEvents: true
        property bool tracking: false
        property bool ignore: false
        property real startX: 0
        property real startY: 0
        property real startOffset: 0
        property real lastX: 0
        property real lastT: 0
        property real velocity: 0

        onPressed: (mouse) => {
            var p = mapToItem(null, mouse.x, mouse.y)
            ignore = swipe.state_ === "covered" && p.x < swipe.edgeExclusion
            if (ignore) {
                mouse.accepted = false
                return
            }
            _anim.stop()
            tracking = false
            startX = p.x; startY = p.y
            startOffset = swipe.offset
            lastX = p.x; lastT = Date.now(); velocity = 0
        }
        onPositionChanged: (mouse) => {
            var p = mapToItem(null, mouse.x, mouse.y)
            var dx = p.x - startX, dy = p.y - startY
            if (!tracking) {
                if (Math.abs(dx) < swipe.touchSlop && Math.abs(dy) < swipe.touchSlop)
                    return
                if (Math.abs(dx) <= Math.abs(dy) || (dx > 0 && swipe.state_ === "covered"))
                    return   // vertical: the list scrolls; rightwards: the back swipe
                tracking = true
                preventStealing = true
            }
            var now = Date.now()
            if (now > lastT)
                velocity = 0.6 * velocity + 0.4 * (p.x - lastX) * 1000 / (now - lastT)
            lastX = p.x; lastT = now
            swipe.offset = Math.max(-swipe.width, Math.min(0, startOffset + dx))
            if (-swipe.offset >= swipe.revealingOffset && swipe.state_ === "covered") {
                swipe.state_ = "revealing"
                swipe._coverOthers()
                swipe._haptic()
            }
        }
        onReleased: (mouse) => {
            preventStealing = false
            if (!tracking) {
                // a tap on a revealed card covers it again
                if (swipe.state_ !== "covered")
                    swipe.settle("covered")
                return
            }
            tracking = false
            swipe.release(-swipe.offset, velocity)
        }
        onClicked: (mouse) => { mouse.accepted = swipe.state_ !== "covered" }
        onCanceled: {
            preventStealing = false
            if (tracking) {
                tracking = false
                swipe.release(-swipe.offset, 0)
            }
        }
    }

    /*!
        Stock's decision for a swipe of \a distance px (to the left) released
        at \a velocity px/s (negative = to the left).
    */
    function decide(distance, velocity) {
        if (distance >= fullThreshold || velocity <= -flingVelocity)
            return "revealed"
        return distance >= revealingOffset / 2 ? "revealing" : "covered"
    }
    function release(distance, velocity) {
        settle(decide(distance, velocity))
    }
}
