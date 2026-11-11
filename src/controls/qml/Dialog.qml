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
import Nemo.KeepAlive
import org.asteroid.controls

/*!
    \qmltype Dialog
    \inqmlmodule org.asteroid.controls

    \brief The Wear OS Material 3 dialog container (E01): a full-screen,
    opaque black window over the screen it belongs to.

    Stock CP3A (androidx.wear.compose.material3 Dialog, Settings decomp
    DialogKt$$ExternalSyntheticLambda0.java:67-68,148,173-175,218,255,
    DialogKt.java:108, MotionSchemeKt$$ExternalSyntheticLambda0.java:13-18,
    AnimationSpecUtilsKt.java:115-126):
    \list
    \li no window dim (setDimAmount(0)); the background is opaque #000000;
    \li show: alpha 0 -> 1 on a critically damped spring of stiffness 3150
        (fastEffects 1400 made 50 % faster: 1400 x 1.5^2), the content scale
        1.25 -> 1.0 on stiffness 1125 (defaultEffects 500 x 1.5^2);
    \li hide: alpha 1 -> 0 on fastEffects (1400), the content scale
        1.0 -> 1.25 on 1125;
    \li \l behind (the screen under the dialog) scales 1.0 -> 0.85 on show
        and back on hide, on 1125;
    \li a swipe right drags the dialog with the finger while \l behind scales
        lerp(0.85, 1.0, dx / width); stock's back decision (BackSwipeArea)
        dismisses it;
    \li Reduce animations makes every spring land at once (WearSpring).
    \endlist

    Nothing runs while the dialog is hidden or once its springs have
    settled. \l keepScreenOn holds the display on (Nemo.KeepAlive) only while
    the dialog is shown; confirmations set it, alert dialogs never do.

    \qml
    Dialog {
        id: dialog
        behind: page
        onDismissRequested: close()
        Label { anchors.centerIn: parent; text: "Hello" }
    }
    \endqml
*/
Item {
    id: dialog

    /*! The screen under the dialog: scaled to \l behindScale while shown. */
    property Item behind: null
    /*! A swipe right dismisses the dialog. */
    property bool swipeToDismiss: true
    /*! Close the dialog by itself when it is swiped away. */
    property bool closeOnSwipe: true
    /*! Hold the display on while shown (confirmations only, as stock). */
    property bool keepScreenOn: false

    /*! The display is held on now (\l keepScreenOn and shown). */
    readonly property bool holdingDisplay: keepScreenOn && _shown
    /*! The dialog is shown (between \l open() and \l close()). */
    readonly property bool shown: _shown
    /*! The dialog is on screen, entering, shown or leaving. */
    readonly property bool active: _shown || _alpha.value > 0.001 || _alpha.running
    /*! The content, scaled by the entry and exit. */
    default property alias contentData: _content.data
    readonly property alias content: _content
    /*! The dialog surface (background and content), moved by the swipe. */
    readonly property alias surface: _surface

    /*! Window alpha now. */
    readonly property real alpha: _alpha.value
    /*! Content scale now. */
    readonly property real contentScale: _scale.value
    /*! Horizontal offset of the surface from the swipe, px. */
    readonly property real swipeOffset: _surface.x

    /* ---- stock numbers ---- */
    /*! Content scale at the start of the entry and the end of the exit. */
    readonly property real enterScale: 1.25
    /*! Scale of \l behind while the dialog shows. */
    readonly property real behindScale: 0.85
    /*! faster(50 %, fastEffects 1400): 3150. */
    readonly property real alphaInStiffness: Motion.faster(Motion.standard.fastEffects, 50).stiffness
    /*! fastEffects: 1400. */
    readonly property real alphaOutStiffness: Motion.standard.fastEffects.stiffness
    /*! faster(50 %, defaultEffects 500): 1125, for the content and \l behind. */
    readonly property real scaleStiffness: Motion.faster(Motion.standard.defaultEffects, 50).stiffness

    /*! Emitted by \l open(). */
    signal opened()
    /*! Emitted once the exit animation has finished. */
    signal closed()
    /*! The dialog was swiped away (stock onDismissRequest). */
    signal dismissRequested()

    /*! Show the dialog. */
    function open() {
        if (_shown)
            return
        if (!active) {
            _alpha.snapTo(0)
            _scale.snapTo(enterScale)
            _drag.snapTo(0)
        }
        _shown = true
        _alpha.stiffness = alphaInStiffness
        _alpha.animateTo(1)
        _scale.animateTo(1)
        if (behind) {
            _behind.target = behind
            _behind.animateTo(behindScale)
        }
        opened()
    }

    /*! Hide the dialog. */
    function close() {
        if (!_shown)
            return
        _shown = false
        _alpha.stiffness = alphaOutStiffness
        _alpha.animateTo(0)
        _scale.animateTo(enterScale)
        if (_behind.target)
            _behind.animateTo(1)
    }

    property bool _shown: false

    anchors.fill: parent
    visible: active
    opacity: _alpha.value
    z: 1000

    WearSpring {
        id: _alpha
        dampingRatio: 1.0
        visibilityThreshold: 0.002
        onFinished: {
            if (!dialog._shown && value <= 0.002) {
                _drag.snapTo(0)
                dialog.closed()
            }
        }
    }
    WearSpring {
        id: _scale
        stiffness: dialog.scaleStiffness
        dampingRatio: 1.0
        visibilityThreshold: 0.0005
    }
    WearSpring {
        id: _behind
        property: "scale"
        stiffness: dialog.scaleStiffness
        dampingRatio: 1.0
        visibilityThreshold: 0.0005
    }
    // the swipe offset in px once the finger has let go
    WearSpring {
        id: _drag
        stiffness: Motion.inAppBack.settle.stiffness
        dampingRatio: 1.0
        visibilityThreshold: 0.5
    }

    // only dialogs that may hold the display (confirmations) talk to mce
    Loader {
        id: _blanking
        active: dialog.keepScreenOn
        sourceComponent: Component {
            DisplayBlanking {
                preventBlanking: dialog.holdingDisplay
            }
        }
    }

    BackSwipeArea {
        id: _swipe
        anchors.fill: parent
        swipeEnabled: dialog.swipeToDismiss && dialog._shown

        property bool tracking: false
        onStarted: {
            tracking = true
            _drag.snapTo(0)
        }
        onValueChanged: {
            if (!tracking)
                return
            _drag.snapTo(Math.max(0, value))
            if (_behind.target)
                _behind.snapTo(dialog.behindScale + (1 - dialog.behindScale) * progress)
        }
        onFinished: {
            tracking = false
            var v = velocity
            if (committed) {
                _drag.animateTo(dialog.width, v)
                dialog.dismissRequested()
                if (dialog.closeOnSwipe)
                    dialog.close()
            } else {
                _drag.animateTo(0, v)
                if (_behind.target)
                    _behind.animateTo(dialog.behindScale)
            }
            reset()
        }

        Item {
            id: _surface
            width: dialog.width
            height: dialog.height
            x: _drag.value

            Rectangle {
                anchors.fill: parent
                color: "#000000"
            }
            // the dialog takes every touch it does not use
            MouseArea {
                anchors.fill: parent
                enabled: dialog._shown
            }
            Item {
                id: _content
                anchors.fill: parent
                scale: _scale.value
            }
        }
    }
}
