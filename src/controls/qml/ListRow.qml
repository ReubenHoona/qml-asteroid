/*
 * Copyright (C) 2026 Timo Könnecke <github.com/moWerk>
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
import org.asteroid.controls
import org.asteroid.utils

/*!
    \qmltype ListRow
    \inqmlmodule org.asteroid.controls

    \brief A list row with a label on the left and an action widget on the right.

    The row is drawn as a Wear OS Material 3 button row (E19): a
    surfaceContainer container with CornerLarge (26 dp) corners, at least
    52 dp (104 px) tall, the label in labelMedium (15 sp, onSurface) 14 dp
    from the start, an optional second line in labelSmall (onSurfaceVariant),
    the action in a 32 x 24 dp slot 6 dp after the label and 14 dp from the
    end, and a bounded ripple on press. Rows are 4 dp apart in a list: each
    row keeps 2 dp above and below its container (the implicit height is the
    stock row pitch, 104 + 8 px). With \l checkedStyle (a switch that is on)
    the row takes the checked colours: primaryContainer, onPrimaryContainer.

    ListRow serves as the foundation for \l LabeledSwitch, \l LabeledActionButton,
    \l IntSelector and \l OptionCycler. Subclasses provide an \l actionComponent;
    the left side can be either a plain text label via \l text, or custom content
    declared as child items.

    Simple text label example:
    \qml
    ListRow {
        text: "Show Seconds"
        actionComponent: Item {
            Switch { anchors.centerIn: parent }
        }
    }
    \endqml
*/
Item {
    id: listRow

    /*!
        \qmlproperty Component ListRow::actionComponent
        The component to instantiate in the right-side action area.
        The Loader is \l iconSize + 2 * \l actionSlotPadding wide and \l iconSize tall,
        providing \l actionSlotPadding on each side around centered content. The Loader
        resizes its instantiated root item to fill itself, so action components must wrap
        their widget in an Item and size it explicitly using \l iconSize.
    */
    property Component actionComponent: null
    /*!
        \qmlproperty Item ListRow::actionArea
        Read-only reference to the Loader occupying the right action slot.
        Left-side content anchors its right edge to \c actionArea.left automatically
        via the internal \c labelContainer.
    */
    readonly property alias actionArea: actionLoader
    /*!
        \qmlproperty bool ListRow::highlightBarEnabled
        Set to false to disable the press ripple and the row tap, allowing child
        items to receive taps directly. Defaults to true. Set to false for components
        such as \l IntSelector that manage multiple independent tap targets.
    */
    property bool highlightBarEnabled: true
    /*!
     \qmlproperty string ListRow::text
     The descriptive label text displayed on the left side of the row.
     Leave unset and add child items via the default property for custom left-side content.
    */
    property alias text: labelContainer.text
    /*! The second line under the label (labelSmall, onSurfaceVariant); empty for none. */
    property string secondaryText: ""
    /*! Padding on each side of the action widget within the action slot */
    property int actionSlotPadding: 0
    /*! Side margin from the row's edges to its container: the list's 5.2 % side padding */
    property int rowMargin: Theme.margin.listSide
    /*! Size of the right-side action slot: 32 dp (the stock control slot) */
    property int iconSize: Theme.dp(32)
    /*! Base font size for label text: labelMedium, 15 sp */
    property int labelFontSize: Theme.type.labelMedium.pixelSize
    /*! Draw the container (false: a transparent information row, E03). */
    property bool containerVisible: true
    /*! The checked colours (a switch row that is on). */
    property bool checkedStyle: false
    /*!
        Shrink and fade the row near the top and bottom of a round screen
        while it scrolls in a list, as Wear OS lists do (see \l EdgeEffect).
    */
    property alias edgeEffect: edge.enabled
    /*! The container (for subclasses and tests). */
    readonly property alias container: _container
    /*! The ripple (for tests). */
    readonly property alias ripple: _ripple
    /*! Container colour */
    readonly property color containerColor: !enabled ? Qt.rgba(Theme.color.onSurface.r, Theme.color.onSurface.g, Theme.color.onSurface.b, Theme.alpha.disabledContainer)
        : !containerVisible ? "transparent"
        : checkedStyle ? Theme.color.primaryContainer : Theme.color.surfaceContainer
    /*! Label colour */
    readonly property color contentColor: !enabled ? Qt.rgba(Theme.color.onSurface.r, Theme.color.onSurface.g, Theme.color.onSurface.b, Theme.alpha.disabledContent)
        : checkedStyle ? Theme.color.onPrimaryContainer : Theme.color.onSurface
    readonly property color secondaryContentColor: !enabled ? contentColor
        : checkedStyle ? Qt.rgba(Theme.color.onPrimaryContainer.r, Theme.color.onPrimaryContainer.g, Theme.color.onPrimaryContainer.b, Theme.alpha.secondaryOnChecked)
        : Theme.color.onSurfaceVariant

    /*! Default width is parent width */
    width: parent ? parent.width : implicitWidth
    /*! Default height is parent height */
    height: parent ? parent.height : implicitHeight
    implicitWidth: Theme.dp(192)
    implicitHeight: Math.max(Theme.size.button, labelContainer.implicitHeight + (secondary.visible ? secondary.implicitHeight : 0)
                                                 + 2 * Theme.space.s) + Theme.space.xs

    /*! Left content area — filled by child declarations */
    default property alias content: labelContainer.data

    signal clicked()

    EdgeEffect { id: edge }
    transform: Scale {
        origin.x: listRow.width / 2
        origin.y: listRow.height / 2
        xScale: edge.scale
        yScale: edge.scale
    }

    Behavior on opacity {
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutQuad
        }
    }

    Rectangle {
        id: _container
        opacity: edge.alpha
        anchors {
            fill: parent
            leftMargin: listRow.rowMargin
            rightMargin: listRow.rowMargin
            topMargin: Theme.space.xs / 2
            bottomMargin: Theme.space.xs / 2
        }
        radius: Math.min(Theme.shape.large, height / 2)
        color: listRow.containerColor
        Behavior on color {
            ColorAnimation {
                duration: Motion.springDuration(Motion.standard.slowEffects.stiffness)
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.springEasing
            }
        }
        Ripple {
            id: _ripple
            radius: _container.radius
            color: listRow.contentColor
            pressed: listRow.highlightBarEnabled && rowArea.pressed
            pressX: rowArea.mouseX - _container.x
            pressY: rowArea.mouseY - _container.y
        }
    }

    Column {
        id: labelColumn
        opacity: edge.alpha
        anchors {
            left: _container.left
            leftMargin: Theme.space.xl
            right: actionLoader.left
            rightMargin: actionComponent ? Theme.space.s : Theme.space.xl
            verticalCenter: _container.verticalCenter
        }
        Label {
            id: labelContainer
            width: parent.width
            height: secondary.visible ? implicitHeight : Math.max(implicitHeight, _container.height - 2 * Theme.space.s)
            role: "labelMedium"
            font.pixelSize: listRow.labelFontSize
            color: listRow.contentColor
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignLeft
            wrapMode: Text.Wrap
            maximumLineCount: listRow.secondaryText === "" && !listRow.actionComponent ? 5 : 3
        }
        Label {
            id: secondary
            width: parent.width
            visible: text !== ""
            text: listRow.secondaryText
            role: "labelSmall"
            color: listRow.secondaryContentColor
            wrapMode: Text.Wrap
            maximumLineCount: 2
        }
    }

    Loader {
        id: actionLoader
        opacity: edge.alpha
        anchors {
            right: _container.right
            rightMargin: actionComponent ? Theme.space.xl - actionSlotPadding : 0
            verticalCenter: _container.verticalCenter
        }
        width: actionComponent ? iconSize + 2 * actionSlotPadding : 0
        height: actionComponent ? Math.max(iconSize, Theme.dp(24)) : 0
        sourceComponent: actionComponent
    }

    MouseArea {
        id: rowArea
        anchors.fill: parent
        enabled: highlightBarEnabled
        onClicked: listRow.clicked()
    }
}
