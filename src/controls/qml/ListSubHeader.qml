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
    \qmltype ListSubHeader
    \inqmlmodule org.asteroid.controls

    \brief A category header inside a list (E16).

    As the Wear OS 6 emulator draws them ('Ring volume', 'Notification
    volume', S21 / S21-d): labelSmall (13 sp, Medium) in onSurface,
    start-aligned with the ink of a stem letter (H, N, R) 16 dp inside the
    list's 5.2 % side padding (x 52 on 384 px; S21-d 'Notification
    volume' from x 51). The header is usually as wide as the rows (a
    Column or a ScalingList row 5.2 % in from each side), so
    \l textInset, from its own left edge, is 16 dp; a header as wide as
    the screen (next to ListItem or ListRow, which keep the 5.2 %
    inside) sets \c{textInset: Theme.margin.listSide + Theme.dp(16)}.
    No least height; the first cap row 38 pixel rows
    under the last row of the row above and the next row 22 rows under
    the last cap row (S21-d: row 120-223, 'N' 261-277; 'R' 82-98, the
    stepper from 120). \l first: no space above (the cap top at the top
    of the box). In a scrolling list of packed rows it shrinks and fades
    at the edges and packs with them; among plain rows it stays as it is
    (\l edgeEffect).

    Those two spaces include the list's own space between its items,
    \l rowGap: 4 dp in a list with the stock spacing (ScalingList, a
    Column with \c{spacing: Theme.space.xs}); set it to 2 dp next to
    ListItem or ListRow in a Column without spacing (each keeps 2 dp of
    its own above and below its row), or 0 where nothing else makes room.
*/
Item {
    id: header

    /*! The header text. */
    property alias text: label.text
    /*! The first item of the page: no space above. */
    property bool first: false
    /*! Where the ink of a stem letter starts, from the header's left edge:
        16 dp (x 52 in a list 5.2 % in from the screen's edge). */
    property real textInset: Theme.dp(16)
    /*! The label's inset each side: textInset less the font's left bearing. */
    property real horizontalPadding: textInset - capMetrics.tightBoundingRect.x
    /*! The space the list already leaves around this header (see above). */
    property real rowGap: Theme.space.xs
    /*! From the top of the box to the cap top: 37 px from the row above
        (its last pixel row and the first cap row 38 apart). */
    readonly property real topPadding: first ? 0 : Theme.dp(18.5) - rowGap
    /*! From the last baseline to the bottom of the box: 21 px to the next
        row (the last cap row and its first row 22 apart). */
    readonly property real bottomPadding: Theme.dp(10.5) - rowGap
    /*! The cap height of the font (an H's ink). */
    readonly property real capHeight: capMetrics.tightBoundingRect.height
    readonly property alias label: label
    /*!
        Shrink and fade near the top and bottom of a round screen while the
        list scrolls, packed with its rows, when the list has packed rows
        (see \l EdgeEffect, packed, onlyWithRows).
    */
    property alias edgeEffect: edge.enabled

    width: parent ? parent.width : Theme.dp(192)
    // the box ends bottomPadding under the last baseline
    readonly property real _linePitch: label.lineHeightMode === Text.FixedHeight ? label.lineHeight
                                       : label.contentHeight / Math.max(1, label.lineCount)
    implicitHeight: Math.max(0, label.y + label.baselineOffset
                                + Math.max(0, label.lineCount - 1) * _linePitch + bottomPadding)
    height: implicitHeight

    Accessible.role: Accessible.Heading
    Accessible.name: text

    EdgeEffect { id: edge; item: header; packed: true; onlyWithRows: true }
    transform: [
        Scale {
            origin.x: header.width / 2
            origin.y: edge.originY
            xScale: edge.scale
            yScale: edge.scale
        },
        Translate { y: edge.translateY }
    ]

    TextMetrics {
        id: capMetrics
        font: label.font
        text: "H"
    }

    Label {
        id: label
        opacity: edge.alpha
        x: header.horizontalPadding
        width: Math.max(0, header.width - 2 * header.horizontalPadding)
        // the cap top topPadding under the top of the box
        y: header.topPadding - (baselineOffset - header.capHeight)
        role: "labelSmall"
        color: Theme.color.onSurface
        horizontalAlignment: Text.AlignLeft
        wrapMode: Text.Wrap
        maximumLineCount: 2
    }
}
