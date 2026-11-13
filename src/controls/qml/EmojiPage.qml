/*
 * Copyright (C) 2026 Reuben Horner <reubarb.scons@gmail.com>
 * SPDX-License-Identifier: BSD-3-Clause
 */

import QtQuick
import Nemo.Configuration
import org.asteroid.controls
import "keyboard/KeyboardLayout.js" as L
import "emoji/EmojiLogic.js" as EL

/*!
    \qmltype EmojiPage
    \inqmlmodule org.asteroid.controls

    \brief The emoji page of Gboard for Wear OS (stock CP3A), a page of
    \l WearKeyboard.

    The header (15 % of the width, 57 px) holds the category tabs (a 20 dp icon
    in a 24 dp holder, #cac5bc, the selected one #fcf7eb with a 2 x 24 dp
    underline, 24 dp side padding) and the action key (#fcf7eb pill, 1.1 times
    the header height). Under it a grid of 4 columns (19 dp side padding, rows
    18 % of the width plus 1 dp = 71 px, 30 dp emoji, no cell background until
    pressed: #3d3d3d with 8 dp corners) with a fading edge; at the bottom two
    #32312f pills, "keyboard" and "delete". A 5 dp mark at the bottom right of
    an emoji with skin tones, which a long press (300 ms) opens as a full screen
    list. The tabs are: recently used (at most 8, the last first, kept in
    dconf /org/asteroidos/notifications/recent-emoji), then the nine groups of
    the Unicode emoji list.

    The crown first expands the page to the whole screen (the text line and the
    action key go, the bottom row fades), then scrolls; turned back with the grid
    at its top it collapses again.

    The page draws only the emoji and takes touches; the owner (WearKeyboard)
    puts the emoji in the text: \l picked, \l deleteRequested.

    \qml
    EmojiPage {
        anchors.fill: parent
        actionIcon: "ios-send"
        onPicked: (emoji) => field.insert(emoji)
        onDeleteRequested: field.backspace()
        onKeyboardRequested: showLetters()
    }
    \endqml
*/
FocusScope {
    id: page

    /*! The icon of the action key (Close with no text, else the keyboard's action) */
    property string actionIcon: "ios-checkmark"
    /*! Emoji newer than this Emoji version (x10, 160 = E16.0) are left out: the font cannot draw them */
    property int maxVersion: 160
    /*! Recent emoji kept (emoji_max_recent_count) */
    property int maxRecent: 8
    /*! Keep the recents in dconf; false: in memory only (tests) */
    property bool persist: true
    /*! Where the header starts when the page is not expanded: the top of the keyboard area */
    property real areaTop: _m.top
    /*! The columns of the grid (emoji_picker_column_count 4; 5 only from 225 dp wide) */
    property int columns: 4
    /*! The category shown: 0 recent, 1..9 the groups */
    property int category: -1
    /*! 0 the keyboard area, 1 the whole screen (the crown expands it) */
    property real expansion: 0
    /*! The skin tone list is open */
    readonly property bool variantsOpen: popup.items.length > 0

    /*! An emoji was tapped (or chosen in the variant list) */
    signal picked(string emoji)
    /*! The delete key was pressed (it repeats while held, as the keyboard's) */
    signal deleteRequested()
    /*! The "keyboard" key was tapped */
    signal keyboardRequested()
    /*! The action key was tapped */
    signal actionRequested()
    /*! Left with a right swipe */
    signal dismissed()

    // ---- geometry ----
    readonly property real _w: Math.min(width, height)
    readonly property var _g: EL.geometry(_w, columns)
    readonly property var _m: L.metrics(_w, height)
    readonly property real _headerInset: _g.u * 10
    readonly property real headerY: areaTop + (_headerInset - areaTop) * expansion
    readonly property real bodyY: headerY + _g.header
    // the bottom row is the keyboard's bottom row, 5 % down and fading while expanding
    readonly property real bottomRowY: _m.rowsY + 3 * _m.rowH
    readonly property real gridBottomMargin: (height - bottomRowY) + (_g.expandedBottom - (height - bottomRowY)) * expansion

    readonly property Item _grid: grid
    readonly property Item _tabs: tabList
    readonly property Item _popupItem: popup
    readonly property Item _bottomRow: bottomRow
    readonly property Item _actionKey: actionKey
    readonly property Item _headerItem: header
    readonly property QtObject _expandAnimation: expandAnim

    // the fixed Gboard Pixel palette (the keyboard's)
    readonly property QtObject _c: QtObject {
        readonly property color black: "#000000"
        readonly property color label: "#ffffff"
        readonly property color paper: "#fcf7eb"       // action key, selected tab
        readonly property color ink: "#202124"
        readonly property color fn: "#32312f"          // function key pills
        readonly property color pressed: "#3d3d3d"     // key_pressed_bordered_dark_theme
        readonly property color tab: "#cac5bc"         // header icon
        readonly property color hint: "#9aa0a6"        // empty text, variant mark (google_grey500)
        readonly property color placeholder: "#242424" // emoji_placeholder_background
    }

    // ---- texts (STRINGS.tsv emoji_*) ----
    readonly property var _names: [qsTr("Recents"), qsTr("Smileys and Emotions"), qsTr("People"),
                                   qsTr("Animals and nature"), qsTr("Food and drink"),
                                   qsTr("Travel and places"), qsTr("Activities and events"),
                                   qsTr("Objects"), qsTr("Symbols"), qsTr("Flags")]
    readonly property string emptyRecentText: qsTr("You haven't used any emojis yet")
    readonly property string emptyCategoryText: qsTr("No emojis available")
    readonly property string closeVariantsDescription: qsTr("Dismiss alternative Emojis")

    // ---- recents ----
    property ConfigurationValue _setting: ConfigurationValue {
        key: "/org/asteroidos/notifications/recent-emoji"
        defaultValue: []
    }
    property var _mem: []
    /*! The recently used emoji, the last first */
    readonly property var recents: EL.cleanRecents(persist ? _setting.value : _mem, maxRecent)
    function _remember(e) {
        var r = EL.addRecent(recents, e, maxRecent)
        if (persist)
            _setting.value = r
        else
            _mem = r
    }
    /*! Picks an emoji as a tap does: remembered, then \l picked */
    function pick(e) {
        _remember(e)
        popup.items = []
        picked(e)
    }

    // the page opens on the recents when there are some, else on the smileys
    Component.onCompleted: {
        if (category < 0)
            category = recents.length > 0 ? 0 : 1
    }
    readonly property var _model: category === 0 ? EL.recentItems(recents)
                                  : category > 0 ? EL.list(EL.tabs[category].id, maxVersion) : []
    onCategoryChanged: {
        grid.contentY = -grid.topMargin
        tabList.positionViewAtIndex(Math.max(0, category), ListView.Contain)
    }

    // ---- the crown ----
    /*! The crown: px > 0 scrolls forward. Expands the page first, then scrolls; collapses at the top */
    function crown(px) {
        if (popup.items.length > 0) {
            popupList.contentY = Math.max(0, Math.min(Math.max(0, popupList.contentHeight - popupList.height),
                                                      popupList.contentY + px))
            return "scroll"
        }
        var atTop = grid.contentY <= -grid.topMargin + _g.rowH
        var act = EL.crownAction(px, expansion, atTop)
        if (act === "expand") {
            if (!expandAnim.running)
                _animateTo(1)
        } else if (act === "collapse") {
            if (!expandAnim.running && Date.now() - _lastExpandEnd > 400)
                _animateTo(0)
        } else {
            var maxY = Math.max(-grid.topMargin, grid.contentHeight - grid.height + grid.bottomMargin)
            grid.contentY = Math.max(-grid.topMargin, Math.min(maxY, grid.contentY + px))
        }
        return act
    }
    property real _lastExpandEnd: 0
    function _animateTo(to) {
        expandAnim.stop()
        if (Motion.animationScale === 0) {
            expansion = to
            _lastExpandEnd = Date.now()
            return
        }
        expandAnim.to = to
        expandAnim.duration = Motion.duration(EL.expandDuration(expansion, to))
        expandAnim.start()
    }
    NumberAnimation {
        id: expandAnim
        target: page; property: "expansion"
        // DecelerateInterpolator(2.0) is 1 - (1 - t)^4
        easing.type: Easing.OutQuart
        onFinished: page._lastExpandEnd = Date.now()
    }
    /*! Folds back to the keyboard area */
    function collapse() { _animateTo(0) }

    // ---- what is drawn ----
    // black from the header down (the keyboard's text line stays visible above it); takes the touches
    // that nothing else wants, and a right swipe leaves
    Rectangle {
        y: page.headerY
        width: parent.width
        height: parent.height - y
        color: page._c.black
    }
    MouseArea {
        id: backdrop
        y: page.headerY
        width: parent.width
        height: parent.height - y
        DragHandler {
            id: swipe
            property bool fired: false
            enabled: !page.variantsOpen
            target: null
            yAxis.enabled: false
            onActiveChanged: if (active) fired = false
            onTranslationChanged: {
                if (active && !fired && translation.x > page.width * 0.25) {
                    fired = true
                    page.swipeRight()
                }
            }
        }
    }

    // the grid
    GridView {
        id: grid
        x: page._g.side
        y: page.bodyY
        width: page._g.gridW
        height: page.height - y
        cellWidth: page._g.cellW
        cellHeight: page._g.rowH
        topMargin: page._g.gridTop
        bottomMargin: page.gridBottomMargin
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: page._model
        // an 8 dp margin of slop: a tap is a tap
        pressDelay: 0
        delegate: Item {
            id: cell
            required property var modelData
            required property int index
            width: grid.cellWidth
            height: grid.cellHeight
            readonly property bool hasVariants: modelData.v.length > 0
            Rectangle {
                anchors.fill: parent
                radius: page._g.corner
                color: page._c.pressed
                visible: area.pressed
            }
            Text {
                anchors.centerIn: parent
                text: cell.modelData.e
                font.pixelSize: page._g.emoji
                color: "#ffffff"
            }
            // the skin tone mark: a 5 dp triangle in the bottom right corner (a square turned 45 degrees, clipped)
            Item {
                visible: cell.hasVariants
                width: page._g.indicator; height: width
                x: parent.width - width - page._g.u * 2
                y: parent.height - height - page._g.u * 2
                clip: true
                Rectangle {
                    width: parent.width * Math.SQRT2; height: width
                    x: parent.width - width / 2; y: parent.height - height / 2
                    rotation: 45
                    color: page._c.hint
                }
            }
            MouseArea {
                id: area
                anchors.fill: parent
                pressAndHoldInterval: 300
                property bool held: false
                onPressed: held = false
                onPressAndHold: {
                    if (cell.hasVariants) {
                        held = true
                        Haptics.longPress()
                        popup.open(cell.modelData)
                    }
                }
                onClicked: if (!held) { Haptics.keyboardTap(); page.pick(cell.modelData.e) }
            }
        }
    }

    // nothing to show: recents with no emoji yet
    Text {
        visible: page._model.length === 0 && page.category >= 0
        x: page._g.side + page._g.u * 7
        y: page.bodyY
        width: page._g.gridW - 2 * page._g.u * 7
        height: page.height - page.bodyY - page.gridBottomMargin
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.Wrap
        text: page.category === 0 ? page.emptyRecentText : page.emptyCategoryText
        color: page._c.hint
        font.pixelSize: Math.round(Theme.sp(16))
        font.family: Theme.fontFamily
    }

    // 12 dp fading edges of the grid (a View's default fadingEdgeLength)
    Rectangle {
        visible: grid.contentY > -grid.topMargin + 1
        x: grid.x; y: grid.y; width: grid.width; height: Theme.dp(12)
        gradient: Gradient {
            GradientStop { position: 0; color: page._c.black }
            GradientStop { position: 1; color: "#00000000" }
        }
    }
    Rectangle {
        readonly property real viewBottom: grid.contentY + grid.height - grid.bottomMargin
        visible: grid.contentHeight - viewBottom > 1
        x: grid.x; y: grid.y + grid.height - height; width: grid.width; height: Theme.dp(12)
        gradient: Gradient {
            GradientStop { position: 0; color: "#00000000" }
            GradientStop { position: 1; color: page._c.black }
        }
    }

    // the header: the tabs and the action key, on black over the grid
    Item {
        id: header
        x: 0; y: page.headerY
        width: parent.width; height: page._g.header
        Rectangle {
            anchors.fill: parent
            color: page._c.black
        }
        readonly property real keyW: page._g.actionW
        // the strip: from the 24 dp padding to the action key; the whole row when expanded
        readonly property real stripX: page._g.headerPad
        readonly property real stripW: width - 2 * page._g.headerPad
                                       - keyW * (1 - page.expansion)

        ListView {
            id: tabList
            x: header.stripX
            width: header.stripW
            height: parent.height
            orientation: ListView.Horizontal
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: EL.tabs
            delegate: Item {
                id: tab
                required property var modelData
                required property int index
                width: page._g.holderW
                height: tabList.height
                readonly property bool selected: index === page.category
                Rectangle {
                    anchors.fill: parent
                    radius: page._g.corner
                    color: page._c.pressed
                    visible: tabArea.pressed
                }
                Icon {
                    anchors.centerIn: parent
                    width: page._g.iconSize; height: width
                    name: tab.modelData.icon
                    color: tab.selected ? page._c.paper : page._c.tab
                }
                // the underline: 2 x 24 dp, rounded, at the bottom of the holder
                Rectangle {
                    visible: tab.selected
                    width: page._g.underlineW; height: page._g.underlineH
                    radius: height / 2
                    x: (parent.width - width) / 2
                    y: parent.height - height
                    color: page._c.paper
                }
                MouseArea {
                    id: tabArea
                    anchors.fill: parent
                    onClicked: { Haptics.keyboardTap(); page.category = tab.index }
                }
            }
        }
        // 12 dp fading edges of the tab strip
        Rectangle {
            visible: tabList.contentX > 1
            x: tabList.x; width: Theme.dp(12); height: parent.height
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: page._c.black }
                GradientStop { position: 1; color: "#00000000" }
            }
        }
        Rectangle {
            visible: tabList.contentWidth - tabList.contentX > tabList.width + 1
            x: tabList.x + tabList.width - width; width: Theme.dp(12); height: parent.height
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "#00000000" }
                GradientStop { position: 1; color: page._c.black }
            }
        }

        // the action key (WearFunctionKeyStyle.Key: #fcf7eb, 32 dp corners); not while expanded
        Item {
            id: actionKey
            readonly property real insetX: 1.35 * page._g.u
            readonly property real insetY: 2 * page._g.u
            x: parent.width - page._g.headerPad - width
            y: 0
            width: header.keyW; height: parent.height
            opacity: 1 - page.expansion
            visible: opacity > 0
            Rectangle {
                x: actionKey.insetX; y: actionKey.insetY
                width: parent.width - 2 * actionKey.insetX
                height: parent.height - 2 * actionKey.insetY
                radius: Math.min(height / 2, 32 * page._g.u)
                color: actionArea.pressed ? page._c.pressed : page._c.paper
            }
            Icon {
                anchors.centerIn: parent
                width: Theme.dp(24); height: width
                name: page.actionIcon
                color: page._c.ink
            }
            MouseArea {
                id: actionArea
                anchors.fill: parent
                enabled: page.expansion < 0.5
                onClicked: { Haptics.keyboardTap(); page.actionRequested() }
            }
        }
    }

    // the bottom row: [keyboard] [delete], #32312f pills, equal halves; fades while expanding
    Item {
        id: bottomRow
        readonly property var rect: L.rowRect(page._m, 3)
        x: rect.x; width: rect.w; height: page._m.rowH
        y: page.bottomRowY + page.height * 0.05 * page.expansion
        opacity: 1 - page.expansion
        visible: opacity > 0
        property bool deleteDown: false
        Repeater {
            model: ["keyboard", "delete"]
            delegate: Item {
                id: key
                required property string modelData
                required property int index
                readonly property bool down: modelData === "keyboard" ? keyboardArea.pressed : bottomRow.deleteDown
                x: index * bottomRow.width / 2
                width: bottomRow.width / 2
                height: bottomRow.height
                Rectangle {
                    x: 1.35 * page._g.u; y: 2 * page._g.u
                    width: parent.width - 2 * 1.35 * page._g.u
                    height: parent.height - 4 * page._g.u
                    radius: height / 2
                    color: key.down ? page._c.pressed : page._c.fn
                }
                Icon {
                    anchors.centerIn: parent
                    width: Theme.dp(24); height: width
                    name: key.modelData === "keyboard" ? "ios-keypad" : "ios-backspace-outline"
                    color: page._c.label
                }
                MouseArea {
                    id: keyboardArea
                    anchors.fill: parent
                    enabled: key.modelData === "keyboard" && page.expansion < 0.5
                    onClicked: { Haptics.keyboardTap(); page.keyboardRequested() }
                }
            }
        }
        // delete: once on press, then repeating after 300 ms like the keyboard's
        MouseArea {
            x: parent.width / 2; width: parent.width / 2; height: parent.height
            enabled: page.expansion < 0.5
            onPressed: { bottomRow.deleteDown = true; Haptics.keyboardTap(); page.deleteRequested(); holdTimer.restart() }
            onReleased: { bottomRow.deleteDown = false; holdTimer.stop(); repeatTimer.stop() }
            onCanceled: { bottomRow.deleteDown = false; holdTimer.stop(); repeatTimer.stop() }
        }
        Timer { id: holdTimer; interval: 300; onTriggered: { page.deleteRequested(); repeatTimer.start() } }
        Timer { id: repeatTimer; interval: 70; repeat: true; onTriggered: page.deleteRequested() }
    }

    // ---- the skin tone list: a full screen list of the variants, a close key under it ----
    Rectangle {
        id: popup
        property var items: []
        readonly property real cellW: Theme.dp(44 + 2 * 2)   // fullscreen_popup_emoji_width + margins 2 dp
        readonly property real cellH: Theme.dp(47 + 2 * 2)
        readonly property real sidePad: Theme.dp(24)
        readonly property real topPad: Theme.dp(24)
        readonly property real bottomPad: Theme.dp(34)
        readonly property int perRow: Math.max(1, Math.floor((parent.width - 2 * sidePad) / cellW))
        anchors.fill: parent
        visible: items.length > 0
        color: page._c.black
        function open(item) {
            popupList.contentY = 0
            items = [item.e].concat(item.v.filter(function (v) { return v !== item.e }))
        }
        // swallows the touches
        MouseArea { anchors.fill: parent; preventStealing: true }
        Flickable {
            id: popupList
            anchors.fill: parent
            topMargin: popup.topPad
            bottomMargin: popup.bottomPad
            contentWidth: width
            contentHeight: Math.ceil(popup.items.length / popup.perRow) * popup.cellH
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            Repeater {
                model: popup.items
                delegate: Item {
                    id: variant
                    required property string modelData
                    required property int index
                    readonly property int rowItems: Math.min(popup.perRow, popup.items.length - Math.floor(index / popup.perRow) * popup.perRow)
                    x: (popupList.width - rowItems * popup.cellW) / 2 + (index % popup.perRow) * popup.cellW
                    y: Math.floor(index / popup.perRow) * popup.cellH
                    width: popup.cellW; height: popup.cellH
                    Rectangle {
                        x: Theme.dp(2); y: Theme.dp(2)
                        width: parent.width - Theme.dp(4); height: parent.height - Theme.dp(4)
                        radius: page._g.corner
                        color: page._c.pressed
                        visible: variantArea.pressed
                    }
                    Text {
                        anchors.centerIn: parent
                        text: variant.modelData
                        font.pixelSize: page._g.emoji
                        color: "#ffffff"
                    }
                    MouseArea {
                        id: variantArea
                        anchors.fill: parent
                        onClicked: { Haptics.keyboardTap(); page.pick(variant.modelData) }
                    }
                }
            }
        }
        // the close key: 36 x 24 dp, #fcf7eb, 12 dp above the bottom edge
        Item {
            id: popupClose
            width: Theme.dp(36); height: Theme.dp(24)
            x: (parent.width - width) / 2
            y: parent.height - Theme.dp(12) - height
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: closeArea.pressed ? page._c.pressed : page._c.paper
            }
            Icon {
                anchors.centerIn: parent
                width: Theme.dp(20); height: width
                name: "ios-close"
                color: page._c.ink
            }
            MouseArea { id: closeArea; anchors.fill: parent; onClicked: popup.items = [] }
        }
    }
    readonly property Item _popupClose: popupClose
    readonly property Item _popupList: popupList

    /*! A right swipe: leaves (also callable from tests) */
    function swipeRight() {
        if (!variantsOpen)
            dismissed()
    }

    // back closes the variant list first
    function back() {
        if (variantsOpen) {
            popup.items = []
            return true
        }
        return false
    }
}
