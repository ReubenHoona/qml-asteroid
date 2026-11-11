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
    \qmltype AlertDialog
    \inqmlmodule org.asteroid.controls

    \brief The Wear OS Material 3 alert dialog (E02, E03, E05, E06) on
    \l Dialog: an optional icon, a title, a text, optional rows, then either
    the dismiss and confirm icon buttons, one edge button, or nothing.

    Stock CP3A (AlertDialogDefaults.java:37-66,81-122,166-235,271-323,
    AlertDialogKt.java:292,301,684-750,813-891; px on the 384 px Pixel
    Watch 2, 2 px per dp):
    \list
    \li padding: top ceil(10 % of the height) = 39 px (with an icon
        ceil(1.2 %) = 5 px), sides ceil(5.2 % of the width) = 20 px, bottom
        39 px with the two buttons, 36.46 % of the height = 140 px with no
        button; items 4 dp (8 px) apart, centred when they fit;
    \li icon 32 dp (64 px) centred, 4 dp under it (with the 4 dp item gap);
    \li title titleMedium (32 px, weight 550; Settings uses titleLarge 36 px
        through \l titleRole) centred, at most 3 lines, ellipsis, 12 % of the
        width (46 px) at each side;
    \li text bodyMedium (28 px, weight 450), onBackground, centred, 4.16 %
        of the width (16 px) at each side, 4 dp (8 px) more above it;
    \li confirm/dismiss row, 12 dp (24 px) above it: 6 dp, the dismiss
        FilledTonalIconButton 60 dp (120 px) square with 18 dp (36 px)
        corners in a 61 dp box, aligned to its bottom end, surfaceContainer
        with a 28 dp close in primary; 3 % of the width; the confirm
        FilledIconButton 63 x 54 dp (126 x 108 px) full-round pill turned
        -45 degrees, primary with a 28 dp check in onPrimary turned back
        upright; 2 dp; then 4.5 % of the height below the row;
    \li one button (\c{buttons: "edge"}): an EdgeButton 70 dp (140 px) high
        at the bottom edge, primary with a 28 dp check in onPrimary, 4 dp
        above it, 16 dp when there is only a title;
    \li long content scrolls as a scaling list: rows shrink and fade at the
        top and bottom edges (EdgeEffect), the crown scrolls it and the
        position indicator shows (both from the crown support of
        org.asteroid.controls); it stays a fixed centred layout while
        everything fits.
    \endlist

    The buttons are named "Confirm" and "Dismiss" for the screen reader
    (wear_m3c_alert_dialog_content_description_confirm_button / _dismiss_).
    Alert dialogs never hold the screen on.

    \qml
    AlertDialog {
        id: alert
        title: qsTr("Turn on Bedtime mode?")
        text: qsTr("Notifications and the screen stay off")
        onConfirmed: bedtime.enable()
    }
    ...
    alert.open()
    \endqml
*/
Dialog {
    id: alert

    property string title: ""
    property string text: ""
    /*! The title's type role: titleMedium (the library), titleLarge (Settings). */
    property string titleRole: "titleMedium"
    /*! An Icon name for the icon slot above the title (32 dp). */
    property string iconName: ""
    /*! A component for the icon slot, instead of \l iconName. */
    property Component icon: null
    /*! "confirmDismiss" (two icon buttons), "edge" (one edge button) or "none". */
    property string buttons: "confirmDismiss"
    /*! A label for the edge button; empty shows the check. */
    property string edgeText: ""
    /*! Close the dialog when a button is pressed or it is swiped away. */
    property bool closeOnAction: true
    /*! Rows between the text and the buttons (e.g. a CheckboxButton). */
    default property alias rows: _rows.data
    readonly property alias flickable: _list

    signal confirmed()
    signal dismissed()

    closeOnSwipe: closeOnAction
    onDismissRequested: dismissed()

    function _confirm() {
        confirmed()
        if (closeOnAction)
            close()
    }
    function _dismiss() {
        dismissed()
        if (closeOnAction)
            close()
    }

    readonly property bool hasIcon: iconName !== "" || icon !== null
    readonly property real _h: height > 0 ? height : 384
    readonly property real _w: width > 0 ? width : 384

    /* ---- stock layout in px (Compose ceilDp rounds the px up) ---- */
    readonly property real topPadding: hasIcon ? Math.ceil(0.012 * _h) : Math.ceil(0.10 * _h)
    readonly property real sidePadding: Math.ceil(0.052 * _w)
    readonly property real bottomPadding: buttons === "confirmDismiss" ? Math.ceil(0.10 * _h)
                                         : buttons === "edge" ? _edge.preferredHeight + Theme.size.edgeButtonBottomGap + edgeGap
                                         : 0.3646 * _h
    /*! Gap above the edge button: 4 dp, 16 dp with no text and no rows. */
    readonly property real edgeGap: (text === "" && _rows.children.length === 0) ? Theme.dp(16) : Theme.dp(4)
    readonly property real itemSpacing: Theme.dp(4)
    readonly property real iconSize: Theme.dp(32)
    readonly property real titleSidePadding: 0.12 * _w
    readonly property real textSidePadding: 0.0416 * _w
    readonly property real textTopSpacing: Theme.dp(4)
    readonly property real buttonsTopSpacing: Theme.dp(12)
    readonly property real buttonsBottomSpacing: 0.045 * _h
    readonly property real dismissSize: Theme.dp(60)
    readonly property real dismissBox: Theme.dp(61)
    readonly property real dismissRadius: Theme.dp(18)
    readonly property real confirmWidth: Theme.dp(63)
    readonly property real confirmHeight: Theme.dp(54)
    readonly property real buttonIconSize: Theme.dp(28)
    readonly property real buttonGap: 0.03 * _w

    /*! The content at its own size (rows unscaled), px. */
    readonly property real naturalHeight: {
        var rows = [_iconRow, _titleRow, _textRow, _rowsRow, _buttonsRow]
        var h = 0, n = 0
        for (var i = 0; i < rows.length; i++)
            if (rows[i].innerHeight > 0) {
                h += rows[i].innerHeight
                n++
            }
        return h + Math.max(0, n - 1) * itemSpacing
    }
    /*! The content does not fit: it scrolls as a scaling list. */
    readonly property bool scrolling: naturalHeight + topPadding + bottomPadding > _h + 0.5

    // stock starts the list at item 0
    function _toStart() {
        _list.contentY = -_list.topMargin
    }
    onOpened: _toStart()

    /*! The buttons, for tests and wrappers. */
    readonly property alias confirmButton: _confirmBtn
    readonly property alias dismissButton: _dismissBtn
    readonly property alias edgeButton: _edge
    readonly property alias titleLabel: _title
    readonly property alias textLabel: _text

    // one list item: scaled and faded at the edges while the content scrolls
    component EdgeRow: Item {
        id: row
        default property alias inner: _inner.data
        property real innerHeight: _inner.childrenRect.height
        width: _col.width
        height: alert.scrolling ? _fx.transformedHeight : innerHeight
        visible: innerHeight > 0
        EdgeEffect {
            id: _fx
            item: _inner
            enabled: alert.scrolling
        }
        Item {
            id: _inner
            width: row.width
            height: row.innerHeight
            opacity: alert.scrolling ? _fx.alpha : 1
            transform: Scale {
                origin.x: _inner.width / 2
                origin.y: 0
                xScale: alert.scrolling ? _fx.scale : 1
                yScale: alert.scrolling ? _fx.scale : 1
            }
        }
    }

    Flickable {
        id: _list
        anchors.fill: parent
        contentWidth: width
        contentHeight: _col.height
        topMargin: alert.topPadding + (alert.scrolling ? 0 : Math.max(0, (alert._h - alert.topPadding - alert.bottomPadding - alert.naturalHeight) / 2))
        onTopMarginChanged: if (!alert.scrolling || !alert.shown) alert._toStart()
        bottomMargin: alert.bottomPadding
        interactive: alert.scrolling
        boundsBehavior: Flickable.StopAtBounds
        clip: false

        Column {
            id: _col
            x: alert.sidePadding
            width: alert._w - 2 * alert.sidePadding
            spacing: alert.itemSpacing

            EdgeRow {
                id: _iconRow
                innerHeight: alert.hasIcon ? alert.iconSize + alert.itemSpacing : 0
                Loader {
                    active: alert.hasIcon
                    width: alert.iconSize
                    height: alert.iconSize
                    anchors.horizontalCenter: parent.horizontalCenter
                    sourceComponent: alert.icon !== null ? alert.icon : _iconComponent
                }
            }
            EdgeRow {
                id: _titleRow
                innerHeight: alert.title !== "" ? _title.height : 0
                Label {
                    id: _title
                    x: alert.titleSidePadding - alert.sidePadding
                    width: parent.width - 2 * x
                    text: alert.title
                    role: alert.titleRole
                    color: Theme.color.onBackground
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                }
            }
            EdgeRow {
                id: _textRow
                innerHeight: alert.text !== "" ? _text.height + alert.textTopSpacing : 0
                Label {
                    id: _text
                    y: alert.textTopSpacing
                    x: alert.textSidePadding
                    width: parent.width - 2 * x
                    text: alert.text
                    role: "bodyMedium"
                    color: Theme.color.onBackground
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                }
            }
            EdgeRow {
                id: _rowsRow
                innerHeight: _rows.children.length > 0 ? _rows.height : 0
                Column {
                    id: _rows
                    width: parent.width
                    spacing: alert.itemSpacing
                }
            }
            EdgeRow {
                id: _buttonsRow
                innerHeight: alert.buttons === "confirmDismiss"
                             ? alert.buttonsTopSpacing + _buttonRow.height + alert.buttonsBottomSpacing : 0
                Row {
                    id: _buttonRow
                    y: alert.buttonsTopSpacing
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: alert.buttons === "confirmDismiss"
                    Item { width: Theme.dp(6); height: 1 }
                    Item {
                        width: alert.dismissBox
                        height: alert.dismissBox
                        MouseArea {
                            id: _dismissBtn
                            width: alert.dismissSize
                            height: alert.dismissSize
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            Accessible.role: Accessible.Button
                            Accessible.name: qsTr("Dismiss")
                            Accessible.onPressAction: alert._dismiss()
                            onClicked: alert._dismiss()
                            Rectangle {
                                id: _dismissShape
                                anchors.fill: parent
                                color: Theme.color.surfaceContainer
                                radius: alert.dismissRadius + (Theme.shape.small - alert.dismissRadius) * _dismissMorph.value
                                WearSpring {
                                    id: _dismissMorph
                                    to: _dismissBtn.pressed ? 1 : 0
                                    stiffness: _dismissBtn.pressed ? Motion.pressMorph.press.stiffness : Motion.pressMorph.release.stiffness
                                    dampingRatio: 1.0
                                }
                                Ripple {
                                    radius: _dismissShape.radius
                                    color: Theme.color.primary
                                    pressed: _dismissBtn.pressed
                                    pressX: _dismissBtn.mouseX
                                    pressY: _dismissBtn.mouseY
                                }
                            }
                            DialogGlyph {
                                anchors.centerIn: parent
                                width: alert.buttonIconSize
                                height: width
                                glyph: "close"
                                color: Theme.color.primary
                            }
                        }
                    }
                    Item { width: alert.buttonGap; height: 1 }
                    MouseArea {
                        id: _confirmBtn
                        width: alert.confirmWidth
                        height: alert.confirmHeight
                        Accessible.role: Accessible.Button
                        Accessible.name: qsTr("Confirm")
                        Accessible.onPressAction: alert._confirm()
                        onClicked: alert._confirm()
                        Rectangle {
                            id: _confirmShape
                            anchors.fill: parent
                            rotation: -45
                            color: Theme.color.primary
                            radius: height / 2 + (Theme.shape.small - height / 2) * _confirmMorph.value
                            WearSpring {
                                id: _confirmMorph
                                to: _confirmBtn.pressed ? 1 : 0
                                stiffness: _confirmBtn.pressed ? Motion.pressMorph.press.stiffness : Motion.pressMorph.release.stiffness
                                dampingRatio: 1.0
                            }
                            Ripple {
                                radius: _confirmShape.radius
                                color: Theme.color.onPrimary
                                pressed: _confirmBtn.pressed
                                pressX: _confirmBtn.mouseX
                                pressY: _confirmBtn.mouseY
                            }
                        }
                        // turned back upright, inside 10 dp of padding
                        DialogGlyph {
                            anchors.centerIn: parent
                            width: alert.buttonIconSize
                            height: width
                            glyph: "check"
                            color: Theme.color.onPrimary
                        }
                    }
                    Item { width: Theme.dp(2); height: 1 }
                }
            }
        }
    }

    EdgeButton {
        id: _edge
        visible: alert.buttons === "edge" && shownHeight > 0.5
        preferredHeight: Theme.size.edgeButtonMedium
        flickable: alert.scrolling ? _list : null
        text: alert.edgeText
        Accessible.name: alert.edgeText !== "" ? alert.edgeText : qsTr("Confirm")
        onClicked: alert._confirm()
        DialogGlyph {
            visible: alert.edgeText === ""
            anchors.centerIn: parent
            width: alert.buttonIconSize
            height: width
            glyph: "check"
            color: Theme.color.onPrimary
        }
    }

    Component {
        id: _iconComponent
        Icon {
            name: alert.iconName
            color: Theme.color.onBackground
        }
    }
}
