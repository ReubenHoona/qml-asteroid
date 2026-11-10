/*
 * Copyright (C) 2026 Reuben Horner <reubarb.scons@gmail.com>
 * SPDX-License-Identifier: BSD-3-Clause
 */

import QtQuick
import org.asteroid.controls

/*!
    \qmltype ScalingList
    \inqmlmodule org.asteroid.controls

    \brief A vertical list that moves as Wear OS lists do (CP3A
    TransformingLazyColumn / ScalingLazyColumn).

    \list
    \li Rows shrink to 0.7 and fade to 0.5 towards the top and bottom of the
        round screen, measured from their edge nearest the centre, scaled
        about their top and laid out at their transformed height so they
        stay packed (\l EdgeEffect).
    \li Touch flings follow Android's spline decay, at most 2750 dp/s, and
        the ends stretch instead of sliding (\l ScrollPhysics).
    \li Stock list paddings: 16.64 % of the height at the top, 36.46 % at the
        bottom, 4 dp between rows; rows keep 5.2 % of the width from the
        sides (\c sideMargin).
    \endlist

    Give it the row as \l itemDelegate. The row is created where it is
    written, so it gets the delegate's \c index, \c modelData and \c model
    through properties of those names that it declares:

    \qml
    ScalingList {
        anchors.fill: parent
        model: 20
        itemDelegate: ListItem { property int index; title: "Row " + index }
    }
    \endqml

    A list that sets \c delegate itself keeps the physics and paddings; its
    rows can use their own \l EdgeEffect with this list's edge values.
    Accessibility > Reduce animations stops the edge scaling and fading.
*/
ListView {
    id: list

    /*! The row, wrapped in the stock edge transformation */
    property Component itemDelegate: null
    /*! Lay rows out at their transformed height (stock); false keeps their own height */
    property bool packed: true
    /*! Edge values (stock 192 dp spec; the notification stream uses 0.6 and [0, 0, 0.6, 1]) */
    property real edgeScale: Motion.list.edgeScale
    property real edgeAlpha: Motion.list.edgeAlpha
    property real edgeContentAlpha: Motion.list.edgeContentAlpha
    property var edgeEasing: Motion.list.edgeEasing
    /*! Space a row keeps from the sides: 5.2 % of the width (CustomDimensions.java:22) */
    property real sideMargin: Theme.margin.listSide
    /*! The fling and stretch, see \l ScrollPhysics */
    readonly property alias physics: scrollPhysics

    spacing: Theme.space.xs
    topMargin: Theme.margin.listTop
    bottomMargin: Theme.margin.listBottom
    boundsBehavior: Flickable.DragOverBounds
    boundsMovement: Flickable.StopAtBounds

    ScrollPhysics {
        id: scrollPhysics
        flickable: list
    }

    // the stretch: about the pulled edge, one transform, no layer
    transform: Scale {
        origin.y: scrollPhysics.stretchOrigin
        yScale: scrollPhysics.stretchScale
    }

    Component {
        id: wrapper
        Item {
            id: row
            required property int index
            required property var modelData
            required property var model
            width: list.width
            height: list.packed ? edge.transformedHeight : content.height

            EdgeEffect {
                id: edge
                item: content
                edgeScale: list.edgeScale
                edgeAlpha: list.edgeAlpha
                edgeContentAlpha: list.edgeContentAlpha
                easing: list.edgeEasing
            }

            Loader {
                id: content
                x: list.sideMargin
                width: row.width - 2 * list.sideMargin
                sourceComponent: list.itemDelegate
                opacity: edge.alpha
                onLoaded: {
                    if ("index" in item)
                        item.index = Qt.binding(function() { return row.index })
                    if ("modelData" in item)
                        item.modelData = Qt.binding(function() { return row.modelData })
                    if ("model" in item)
                        item.model = Qt.binding(function() { return row.model })
                }
                transform: Scale {
                    origin.x: content.width / 2
                    origin.y: 0
                    xScale: edge.scale
                    yScale: edge.scale
                }
            }
        }
    }

    delegate: itemDelegate ? wrapper : null
}
