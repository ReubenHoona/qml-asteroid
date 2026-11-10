/*
 * Copyright (C) 2016 Florent Revest <revestflo@gmail.com>
 *               2015 Tim Süberkrüb <tim.sueberkrueb@web.de>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as
 * published by the Free Software Foundation, either version 2.1 of the
 * License, or (at your option) any later version.
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
    \qmltype LayerStack
    \inqmlmodule org.asteroid.controls

    \brief A simple stack of QML components.

    This provides a way to manage a virtual stack of QML compoments
    and to navigate between them.

    Because \l LayerStack is a more advanced and complex control, the
    example program is longer than usual, but not too complex.  There 
    are three different \l Component elements defined, named "top", "one",
    and "two".  The \l firstPage of the \l LayerStack is set to the "top" 
    component, and the other components provide a means to navigate either
    deeper into the stack or back up, depending on which stack component
    it is.  The \l Component labeled "one" is the only one that can go
    either deeper (to "two") or up (to "top").

    \qml
    import QtQuick
    import org.asteroid.controls

    Item {
        Component {
            id: one
            Item {
                LabeledActionButton {
                    text: "Still deeper"
                    anchors.bottom: parent.verticalCenter
                    height: parent.height * 0.2
                    onClicked: stack.push(two)
                }
                LabeledActionButton {
                    text: "Back up"
                    anchors.top: parent.verticalCenter
                    height: parent.height * 0.2
                    onClicked: stack.pop(stack.currentLayer)
                }
            }
        }
        Component {
            id: two
            LabeledActionButton {
                text: "Deep enough"
                onClicked: stack.pop(stack.currentLayer)
            }
        }
        Component {
            id: top
            LabeledActionButton {
                text: "Go deeper"
                onClicked: stack.push(one)
            }
        }
        anchors.fill: parent
        LayerStack {
            id: stack
            firstPage: top
            win: null
        }
    }
    \endqml
*/
Item {
    id: layersStack
    anchors.fill: parent
    objectName: "LayerStack"

    /*! The top level page of the stack */
    property var firstPage
    /*! The collection of pages of the stack */
    property var layers: []
    /*! The current layer of the stack */
    property var currentLayer: layers.length > 0 ? layers[layers.length-1] : null
    property var firstPageItem
    /*! Can be set to null if you don't want indicators animations and systemgestures override. If your LayerStack isn't directly a child element of your window, you can also specify the window via this parameter. */
    property QtObject win: parent
    /*! False keeps the back swipe from popping the top page, for example while a stack inside that page has pages of its own to go back from first */
    property bool gesturesEnabled: true

    /*! True: go back only with a swipe from the left edge; false (the default): with a swipe right from anywhere, as Wear OS does, unless what is under the finger scrolls horizontally (see \l BackSwipeArea) */
    property bool edgeSwipeOnly: false

    /*! What each page is drawn on. Stock screens are opaque (black), so the two pages of a transition never show their text through each other; "transparent" shows what is behind the stack. */
    property color pageBackground: Theme.color.background

    /*! 0 at rest, 1 when the top page has gone: the in-app back (pop) progress */
    readonly property real backProgress: _popActive ? _p : 0
    /*! A page is sliding in */
    readonly property bool pushing: pushX.running || pushScale.running || pushAlpha.running
                                    || outScale.running || outX.running || outAlpha.running

    /* Wear OS motion (CP3A, Compose PredictiveBackNavHost, see Motion):
     * push: the new page from +W/2 (0.8/300), scale 0.8 -> 1 (1.0/500), fade in
     * (1.0/1500); the old page to scale 0.85 (1.0/150), -W/2 (0.8/200), alpha
     * 0.6 (1.0/1400), then hidden.
     * pop, linear in the back progress p: the top page x = W p, scale 1 ->
     * 0.8; the page below x = -W/2 (1 - p), scale 0.8 -> 1, alpha 0.5 -> 1;
     * commit and cancel on 1.0/1500 from where the finger left it. */
    property bool _popActive: false
    property bool _dragging: false
    readonly property real _p: _dragging ? gestureArea.smoothedProgress : popSpring.value
    property var _frames: []

    readonly property real _topX: _popActive ? width * _p : width * Motion.push.enterOffset * (1 - pushX.value)
    readonly property real _topScale: _popActive ? 1 - (1 - Motion.inAppBack.topScale) * _p
                                                 : Motion.push.enterScale + (1 - Motion.push.enterScale) * pushScale.value
    readonly property real _topOpacity: _popActive ? 1 : pushAlpha.value
    readonly property real _belowX: _popActive ? width * Motion.inAppBack.belowOffset * (1 - _p)
                                               : width * Motion.push.exitOffset * outX.value
    readonly property real _belowScale: _popActive ? Motion.inAppBack.belowScale + (1 - Motion.inAppBack.belowScale) * _p
                                                   : 1 - (1 - Motion.push.exitScale) * outScale.value
    readonly property real _belowOpacity: _popActive ? Motion.inAppBack.belowAlpha + (1 - Motion.inAppBack.belowAlpha) * _p
                                                     : 1 - (1 - Motion.push.exitAlpha) * outAlpha.value
    readonly property bool _belowVisible: _popActive || pushing

    component PushSpring: WearSpring {
        to: 1
        visibilityThreshold: 0.002
    }
    PushSpring {
        id: pushX
        stiffness: Motion.push.enterX.stiffness; dampingRatio: Motion.push.enterX.dampingRatio
        onFinished: if (win !== null) win.animIndicators()
    }
    PushSpring { id: pushScale; stiffness: Motion.push.enterScaleSpring.stiffness; dampingRatio: Motion.push.enterScaleSpring.dampingRatio }
    PushSpring { id: pushAlpha; stiffness: Motion.push.enterAlpha.stiffness; dampingRatio: Motion.push.enterAlpha.dampingRatio }
    PushSpring { id: outScale; stiffness: Motion.push.exitScaleSpring.stiffness; dampingRatio: Motion.push.exitScaleSpring.dampingRatio }
    PushSpring { id: outX; stiffness: Motion.push.exitX.stiffness; dampingRatio: Motion.push.exitX.dampingRatio }
    PushSpring { id: outAlpha; stiffness: Motion.push.exitAlphaSpring.stiffness; dampingRatio: Motion.push.exitAlphaSpring.dampingRatio }

    function _finishPush() {
        var springs = [pushX, pushScale, pushAlpha, outScale, outX, outAlpha]
        for (var i = 0; i < springs.length; i++)
            springs[i].snapTo(1)
    }

    WearSpring {
        id: popSpring
        to: 0
        stiffness: Motion.inAppBack.settle.stiffness
        dampingRatio: Motion.inAppBack.settle.dampingRatio
        visibilityThreshold: 0.002
        onFinished: layersStack._endBack(to >= 1)
    }

    function _endBack(popped) {
        if (popped && layers.length > 0)
            pop(currentLayer)
        _popActive = false
        _dragging = false
        popSpring.snapTo(0)
        gestureArea.reset()
        if (win !== null)
            win.animIndicators()
    }

    // The pages sit inside the back swipe area: it watches their touches
    // and takes a drag over once it clearly goes right
    BackSwipeArea {
        id: gestureArea
        anchors.fill: parent
        swipeEnabled: layers.length > 0 && layersStack.gesturesEnabled
        edgeOnly: layersStack.edgeSwipeOnly

        onStarted: {
            layersStack._finishPush()
            popSpring.snapTo(0)
            layersStack._dragging = true
            layersStack._popActive = true
        }

        onFinished: {
            // stock: go back from where the progress is, at its speed
            var p = gestureArea.smoothedProgress
            var v = gestureArea.smoothedVelocity
            popSpring.snapTo(p)
            layersStack._dragging = false
            popSpring.animateTo(gestureArea.committed ? 1 : 0, v)
        }
    }

    Component {
        id: frameComponent
        // One page and what it is drawn on, moved as one
        Item {
            id: frame
            property int index: 0
            readonly property int _count: layersStack._frames.length
            readonly property bool isTop: index === _count - 1
            readonly property bool isBelow: index === _count - 2
            width: layersStack.width
            height: layersStack.height
            clip: true
            visible: isTop || (isBelow && layersStack._belowVisible)
            opacity: isTop ? layersStack._topOpacity : isBelow ? layersStack._belowOpacity : 1
            transform: [
                Scale {
                    origin.x: frame.width / 2
                    origin.y: frame.height / 2
                    xScale: frame.isTop ? layersStack._topScale : frame.isBelow ? layersStack._belowScale : 1
                    yScale: xScale
                },
                Translate {
                    x: frame.isTop ? layersStack._topX : frame.isBelow ? layersStack._belowX : 0
                }
            ]
            Rectangle {
                anchors.fill: parent
                color: layersStack.pageBackground
            }
        }
    }

    function _newFrame() {
        var frame = frameComponent.createObject(gestureArea, { index: _frames.length })
        _frames.push(frame)
        _framesChanged()
        return frame
    }

    function _dropFrame() {
        var frame = _frames.pop()
        _framesChanged()
        if (frame)
            frame.destroy()
    }

    onFirstPageChanged: {
        if(typeof firstPage != 'undefined') {
            if (firstPageItem) {
                firstPageItem.destroy()
            }
            while (layers.length > 0) {
                pop(currentLayer)
            }
            while (_frames.length > 0)
                _dropFrame()
            var params = {}
            params["width"] = Qt.binding(function() { return width })
            params["height"] =  Qt.binding(function() { return height })
            params["x"] = 0
            params["y"] = 0
            if(typeof firstPage != 'undefined' && firstPage.status === Component.Ready) {
                firstPageItem=firstPage.createObject(_newFrame(), params)
                firstPageItem.clip = true
                layersChanged()
            }
        } else {
            console.log("LayerStack: firstpage has been updated with a null value")
        }
    }

    function push(component, params) {
        if (component.status === Component.Ready) {
            if (typeof params === 'undefined') params = {}
            params["width"] = Qt.binding(function() { return width })
            params["height"] =  Qt.binding(function() { return height })
            params["depth"] = (layers.length+1)
            params["x"] = 0
            params["y"] = 0
            params["clip"] = true

            var layer;
            params["pop"] = function() { layersStack.popAnim(); }
            if (_popActive)
                _endBack(false)
            layer = component.createObject(_newFrame(), params);
            layers.push(layer);
            var springs = [pushX, pushScale, pushAlpha, outScale, outX, outAlpha]
            for (var i = 0; i < springs.length; i++)
                springs[i].snapTo(0)
            for (i = 0; i < springs.length; i++)
                springs[i].animateTo(1, 0)
            if(win !== null)
                win.setOverridesSystemGestures(layers.length > 0)
            layersChanged();
            return layer
        }
    }

    /*! Pops the top page with the stock pop transition (as a committed back swipe from rest) */
    function popAnim() {
        if (layers.length === 0 || _popActive)
            return
        _finishPush()
        popSpring.snapTo(0)
        _dragging = false
        _popActive = true
        popSpring.animateTo(1, 0)
    }

    /*! Removes the top page at once */
    function pop(layer) {
        if (layers.length === 0)
            return
        layers.pop(layer);
        _dropFrame()
        if(win !== null)
            win.setOverridesSystemGestures(layers.length > 0)
        layersChanged();
        if(win !== null)
            win.animIndicators()
    }
}
