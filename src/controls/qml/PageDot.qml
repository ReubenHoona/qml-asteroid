/*
 * Copyright (C) 2016 - Florent Revest <revestflo@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
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
import QtQuick.Window
import org.asteroid.controls
import org.asteroid.utils

/*!
    \qmltype PageDot
    \inqmlmodule org.asteroid.controls

    \brief Display indicator dots indicating a fixed collection.

    The \l PageDot control shows a series of dots with one dot
    highlighted.  This is typically used to show a series of pages
    or other items and to indicate where within the collection
    one currently is.

    On a round screen it draws the stock curved page indicator along the
    bottom of the screen (\l ArcPageIndicator; stock paged screens never use
    a straight row, PageIndicator.kt, E40), whatever its own position. The
    arc is drawn over the page the dots belong to (\l arcPage: the nearest
    ancestor that covers the window, such as an application page, a layer of
    a LayerStack or a launcher panel), as stock aligns HorizontalPageIndicator
    to the bottom centre of its screen. It stays a child of the PageDot, so
    it takes the caller's opacity, visibility, clipping and stacking, and it
    moves with the page while the page is swiped. On a square screen it keeps
    the straight row. Unselected dots are at 30 %.

    Here is a short example:

    \qml
    import QtQuick
    import org.asteroid.controls

    Item {
        PageDot {
            height: parent.height * 0.03
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.bottom
                bottomMargin: parent.height * 0.04
            }
            dotNumber: 5
            currentIndex: 2
        }
    }
    \endqml
*/
Item {
    id: pageDot

    width: height*5/4*(dotNumber+(additionalDot ? 1 : 0))
    visible: additionalDot ? dotNumber > 0 : dotNumber > 1

    property int currentIndex: 0
    property int dotNumber: 0
    property bool additionalDot: false
    property string additionalDotText: "+"

    /*! Draw the curved indicator over the page (round screens). */
    readonly property bool arc: DeviceSpecs.hasRoundScreen && Window.window !== null
    /*! The curved indicator (for tests). */
    readonly property alias arcIndicator: _arc
    /*! The item whose bottom arc carries the dots: the nearest ancestor that
        covers the window (else the window's content item). */
    readonly property Item arcPage: _page

    property Item _page: null
    property rect _pageRect: Qt.rect(0, 0, 0, 0)
    property var _watched: []

    function _findPage() {
        var w = pageDot.Window.width, h = pageDot.Window.height
        for (var it = pageDot.parent; it; it = it.parent) {
            if (w > 0 && h > 0 && it.width >= w - 1 && it.height >= h - 1)
                return it
        }
        return pageDot.Window.contentItem
    }
    // the page in this item's coordinates (transforms included)
    function _place() {
        if (!_page) { _pageRect = Qt.rect(0, 0, 0, 0); return }
        var a = pageDot.mapFromItem(_page, 0, 0)
        var b = pageDot.mapFromItem(_page, _page.width, _page.height)
        _pageRect = Qt.rect(a.x, a.y, b.x - a.x, b.y - a.y)
    }
    function _watch(o, sig, fn) {
        o[sig].connect(fn)
        _watched.push([o, sig, fn])
    }
    function _unwatch() {
        for (var i = 0; i < _watched.length; i++) {
            try { _watched[i][0][_watched[i][1]].disconnect(_watched[i][2]) } catch (e) {}
        }
        _watched = []
    }
    function _queueRewatch() { Qt.callLater(pageDot._rewatch) }
    /*  Event driven, no timer: the page is looked up again when an ancestor
        is reparented or resized, and the arc is placed again when this item
        or an item between it and the page moves. The page itself moving (a
        swipe, a LayerStack pop) needs nothing: the arc is its descendant. */
    function _rewatch() {
        _unwatch()
        if (!arc) { _page = null; _place(); return }
        _page = _findPage()
        var below = true
        for (var it = pageDot; it; it = it.parent) {
            if (it === _page)
                below = false
            _watch(it, "parentChanged", _queueRewatch)
            _watch(it, "widthChanged", _queueRewatch)
            _watch(it, "heightChanged", _queueRewatch)
            if (below) {
                _watch(it, "xChanged", _place)
                _watch(it, "yChanged", _place)
                _watch(it, "scaleChanged", _place)
                _watch(it, "rotationChanged", _place)
            }
        }
        _place()
    }
    onArcChanged: _queueRewatch()
    Component.onCompleted: _rewatch()
    Component.onDestruction: _unwatch()

    ArcPageIndicator {
        id: _arc
        anchors.fill: undefined
        x: pageDot._pageRect.x
        y: pageDot._pageRect.y
        width: pageDot._pageRect.width
        height: pageDot._pageRect.height
        visible: pageDot.arc && pageDot._page !== null
        count: pageDot.dotNumber + (pageDot.additionalDot ? 1 : 0)
        position: pageDot.currentIndex
    }

    Row {
        anchors.fill: parent
        spacing: height/4
        visible: !pageDot.arc
        Repeater {
            model: dotNumber
            Rectangle {
                width: parent.height
                height: parent.height
                radius: parent.height
                color: Theme.color.onBackground
                opacity: index == currentIndex ? 1 : Theme.alpha.pageDotUnselected
            }
        }
        Label {
            text: additionalDotText
            width: additionalDot ? parent.height : 0
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            opacity: currentIndex == dotNumber ? 1 : Theme.alpha.pageDotUnselected
            visible: additionalDot
        }
    }
}
