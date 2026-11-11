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
    \qmltype DialogGlyph
    \inqmlmodule org.asteroid.controls

    \brief The stroked glyphs of the dialogs: \c check, \c close,
    \c failure and \c phone, drawn on a 24 x 24 grid scaled to the item.

    Each stroke can be drawn from its start to its end: \l progress for the
    first stroke, \l progress2 for the second (the failure glyph's second
    stroke, the phone's speaker). Our own drawings after the Material Symbols
    check and close (Apache 2.0); the failure and phone glyphs are original
    (the stock ones are firmware animations, out of reach).
*/
Item {
    id: dg

    /*! "check", "close", "failure" or "phone". */
    property string glyph: "check"
    property color color: Theme.color.onPrimary
    /*! Stroke width in grid units (24 per side); 2 is Material's weight. */
    property real strokeUnits: 2
    /*! Round stroke ends. */
    property bool roundCap: true
    /*! How much of the first stroke is drawn, 0..1. */
    property real progress: 1
    /*! How much of the second stroke is drawn, 0..1. */
    property real progress2: 1

    readonly property real unit: width / 24
    readonly property real strokeWidth: strokeUnits * unit

    function _rounded(x0, y0, x1, y1, r) {
        // a rounded rectangle as a closed polyline, clockwise from the top middle
        var pts = [Qt.point((x0 + x1) / 2, y0)]
        var corners = [[x1 - r, y0 + r, -90], [x1 - r, y1 - r, 0], [x0 + r, y1 - r, 90], [x0 + r, y0 + r, 180]]
        for (var c = 0; c < 4; c++)
            for (var k = 0; k <= 6; k++) {
                var a = (corners[c][2] + 15 * k) * Math.PI / 180
                pts.push(Qt.point(corners[c][0] + r * Math.cos(a), corners[c][1] + r * Math.sin(a)))
            }
        pts.push(Qt.point((x0 + x1) / 2, y0))
        return pts
    }

    /*! The strokes on the 24 grid: a list of point lists. */
    readonly property var strokes: {
        switch (glyph) {
        case "check":
            // the centre line of Material Symbols "check"
            return [[Qt.point(4.1, 12.7), Qt.point(9, 17.6), Qt.point(20.3, 6.3)]]
        case "close":
            return [[Qt.point(5.7, 5.7), Qt.point(18.3, 18.3)],
                    [Qt.point(18.3, 5.7), Qt.point(5.7, 18.3)]]
        case "failure":
            return [[Qt.point(6.5, 6.5), Qt.point(17.5, 17.5)],
                    [Qt.point(17.5, 6.5), Qt.point(6.5, 17.5)]]
        case "phone":
            return [_rounded(6.5, 2, 17.5, 22, 2.5),
                    [Qt.point(10.5, 18.5), Qt.point(13.5, 18.5)]]
        }
        return []
    }

    function _length(pts) {
        var l = 0
        for (var i = 1; i < pts.length; i++)
            l += Math.sqrt(Math.pow(pts[i].x - pts[i - 1].x, 2) + Math.pow(pts[i].y - pts[i - 1].y, 2))
        return l
    }

    Repeater {
        model: dg.strokes.length
        delegate: Shape {
            id: stroke
            anchors.fill: parent
            readonly property var pts: dg.strokes[index] || []
            readonly property real p: index === 0 ? dg.progress : dg.progress2
            // length in stroke widths, for the dash that draws it
            readonly property real len: dg.strokeUnits > 0 ? dg._length(pts) / dg.strokeUnits : 0
            visible: p > 0
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: dg.color
                strokeWidth: dg.strokeWidth
                fillColor: "transparent"
                capStyle: dg.roundCap ? ShapePath.RoundCap : ShapePath.FlatCap
                joinStyle: dg.roundCap ? ShapePath.RoundJoin : ShapePath.MiterJoin
                // drawn from its start: one dash as long as the drawn part
                strokeStyle: stroke.p >= 1 ? ShapePath.SolidLine : ShapePath.DashLine
                dashPattern: [Math.max(0.001, stroke.p * stroke.len), stroke.len + 4]
                PathPolyline {
                    path: {
                        var out = []
                        for (var i = 0; i < stroke.pts.length; i++)
                            out.push(Qt.point(stroke.pts[i].x * dg.unit, stroke.pts[i].y * dg.unit))
                        return out
                    }
                }
            }
        }
    }
}
