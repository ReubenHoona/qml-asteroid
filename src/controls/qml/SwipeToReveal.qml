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

    \brief Swipe a card to the side to reveal its actions (E23 of the
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

    Two options take the Wear OS 6 emulator's stream (S34, S34-b, M10, V10);
    both are off by default, so a list that does not set them (the Timer's)
    keeps the CP3A behaviour and look:
    \list
    \li \l bidirectional: a covered card follows the finger both ways after
        the slop, the offset in [-width, +width]. The anchors and \l decide
        are mirrored by the side (|offset| for the thresholds, the fling
        towards that side), and the actions sit on the side the card leaves.
        The left 15 % edge exclusion stays.
    \li \l expressiveLook: the pill \c{Theme.color.swipeRevealContainer}
        #343B4D, its outer edge on the card's rest edge, 2 dp from the
        card (|offset| - 4 px wide) and the card's height less 4 px; a 24 dp
        close glyph in onPrimaryContainer #D9E0F7, fading in as the pill
        grows from 24 to 40 dp (V10: none at 42 px, 38 % at 62 px, full at
        80 px); \l primaryText in titleMedium (16 sp) at onPrimaryContainer
        80 %, fading in from 75 % to 100 % of the card's width, the two
        centred as a group with 8 dp between them; the secondary button a
        #343B4D 52 dp disc with an onPrimaryContainer gear on the pill's
        inner side. The card is clipped to its rest bounds, a plain
        rectangle (S34: square at the bottom corner; the round top corner
        there is the screen's edge).
        The card starts to move \l dragLag (29 dp) after the press and then
        follows the finger 1:1: S34 / S34-b held 160 px from the press show
        the card 102 px out, and M10 / V10 (260 px in 200 ms) move it 22 px a
        frame, the finger's 21.7, about 55 px behind the finger all the way
        (so not a ratio: 0.64 x 260 = 166 px, the card reached 174-192 px).
        The thresholds compare with the card's offset as before; the fling
        speed is the finger's, which the card moves at once it moves.
    \endlist
    Thresholds, the partial anchor, haptics, the edge exclusion and the
    1500 / 1.0 settle spring stay CP3A in both.

    \qml
    SwipeToReveal {
        width: parent.width; height: card.height
        bidirectional: true
        expressiveLook: true
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
    /*! The card follows the finger both ways (the Wear OS 6 stream). */
    property bool bidirectional: false
    /*! The Wear OS 6 emulator's pill (see above). */
    property bool expressiveLook: false
    property string primaryText: qsTr("Clear")
    property string primaryIcon: expressiveLook ? "ms-close" : "ios-close"
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
    /*! A fling faster than this (px/s, towards the side) goes to the full reveal: 800 dp/s. */
    readonly property real flingVelocity: Theme.dp(800)
    /*! Touches starting in this left part of the screen are ignored while covered: 15 %. */
    readonly property real edgeExclusion: 0.15 * _screenWidth
    readonly property real touchSlop: Theme.dp(8)
    /*! Finger travel (px) the card loses at the start of each drag: 29 dp with
        \l expressiveLook (S34, M10), 0 (CP3A) without. */
    readonly property real dragLag: expressiveLook ? Theme.dp(29) : 0

    /*! The card's offset (px): negative to the left; positive to the right
        with \l bidirectional. */
    property real offset: 0
    /*! "covered", "revealing" or "revealed". */
    property string state_: "covered"
    readonly property bool dragging: _area.tracking
    /*! The side the card went to: -1 left (the actions at the right), 1
        right (the actions at the left), 0 covered. */
    readonly property int side: offset > 0 ? 1 : offset < 0 ? -1 : 0

    /*! The expressive pill's colour (#343B4D). */
    readonly property color _pillColor: Theme.color.swipeRevealContainer

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

    // the side a settle goes to: where the card is, else the last side (left at first)
    property int _lastSide: -1
    onSideChanged: if (side !== 0) _lastSide = side

    /*! Animate to an anchor: "covered", "revealing" or "revealed", on the
        card's side; velocity (px/s, negative = to the left) is the finger's
        when it lets go. */
    function settle(target, velocity) {
        var s = side !== 0 ? side : _lastSide
        var to = target === "revealed" ? s * width : target === "revealing" ? s * revealingOffset : 0
        if (target !== "covered" && state_ !== target)
            _haptic()
        if (target !== "covered")
            _coverOthers()
        state_ = target
        _anim.animateTo(to, velocity === undefined ? NaN : velocity)
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

    /* the settle: AnchoredDraggable's default spring, 1.0/1500 (motion E12; no override was
     * found in SysUI), from the speed the finger let go at */
    WearSpring {
        id: _anim
        target: swipe
        property: "offset"
        stiffness: 1500
        dampingRatio: 1.0
        visibilityThreshold: 0.5
        onFinished: if (swipe.state_ === "revealed") swipe.primaryAction()
    }

    clip: true

    // the revealed actions, in the space the card leaves
    Item {
        id: _actions
        // the swipe keeps its physical sides in every language (as the back swipe is not mirrored): the
        // actions behind the card keep their physical places
        LayoutMirroring.enabled: false
        LayoutMirroring.childrenInherit: true
        // the card went right: the actions at the left
        readonly property bool _left: swipe.offset > 0
        x: _left ? 0 : parent.width - width
        height: parent.height
        width: Math.abs(swipe.offset)
        visible: width > 0
        readonly property bool _full: Math.abs(swipe.offset) > swipe.revealingOffset + Theme.dp(4)
        // CP3A: 4 dp around the pill; expressive: the pill on the card's rest
        // edge and 2 dp from the card
        readonly property real _gap: swipe.expressiveLook ? Theme.dp(2) : Theme.dp(4)
        readonly property real _outer: swipe.expressiveLook ? 0 : _gap

        MouseArea {
            id: _secondary
            objectName: "swipeRevealSecondary"
            readonly property real size: Math.min(Theme.size.iconButton, swipe.height)
            visible: swipe.hasSecondaryAction
            opacity: _actions._full ? 0 : 1
            width: visible ? size : 0
            height: size
            // on the inner side, next to the card
            x: _actions._left ? _actions.width - _actions._gap - width : _actions._gap
            anchors.verticalCenter: parent.verticalCenter
            enabled: swipe.state_ === "revealing"
            onClicked: { swipe.settle("covered"); swipe.secondaryAction() }
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: swipe.expressiveLook ? swipe._pillColor : Theme.color.primaryContainer
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
            objectName: "swipeRevealPill"
            width: Math.max(0, _actions._full || !swipe.hasSecondaryAction
                               ? parent.width - _actions._outer - _actions._gap
                               : parent.width - _secondary.width - _actions._outer - 2 * _actions._gap)
            // on the outer side, at the card's rest edge
            x: _actions._left ? _actions._outer : parent.width - _actions._outer - width
            height: swipe.expressiveLook ? Math.max(0, swipe.height - Theme.dp(2)) : Math.min(Theme.dp(84), swipe.height)
            anchors.verticalCenter: parent.verticalCenter
            enabled: swipe.state_ === "revealing"
            onClicked: swipe.settle("revealed")
            Rectangle {
                anchors.fill: parent
                radius: Math.min(width, height) / 2
                color: swipe.expressiveLook ? swipe._pillColor : Theme.color.primaryDim
                Ripple {
                    radius: parent.radius
                    color: swipe.expressiveLook ? Theme.color.onPrimaryContainer : Theme.color.onPrimary
                    pressed: _primary.pressed; pressX: _primary.mouseX; pressY: _primary.mouseY
                }
            }
            Row {
                visible: !swipe.expressiveLook
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
            // the expressive pill's content: the glyph, then the label near a
            // full swipe, centred as a group
            Item {
                id: _group
                visible: swipe.expressiveLook
                anchors.fill: parent
                readonly property real spacing: Theme.dp(8)
                /*! 0 -> 1 as the pill grows from 24 to 40 dp. */
                readonly property real iconAlpha: Math.max(0, Math.min(1, (_primary.width - Theme.size.iconSmall) / Theme.dp(16)))
                /*! 0 -> 1 from 75 % to 100 % of the card's width. */
                readonly property real labelAlpha: swipe.width > 0
                    ? Math.max(0, Math.min(1, (Math.abs(swipe.offset) / swipe.width - 0.75) / 0.25)) : 0
                readonly property real groupWidth: _xIcon.width + labelAlpha * (spacing + _xLabel.implicitWidth)
                Icon {
                    id: _xIcon
                    objectName: "swipeRevealIcon"
                    x: (_group.width - _group.groupWidth) / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.size.iconSmall
                    height: width
                    name: swipe.primaryIcon
                    color: Theme.color.onPrimaryContainer
                    opacity: _group.iconAlpha
                }
                Label {
                    id: _xLabel
                    objectName: "swipeRevealLabel"
                    x: _xIcon.x + _xIcon.width + _group.spacing
                    anchors.verticalCenter: parent.verticalCenter
                    text: swipe.primaryText
                    role: "titleMedium"
                    color: Qt.rgba(Theme.color.onPrimaryContainer.r, Theme.color.onPrimaryContainer.g, Theme.color.onPrimaryContainer.b, 0.8)
                    opacity: _group.labelAlpha
                    visible: opacity > 0
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
        // the card moves (the finger went dragLag from the press), on that side
        property bool engaged: false
        property int lagSide: 0
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
            engaged = false
            lagSide = 0
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
                // vertical: the list scrolls; rightwards on a covered card: the
                // back swipe (unless the card goes both ways)
                if (Math.abs(dx) <= Math.abs(dy) || (dx > 0 && swipe.state_ === "covered" && !swipe.bidirectional))
                    return
                tracking = true
                preventStealing = true
            }
            var now = Date.now()
            if (now > lastT)
                velocity = 0.6 * velocity + 0.4 * (p.x - lastX) * 1000 / (now - lastT)
            lastX = p.x; lastT = now
            if (!engaged) {
                if (Math.abs(dx) < swipe.dragLag)
                    return
                engaged = true
                lagSide = dx > 0 ? 1 : -1
            }
            swipe.offset = Math.max(-swipe.width, Math.min(swipe.bidirectional ? swipe.width : 0, startOffset + dx - lagSide * swipe.dragLag))
            if (Math.abs(swipe.offset) >= swipe.revealingOffset && swipe.state_ === "covered") {
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
            // a drag the card did not follow yet is no fling
            swipe._release(engaged ? velocity : 0)
        }
        onClicked: (mouse) => { mouse.accepted = swipe.state_ !== "covered" }
        onCanceled: {
            preventStealing = false
            if (tracking) {
                tracking = false
                swipe._release(0)
            }
        }
    }

    /*!
        Stock's decision for a swipe of \a distance px (towards the card's
        side) released at \a velocity px/s (negative = towards that side).
    */
    function decide(distance, velocity) {
        if (distance >= fullThreshold || velocity <= -flingVelocity)
            return "revealed"
        return distance >= revealingOffset / 2 ? "revealing" : "covered"
    }
    /*! A release \a distance px to the left at \a velocity px/s (negative =
        to the left). */
    function release(distance, velocity) {
        settle(decide(distance, velocity), velocity)
    }
    // a release where the card is, mirrored by its side; velocity in px/s (negative = left)
    function _release(velocity) {
        var s = side !== 0 ? side : -1
        settle(decide(Math.abs(offset), -s * velocity), velocity)
    }
}
