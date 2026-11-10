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
import QtQuick.Shapes
import org.asteroid.controls

/*!
    \qmltype EdgeButton
    \inqmlmodule org.asteroid.controls

    \brief The Wear OS edge button (E07, E47): the arch-shaped primary action
    hugging the bottom of the round screen.

    Stock (EdgeButtonKt.java:147,274-276, ShapeHelper.java:28-52,
    EdgeButtonShape.java):
    \list
    \li Heights 46 / 56 / 70 / 96 dp (\c{Theme.size.edgeButtonExtraSmall},
        \c edgeButtonSmall (default), \c edgeButtonMedium,
        \c edgeButtonLarge); \l preferredHeight.
    \li The shape: an ellipse 58 dp tall at 46 dp plus 1.42 x the extra
        height, half as wide as sqrt(its half height x (W/2 - 3 dp)), its
        bottom 3 dp above the screen edge; the top corners are circles tangent
        to the top and to the ellipse. Below 46 dp (while it is revealed) the
        ellipse turns into the button height and the content fades.
    \li Filled colours (primary / onPrimary); label labelMedium centred, up
        to 2 lines; content kept inside the arch (20 dp from the screen edge
        at the content's height).
    \li In a scrolling screen (\l flickable) the list keeps \l contentPadding
        free at its end (the button height - 3 dp + 16 dp: set it as the
        flickable's bottomMargin) and the button is held back by the scroll
        distance left, so it grows into view at the end; when the list is
        not moving it settles with the stiffness 400 spring (about 332 ms).
    \endlist

    \qml
    Flickable {
        id: list
        anchors.fill: parent
        bottomMargin: edge.contentPadding
        ...
    }
    EdgeButton { id: edge; flickable: list; text: qsTr("Done"); onClicked: done() }
    \endqml
*/
MouseArea {
    id: edgeButton

    /*! The label. */
    property string text: ""
    /*! An icon name (shown above or instead of the label). */
    property string iconName: ""
    /*! Height of the button when shown in full (px). */
    property real preferredHeight: Theme.size.edgeButton
    /*! The list it ends; null: always shown in full. */
    property Item flickable: null

    function _a(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
    property color containerColor: enabled ? Theme.color.primary : _a(Theme.color.onSurface, Theme.alpha.disabledContainer)
    property color contentColor: enabled ? Theme.color.onPrimary : _a(Theme.color.onSurface, Theme.alpha.disabledContent)

    /*! Space the list keeps free at its end: the height - 3 dp + 16 dp. */
    readonly property real contentPadding: preferredHeight - Theme.size.edgeButtonBottomGap + Theme.dp(16)

    /*! Scroll distance left to the end of \l flickable (px). */
    readonly property real remainingScroll: {
        var f = flickable
        if (!f)
            return 0
        var maxY = f.originY + f.contentHeight + f.bottomMargin - f.height
        return Math.max(0, maxY - f.contentY)
    }
    readonly property real _target: Math.max(0, Math.min(preferredHeight, preferredHeight - remainingScroll))
    /*! The height shown now. */
    property real shownHeight: _target
    Behavior on shownHeight {
        enabled: !edgeButton.flickable || !edgeButton.flickable.moving
        NumberAnimation {
            duration: Motion.springDuration(400)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.springEasing
        }
    }

    width: parent ? parent.width : Theme.dp(192)
    height: shownHeight
    visible: shownHeight > 0.5
    anchors.bottom: parent ? parent.bottom : undefined
    anchors.bottomMargin: Theme.size.edgeButtonBottomGap

    Accessible.role: Accessible.Button
    Accessible.name: text

    /*!
        The shape for a button \a W x \a H px (ShapeHelper and
        EdgeButtonShape): ellipse half axes a, b and centre cy; top corner
        circles of radius k at (qx, qy) and (W - qx, qy) sweeping \c sweep
        degrees; \c th the ellipse start angle; \c fade (finalFadeProgress);
        \c sidePadding and \c contentHalfWidth for the content window.
    */
    function geometry(W, H) {
        var bp = Theme.size.edgeButtonBottomGap
        var xs = Theme.size.edgeButtonExtraSmall
        var fp = Math.max(0, 1 - H / xs)
        var E = ((H - xs) * 1.42 + Theme.dp(58)) * (1 - fp) + H * fp
        var R = W / 2 - bp
        var b = E / 2
        var a = Math.min(Math.sqrt(b * R), R)
        var th = fp * Math.PI / 2
        var cx = W / 2, cy = H - b
        var px = cx + Math.cos(th) * a, py = cy + Math.sin(th) * b
        var tx = Math.sin(th) * a, ty = -b * Math.cos(th)
        var tl = Math.sqrt(tx * tx + ty * ty)
        tx /= tl; ty /= tl
        var k = py / (tx + 1)
        var qx = px + ty * k, qy = py - tx * k
        var sweep = Math.atan2(py - qy, px - qx) * 180 / Math.PI + 90
        var hw = W / 2, dy = W / 2 - bp - E / 2
        var side = W / 2 - Math.sqrt(Math.max(0, hw * hw - dy * dy)) + Theme.size.edgeButtonSideMargin
        var r = H - E / 2
        return { a: a, b: b, cx: cx, cy: cy, k: k, qx: qx, qy: qy, sweep: sweep,
                 th: th * 180 / Math.PI, fade: fp, ellipseHeight: E,
                 sidePadding: side, contentHalfWidth: Math.max(0, (W - 2 * side) / 2 - r) }
    }
    readonly property var shape: geometry(width, Math.max(1, height))

    Shape {
        id: _shape
        anchors.fill: parent
        ShapePath {
            strokeWidth: -1
            strokeColor: "transparent"
            fillColor: edgeButton.containerColor
            startX: edgeButton.shape.qx
            startY: edgeButton.shape.qy - edgeButton.shape.k
            PathAngleArc {
                centerX: edgeButton.shape.qx; centerY: edgeButton.shape.qy
                radiusX: edgeButton.shape.k; radiusY: edgeButton.shape.k
                startAngle: 270; sweepAngle: edgeButton.shape.sweep
                moveToStart: false
            }
            PathAngleArc {
                centerX: edgeButton.shape.cx; centerY: edgeButton.shape.cy
                radiusX: edgeButton.shape.a; radiusY: edgeButton.shape.b
                startAngle: edgeButton.shape.th; sweepAngle: 180 - 2 * edgeButton.shape.th
                moveToStart: false
            }
            PathAngleArc {
                centerX: edgeButton.width - edgeButton.shape.qx; centerY: edgeButton.shape.qy
                radiusX: edgeButton.shape.k; radiusY: edgeButton.shape.k
                startAngle: 270 - edgeButton.shape.sweep; sweepAngle: edgeButton.shape.sweep
                moveToStart: false
            }
            PathLine { x: edgeButton.shape.qx; y: edgeButton.shape.qy - edgeButton.shape.k }
        }
    }

    Item {
        // the arch's width at mid height: the ripple stays inside the shape
        x: edgeButton.shape.cx - edgeButton.shape.a
        width: 2 * edgeButton.shape.a
        height: parent.height
        Ripple {
            radius: edgeButton.shape.k
            color: edgeButton.contentColor
            pressed: edgeButton.pressed
            pressX: edgeButton.mouseX - parent.x
            pressY: edgeButton.mouseY
        }
    }

    Column {
        id: _content
        anchors.centerIn: parent
        width: Math.max(0, 2 * edgeButton.shape.contentHalfWidth)
        opacity: 1 - edgeButton.shape.fade
        visible: opacity > 0
        Icon {
            visible: edgeButton.iconName !== ""
            anchors.horizontalCenter: parent.horizontalCenter
            name: edgeButton.iconName
            width: visible ? Theme.size.icon : 0
            height: width
            color: edgeButton.contentColor
        }
        Label {
            id: _label
            width: parent.width
            visible: text !== ""
            text: edgeButton.text
            role: "labelMedium"
            color: edgeButton.contentColor
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            maximumLineCount: edgeButton.preferredHeight >= Theme.size.edgeButtonSmall ? 2 : 1
        }
    }
}
