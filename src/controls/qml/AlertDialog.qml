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

    \brief The Wear OS alert dialog (E02, E03, E05, E06) on \l Dialog: an
    optional icon, a title, a text, optional rows, then either the dismiss
    and confirm round buttons, one edge button, one round check (the info
    popup) or nothing.

    \c{buttons: "confirmDismiss"} (the default) is the stock Wear OS 6
    confirmation (emulator S25, System > Restart: the View-based
    WearAlertDialog of wear_alertdialog_action_button_layout.xml and its
    wear_alertdialog_* dimens; px on the 384 px Pixel Watch 2, 2 px per
    dp):
    \list
    \li black, no card; padding: top 12.48 % of the height (47 px; 10.4 %,
        39 px, with an icon), bottom 6.24 % (23 px);
    \li title in \l titleRole (titleMedium 32 px by default), onSurface,
        centred between the 5.21 % / 94.79 % guidelines with 16 dp (32 px)
        at each side (x 52 to 332), 8 dp (16 px) above it; its first
        baseline 15 sp (30 px) below its top, the last 5 sp (10 px) above
        its bottom;
    \li text bodyMedium (28 px), onSurface, centred, 4.16 % of the width
        inside the side padding (x 36 to 348), 12 dp (24 px) above it and
        16 dp (32 px) below it; its first baseline 12 sp (24 px) below its
        top, the last 4 sp (8 px) above its bottom;
    \li two 52 dp (104 px) circles 12 dp (24 px) apart, centred, at the
        bottom (y 257 to 361): dismiss in surfaceContainer with a 24 dp
        close in onSurface (x 76 to 180), confirm in primary with a 24 dp
        check in onPrimary (x 204 to 308); a ripple when pressed;
    \li the icon, title, text and rows are centred in the space above the
        buttons: one-line texts put their cap tops at y 103 and 164;
        content that does not fit scrolls, the buttons right under it and
        a 20.83 % (79 px) bottom padding.
    \endlist

    \c{buttons: "edge"} and \c{"none"} keep the CP3A Material 3 layout
    (AlertDialogDefaults.java:37-66,81-122,166-235,271-323,
    AlertDialogKt.java:292,301,684-750,813-891):
    \list
    \li padding: top ceil(10 % of the height) = 39 px (with an icon
        ceil(1.2 %) = 5 px), sides ceil(5.2 % of the width) = 20 px, bottom
        36.46 % of the height = 140 px with no button; items 4 dp (8 px)
        apart, centred when they fit;
    \li icon 32 dp (64 px) centred, 4 dp under it (with the 4 dp item gap);
    \li title in \l titleRole (titleMedium 32 px by default) centred, at
        most 3 lines, ellipsis, 12 % of the width (46 px) at each side;
    \li text bodyMedium (28 px, weight 450), onBackground, centred, 4.16 %
        of the width (16 px) at each side, 4 dp (8 px) more above it;
    \li one button (\c{buttons: "edge"}): an EdgeButton 70 dp (140 px) high
        at the bottom edge, primary with a 28 dp check in onPrimary, 4 dp
        above it, 16 dp when there is only a title;
    \li long content scrolls as a scaling list: rows shrink and fade at the
        top and bottom edges (EdgeEffect), the crown scrolls it and the
        position indicator shows (both from the crown support of
        org.asteroid.controls); it stays a fixed centred layout while
        everything fits.
    \endlist

    \c{buttons: "info"} is the stock info popup instead (Settings
    DialogUtils.showPopup, DialogUtils.java:22-37: a View-based
    WearAlertDialog with one string and only the positive button; its
    simple layout wear_alertdialog_action_button_layout.xml and
    WearAlertDialogViewController.java:108-152):
    \list
    \li no title: the one message (\l text, or \l title when \c text is
        empty) in Title3 = titleMedium 16 sp (32 px) on an 18 sp (36 px)
        line, first baseline 14 sp (28 px) below its top and the last 4 sp
        (8 px) above its bottom, 0.025 em tracking, onSurface, centred
        between the 5.21 % / 94.79 % guidelines with 16 dp (32 px) padding
        at each side (x 52 to 332), 8 dp (16 px) above it;
    \li one round button: 52 dp (104 px) circle in primary with a 26 dp
        (52 px) check in onPrimary, centred, "OK" for the screen reader (the
        confirm button of the two-button style, alone);
    \li padding: top 12.48 % of the height (47 px), bottom 6.24 % (23 px):
        the button sits at the bottom (y 257 to 361) and the message is
        centred between the top padding and the button; content that does
        not fit scrolls with the button right under the message and a
        20.83 % (79 px) bottom padding.
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
    /*! The title's type role: titleMedium (stock, the default). */
    property string titleRole: "titleMedium"
    /*! An Icon name for the icon slot above the title (32 dp). */
    property string iconName: ""
    /*! A component for the icon slot, instead of \l iconName. */
    property Component icon: null
    /*! "confirmDismiss" (the stock confirmation: two round buttons), "edge" (one edge button), "info" (the stock info popup: the message alone and one round check) or "none". */
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

    // a tap while the dialog leaves (its 150 ms exit, fully transparent at the end) is
    // not an answer: after X, a quick tap where the check was must not confirm
    function _confirm() {
        if (!shown)
            return
        confirmed()
        if (closeOnAction)
            close()
    }
    function _dismiss() {
        if (!shown)
            return
        dismissed()
        if (closeOnAction)
            close()
    }

    readonly property bool hasIcon: iconName !== "" || icon !== null
    readonly property real _h: height > 0 ? height : 384
    readonly property real _w: width > 0 ? width : 384
    /*! The stock info popup layout (\c{buttons: "info"}). */
    readonly property bool info: buttons === "info"
    /*! The stock two-button confirmation layout (\c{buttons: "confirmDismiss"}). */
    readonly property bool twoButtons: buttons === "confirmDismiss"
    // the View-based styles: the info popup and the two-button confirmation
    readonly property bool _round: info || twoButtons
    /*! The message drawn in the info style: the text, or the title when there is no text. */
    readonly property string _message: info && text === "" ? title : text

    /* ---- stock layout in px (Compose ceilDp rounds the px up) ---- */
    readonly property real topPadding: info ? Math.floor(0.1248 * _h)
                                      : twoButtons ? Math.floor((hasIcon ? 0.104 : 0.1248) * _h)
                                      : hasIcon ? Math.ceil(0.012 * _h) : Math.ceil(0.10 * _h)
    readonly property real sidePadding: Math.ceil(0.052 * _w)
    readonly property real bottomPadding: _round && scrolling ? Math.floor(0.2083 * _h) : _fitBottomPadding
    // the bottom padding while the content fits: what scrolling is decided
    // on (it never reads bottomPadding, which reads scrolling: no binding
    // loop when a dialog changes style while shown)
    readonly property real _fitBottomPadding: _round ? infoBottomPadding
                                            : buttons === "edge" ? _edge.preferredHeight + Theme.size.edgeButtonBottomGap + edgeGap
                                            : 0.3646 * _h
    /*! Gap above the edge button: 4 dp, 16 dp with no text and no rows. */
    readonly property real edgeGap: (text === "" && _rows.children.length === 0) ? Theme.dp(16) : Theme.dp(4)
    readonly property real itemSpacing: Theme.dp(4)
    readonly property real iconSize: Theme.dp(32)
    readonly property real titleSidePadding: 0.12 * _w
    readonly property real textSidePadding: 0.0416 * _w
    readonly property real textTopSpacing: Theme.dp(4)
    /*! The edge button's check (28 dp). */
    readonly property real buttonIconSize: Theme.dp(28)
    /* the two-button confirmation (wear_alertdialog_* dimens) */
    /*! Two-button style: space between the round buttons (wear_alertdialog_buttons_gap 12 dp). */
    readonly property real roundButtonGap: Theme.dp(12)
    /*! Two-button style: the close and check glyphs (24 dp: about 30 x 30 and 36 x 27 px of ink, as S25). */
    readonly property real roundGlyphSize: Theme.dp(24)
    /*! Two-button style: space above the title (wear_alertdialog_title_margin_top 8 dp). */
    readonly property real titleTop: Theme.dp(8)
    /*! Two-button style: space above the text (wear_alertdialog_message_margin_top 12 dp). */
    readonly property real messageTop: Theme.dp(12)
    /*! Two-button style: space below the text and rows (wear_alertdialog_message_margin_bottom 16 dp). */
    readonly property real messageBottom: Theme.dp(16)
    /*! Two-button style: the title's first baseline below its top (15 sp) and the last above its bottom (5 sp). */
    readonly property real titleFirstBaseline: 15 * Theme.density * Theme.fontScale
    readonly property real titleLastBaseline: 5 * Theme.density * Theme.fontScale
    /*! Two-button style: the text's first baseline below its top (12 sp) and the last above its bottom (4 sp). */
    readonly property real textFirstBaseline: 12 * Theme.density * Theme.fontScale
    readonly property real textLastBaseline: 4 * Theme.density * Theme.fontScale
    /* the info popup (View px: getFraction() and the guidelines are whole px) */
    /*! Info style: bottom padding while the content fits (6.24 %). */
    readonly property real infoBottomPadding: Math.floor(0.0624 * _h)
    /*! Info style: space above the message (wear_alertdialog_title_margin_top 8 dp). */
    readonly property real infoTextTop: Theme.dp(8)
    /*! Info style: message padding at each side of the guidelines (16 dp). */
    readonly property real infoTextSidePadding: Theme.dp(16)
    /*! Info style: first baseline below the message top, last above its bottom (14 sp, 4 sp). */
    readonly property real infoFirstBaseline: 14 * Theme.density * Theme.fontScale
    readonly property real infoLastBaseline: 4 * Theme.density * Theme.fontScale
    /*! Info style: Title3 tracking, 0.025 em. */
    readonly property real infoTracking: 0.025
    /*! The round buttons (wear_chip_button_default_min_height 52 dp); the info style's check (26 dp). */
    readonly property real infoButtonSize: Theme.dp(52)
    readonly property real infoButtonIconSize: Theme.dp(26)
    readonly property real _spacing: _round ? 0 : itemSpacing

    /*! The content at its own size (rows unscaled), px. */
    readonly property real naturalHeight: {
        var rows = [_iconRow, _titleRow, _textRow, _rowsRow, _gapRow, _roundRow]
        var h = 0, n = 0
        for (var i = 0; i < rows.length; i++)
            if (rows[i].innerHeight > 0) {
                h += rows[i].innerHeight
                n++
            }
        return h + Math.max(0, n - 1) * _spacing
    }
    /*! The content does not fit: it scrolls as a scaling list. */
    readonly property bool scrolling: naturalHeight + topPadding + _fitBottomPadding > _h + 0.5
    // half the free height while it fits: above the content, and in the round
    // styles again between the content and the buttons (stock's packed chain)
    readonly property real _freeHalf: scrolling ? 0 : Math.max(0, (_h - topPadding - bottomPadding - naturalHeight) / 2)
    // two buttons: the View TextView boxes, from the first baseline to the
    // last one and its gap below. Qt makes the last line ceil(ascent +
    // descent) high, so the box is worked out here for the row and never
    // written back into the text (padding from contentHeight is a binding
    // loop: the text lays itself out again when its padding changes)
    readonly property real _titleBox: _title.topPadding + _titleMetrics.ascent
                                      + (_title.lineCount - 1) * _title.lineHeight + titleLastBaseline
    readonly property real _textBox: _text.topPadding + _textMetrics.ascent
                                     + (_text.lineCount - 1) * _text.lineHeight + textLastBaseline

    // stock starts the list at item 0
    function _toStart() {
        _list.contentY = -_list.topMargin
    }
    onOpened: _toStart()

    /*! The buttons, for tests and wrappers. */
    readonly property alias confirmButton: _confirmBtn
    readonly property alias dismissButton: _dismissBtn
    readonly property alias edgeButton: _edge
    readonly property alias infoButton: _infoBtn
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
        topMargin: alert.topPadding + alert._freeHalf
        onTopMarginChanged: if (!alert.scrolling || !alert.shown) alert._toStart()
        bottomMargin: alert.bottomPadding
        interactive: alert.scrolling
        boundsBehavior: Flickable.StopAtBounds
        clip: false

        Column {
            id: _col
            x: alert.sidePadding
            width: alert._w - 2 * alert.sidePadding
            spacing: alert._spacing

            EdgeRow {
                id: _iconRow
                innerHeight: alert.hasIcon ? alert.iconSize + (alert.twoButtons ? 0 : alert.itemSpacing) : 0
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
                innerHeight: alert.title !== "" && !alert.info ? _title.y + (alert.twoButtons ? alert._titleBox : _title.height) : 0
                Label {
                    id: _title
                    x: alert.twoButtons ? alert.infoTextSidePadding : alert.titleSidePadding - alert.sidePadding
                    y: alert.twoButtons ? alert.titleTop : 0
                    width: parent.width - 2 * x
                    text: alert.title
                    role: alert.titleRole
                    color: alert.twoButtons ? Theme.color.onSurface : Theme.color.onBackground
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    // two buttons: the View TextView's first and last
                    // baselines (accents above the box are not cut)
                    clip: !alert.twoButtons
                    FontMetrics {
                        id: _titleMetrics
                        font: _title.font
                    }
                    Binding on topPadding {
                        when: alert.twoButtons
                        value: alert.titleFirstBaseline - _titleMetrics.ascent
                    }
                }
            }
            EdgeRow {
                id: _textRow
                innerHeight: alert._message !== "" ? _text.y + (alert.twoButtons ? alert._textBox : _text.height) : 0
                Label {
                    id: _text
                    y: alert.info ? alert.infoTextTop : alert.twoButtons ? alert.messageTop : alert.textTopSpacing
                    x: alert.info ? alert.infoTextSidePadding : alert.textSidePadding
                    width: parent.width - 2 * x
                    text: alert._message
                    role: alert.info ? "titleMedium" : "bodyMedium"
                    color: alert._round ? Theme.color.onSurface : Theme.color.onBackground
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    // info and two buttons: the View TextView's lines (first
                    // and last baseline from the box edges; info in Title3
                    // tracking; Qt gives the last line its full font
                    // height), accents above the box not cut; else Label's
                    // own Compose line box
                    clip: !alert._round
                    font.letterSpacing: alert.info ? alert.infoTracking * Theme.type.titleMedium.pixelSize : Theme.type.bodyMedium.letterSpacing
                    topPadding: alert.info ? alert.infoFirstBaseline - _textMetrics.ascent
                              : alert.twoButtons ? alert.textFirstBaseline - _textMetrics.ascent
                              : (lineHeight - _textMetrics.height) / 2
                    bottomPadding: alert.info ? alert.infoLastBaseline - _textMetrics.descent : 0
                    FontMetrics {
                        id: _textMetrics
                        font: _text.font
                    }
                }
            }
            EdgeRow {
                id: _rowsRow
                innerHeight: _rows.children.length > 0 ? _rows.y + _rows.height : 0
                Column {
                    id: _rows
                    // two buttons: 4 dp under the text (the chain has no item gap)
                    y: alert.twoButtons ? alert.itemSpacing : 0
                    width: parent.width
                    spacing: alert.itemSpacing
                }
            }
            // two buttons: the text's bottom margin (16 dp) above the buttons
            EdgeRow {
                id: _gapRow
                innerHeight: alert.twoButtons ? alert.messageBottom : 0
            }
            // round styles: the rest of the free height, so the buttons sit at the bottom
            Item {
                width: _col.width
                height: alert._round ? alert._freeHalf : 0
                visible: alert._round
            }
            // the round buttons: dismiss and confirm, or the info popup's check
            EdgeRow {
                id: _roundRow
                innerHeight: alert._round ? alert.infoButtonSize : 0
                MouseArea {
                    id: _dismissBtn
                    width: alert.infoButtonSize
                    height: alert.infoButtonSize
                    x: parent.width / 2 - alert.roundButtonGap / 2 - width
                    visible: alert.twoButtons
                    Accessible.role: Accessible.Button
                    Accessible.name: qsTr("Dismiss")
                    Accessible.onPressAction: alert._dismiss()
                    onClicked: alert._dismiss()
                    Rectangle {
                        id: _dismissShape
                        anchors.fill: parent
                        radius: width / 2
                        color: Theme.color.surfaceContainer
                        Ripple {
                            radius: _dismissShape.radius
                            color: Theme.color.onSurface
                            pressed: _dismissBtn.pressed
                            pressX: _dismissBtn.mouseX
                            pressY: _dismissBtn.mouseY
                        }
                    }
                    DialogGlyph {
                        anchors.centerIn: parent
                        width: alert.roundGlyphSize
                        height: width
                        glyph: "close"
                        color: Theme.color.onSurface
                    }
                }
                MouseArea {
                    id: _confirmBtn
                    width: alert.infoButtonSize
                    height: alert.infoButtonSize
                    x: parent.width / 2 + alert.roundButtonGap / 2
                    visible: alert.twoButtons
                    Accessible.role: Accessible.Button
                    Accessible.name: qsTr("Confirm")
                    Accessible.onPressAction: alert._confirm()
                    onClicked: alert._confirm()
                    Rectangle {
                        id: _confirmShape
                        anchors.fill: parent
                        radius: width / 2
                        color: Theme.color.primary
                        Ripple {
                            radius: _confirmShape.radius
                            color: Theme.color.onPrimary
                            pressed: _confirmBtn.pressed
                            pressX: _confirmBtn.mouseX
                            pressY: _confirmBtn.mouseY
                        }
                    }
                    DialogGlyph {
                        anchors.centerIn: parent
                        width: alert.roundGlyphSize
                        height: width
                        glyph: "check"
                        color: Theme.color.onPrimary
                    }
                }
                MouseArea {
                    id: _infoBtn
                    width: alert.infoButtonSize
                    height: alert.infoButtonSize
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: alert.info
                    Accessible.role: Accessible.Button
                    Accessible.name: qsTr("OK")
                    Accessible.onPressAction: alert._confirm()
                    onClicked: alert._confirm()
                    Rectangle {
                        id: _infoShape
                        anchors.fill: parent
                        radius: width / 2
                        color: Theme.color.primary
                        Ripple {
                            radius: _infoShape.radius
                            color: Theme.color.onPrimary
                            pressed: _infoBtn.pressed
                            pressX: _infoBtn.mouseX
                            pressY: _infoBtn.mouseY
                        }
                    }
                    DialogGlyph {
                        anchors.centerIn: parent
                        width: alert.infoButtonIconSize
                        height: width
                        glyph: "check"
                        color: Theme.color.onPrimary
                    }
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
