/****************************************************************************
**
** Copyright (C) 2016 The Qt Company Ltd.
** Contact: https://www.qt.io/licensing/
**
** This file is part of the Qt Virtual Keyboard module of the Qt Toolkit.
**
** $QT_BEGIN_LICENSE:GPL$
** Commercial License Usage
** Licensees holding valid commercial Qt licenses may use this file in
** accordance with the commercial license agreement provided with the
** Software or, alternatively, in accordance with the terms contained in
** a written agreement between you and The Qt Company. For licensing terms
** and conditions see https://www.qt.io/terms-conditions. For further
** information use the contact form at https://www.qt.io/contact-us.
**
** GNU General Public License Usage
** Alternatively, this file may be used under the terms of the GNU
** General Public License version 3 or (at your option) any later version
** approved by the KDE Free Qt Foundation. The licenses are as published by
** the Free Software Foundation and appearing in the file LICENSE.GPL3
** included in the packaging of this file. Please review the following
** information to ensure the GNU General Public License requirements will
** be met: https://www.gnu.org/licenses/gpl-3.0.html.
**
** $QT_END_LICENSE$
**
****************************************************************************/

import QtQuick
import QtQuick.VirtualKeyboard
import org.asteroid.controls

FocusScope {
    id: textBase

    property var editor
    property bool previewTextActive: !editor.activeFocus && text.length === 0
    // bodyLarge (32 px at font scale 1.0), follows Display size & text
    property real fontPixelSize: Theme.type.bodyLarge.pixelSize
    property string previewText
    property int enterKeyAction: EnterKeyAction.None
    property string enterKeyText
    property bool enterKeyEnabled: enterKeyAction === EnterKeyAction.None || editor.text.length > 0 || editor.inputMethodComposing

    /*
     * Stock Wear OS has no edit box: a field is a row (surfaceContainer
     * pill, 52 dp high at least) with the application's hint (previewText)
     * as its label and the value, or dots for a password, below it in
     * onSurfaceVariant (a Button with a secondary label). A tap opens the
     * full screen keyboard with previewText as its hint (text-input-38).
     * The editor stays in the tree as the holder of the text and of the
     * focus, but draws nothing.
     */
    implicitHeight: Math.max(Theme.size.button, rowLabels.implicitHeight + 2 * Theme.space.s)
    /* What the row shows under its label: the text, or one dot per character of a password */
    readonly property string valueText: {
        var t = editor.text
        var mode = editor.echoMode
        if (mode === TextInput.Password || mode === TextInput.PasswordEchoOnEdit) {
            var dots = ""
            for (var i = 0; i < t.length; i++)
                dots += "•"
            return dots
        }
        return t
    }

    signal enterKeyClicked

    /*
     * Wear OS: a tap on the field opens the full screen keyboard
     * (WearKeyboard) over the whole window, with the text at its top; its
     * action key writes the text back (enterKeyClicked, and the editor's
     * accepted), a swipe leaves it unchanged. The editor never takes the
     * focus itself, so an application's InputPanel stays hidden. False: the
     * editor takes the focus and the application's InputPanel shows.
     */
    property bool fullScreenKeyboard: true
    /* The action key of the full screen keyboard: "done" (a tick) or "send" */
    property string keyboardAction: "done"
    property Item _keyboard: null
    /*
     * The application root (Application) the field sits in, if any. While the
     * full screen keyboard is open its keyboardOpen is true: the compositor
     * then answers a crown press with a close request instead of going Home
     * (Wear OS SHORT_PRESS_POWER_CLOSE_IME_OR_GO_HOME: the keyboard first,
     * the next press Home; buttons-navigation-12).
     */
    property Item _app: null

    function _appRoot() {
        for (var p = textBase.parent; p; p = p.parent) {
            if (p._asteroidAppRoot === true)
                return p
        }
        return null
    }
    function _setKeyboardOpen(open) {
        if (_app)
            _app.keyboardOpen = open
    }

    function openKeyboard() {
        if (!editor || editor.readOnly || _keyboard)
            return
        var root = textBase.Window.contentItem
        if (!root)
            return
        var limit = editor.maximumLength !== undefined && editor.maximumLength < 32767 ? editor.maximumLength : -1
        _keyboard = keyboardComponent.createObject(root, {
            "text": editor.text,
            "placeholderText": textBase.previewText,
            "echoMode": editor.echoMode !== undefined ? editor.echoMode : TextInput.Normal,
            "inputMethodHints": editor.inputMethodHints,
            "actionKey": textBase.keyboardAction,
            "maximumLength": limit
        })
        if (_keyboard) {
            _keyboard.forceActiveFocus()
            _app = _appRoot()
            _setKeyboardOpen(true)
        }
    }
    // the keyboard fades out (150 ms), then goes (motion-transitions-34).
    // The compositor hears of it at once: a second crown press during the
    // fade goes Home
    function _hideKeyboard() {
        _setKeyboardOpen(false)
        if (_keyboard)
            _keyboard.hide()
    }
    /*
     * The compositor asks for the keyboard to close (a crown press): what
     * was typed stays in the field, as it does with the input method of
     * Wear OS (it writes into the field as it goes), but nothing is sent
     * (no enterKeyClicked, no accepted).
     */
    function _crownClose() {
        if (!_keyboard)
            return
        textBase.editor.text = _keyboard.text
        _hideKeyboard()
    }
    function _closeKeyboard() {
        _setKeyboardOpen(false)
        if (!_keyboard)
            return
        _keyboard.destroy()
        _keyboard = null
        editor.focus = false
    }
    Connections {
        target: textBase._app
        ignoreUnknownSignals: true
        function onCloseKeyboardRequested() { textBase._crownClose() }
    }
    Component {
        id: keyboardComponent
        WearKeyboard {
            anchors.fill: parent
            z: 10000
            onAccepted: (text) => {
                textBase.editor.text = text
                textBase._hideKeyboard()
                textBase.enterKeyClicked()
                if (typeof textBase.editor.accepted === "function")
                    textBase.editor.accepted()
            }
            onDismissed: textBase._hideKeyboard()
            onClosed: textBase._closeKeyboard()
        }
    }
    // an application that gives the editor the focus wants the keyboard
    Connections {
        target: textBase.editor
        function onActiveFocusChanged() {
            if (textBase.fullScreenKeyboard && textBase.editor.activeFocus && !textBase._keyboard)
                Qt.callLater(textBase.openKeyboard)
        }
    }
    Component.onDestruction: {
        _setKeyboardOpen(false)
        if (_keyboard)
            _keyboard.destroy()
    }

    Keys.onReleased: (event) => {
        if (event.key === Qt.Key_Return)
            enterKeyClicked()
    }

    Rectangle {
        // the row: surfaceContainer, a pill as tall as the content allows
        id: rowContainer
        radius: textBase.fullScreenKeyboard ? Theme.shape.clamp(Theme.shape.large, height) : Theme.shape.extraSmall
        anchors.fill: parent
        color: Theme.color.surfaceContainer
        // an application that edits in place with its own InputPanel
        // (fullScreenKeyboard false) keeps the outlined box
        border {
            width: textBase.fullScreenKeyboard ? 0 : (editor.activeFocus ? Theme.dp(2) : Theme.dp(1))
            color: editor.activeFocus ? Theme.color.primary : Theme.color.outline
        }
    }
    Column {
        id: rowLabels
        anchors {
            left: parent.left; right: parent.right
            leftMargin: Theme.space.xl; rightMargin: Theme.space.xl
            verticalCenter: parent.verticalCenter
        }
        // the hint is the label (labelMedium), the value sits below it (labelSmall)
        Text {
            id: previewText
            width: parent.width
            clip: true
            elide: Text.ElideRight
            maximumLineCount: 2
            wrapMode: Text.Wrap
            color: Theme.color.onSurface
            visible: textBase.previewText.length > 0 && (textBase.fullScreenKeyboard || textBase.previewTextActive)
            text: textBase.previewText
            font.family: Theme.fontFamily
            font.weight: Theme.type.labelMedium.weight
            font.pixelSize: Theme.type.labelMedium.pixelSize
        }
        Text {
            id: valueLabel
            width: parent.width
            elide: Text.ElideRight
            maximumLineCount: textBase.valueLines
            wrapMode: Text.Wrap
            color: Theme.color.onSurfaceVariant
            visible: text.length > 0 && textBase.fullScreenKeyboard
            text: textBase.valueText
            font.family: Theme.fontFamily
            font.weight: Theme.type.labelSmall.weight
            font.pixelSize: Theme.type.labelSmall.pixelSize
        }
    }
    /* How many lines of the value the row shows (a text area shows more) */
    property int valueLines: 1
}
