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
    \qmltype Button
    \inqmlmodule org.asteroid.controls

    \brief The Wear OS Material 3 button: a 52 dp container with an icon, a
    label and an optional second line.

    Stock (FilledButtonTokens.java:7, FilledTonalButtonTokens.java:6,
    ButtonDefaults.java:21,33): at least 52 dp tall, CornerLarge (26 dp),
    label labelMedium (15 sp), second line labelSmall (13 sp), icon 26 dp,
    padding 14/6/14/6 dp, 6 dp between the icon and the text, content
    start-aligned. A bounded ripple in the content colour on press.

    \c variant picks the colours:
    \list
    \li \c filled (default): primary / onPrimary, second line onPrimary at 80 %.
    \li \c tonal: surfaceContainer / onSurface, second line and icon primary
        (FilledTonalButton; the Settings navigation row: the Wear OS 6
        emulator draws the second line in primary, S18-b 'After 1 minute'
        #D7DEF4, S20 'Will turn on at 10%' #DBE2F9).
    \li \c outlined: transparent with a 1 dp outlineVariant border (androidx
        OutlinedButtonTokens; not in the CP3A decomp), onSurface / primary icon.
    \li \c child: transparent, no border (ChildButton).
    \endlist
    Disabled: container onSurface at 12 % (filled), border onSurface at
    12 % (outlined), content onSurface at 38 %. A disabled tonal button
    keeps its surfaceContainer and draws its label, second line and icon in
    \c{Theme.color.disabledContentFlat} #80868B (the Wear OS 6 emulator
    S23-b: 'Set time / 6:58 PM').

    \l checkedGradient (0 to 1) lays the checked toggle row's gradient over
    the container: primary from 0 in the top left corner to 32.5 % in the
    bottom right one (mirrored right to left), as Wear Material 2's
    ToggleChip and the Wear OS 6 emulator's checked rows (S18-b, S21,
    S23: #35363D at x 30, #636671 at x 355 on #2F3036). \l SwitchButton
    drives it from its switch.

    In a Material 2 application (\l{Theme}{Theme.materialVersion} 2) the
    second line and the icon take the content colour, as Wear Material 2's
    ChipDefaults (secondaryContentColor = iconColor = contentColor for
    every chip): a tonal row is white on #303133 (S31 'Favorites' and its
    star, S29-b '7:02 PM' and 'One time').

    \qml
    Button { variant: "tonal"; iconName: "ios-settings"; text: "Settings"; secondaryText: "On" }
    \endqml
*/
MouseArea {
    id: button

    /*! "filled", "tonal", "outlined" or "child". */
    property string variant: "filled"
    /*! The label. */
    property string text: ""
    /*! The second line (empty: none). */
    property string secondaryText: ""
    /*! An icon name (empty: none). */
    property string iconName: ""
    /*! Centre the content (EdgeButton, TextButton, dialogs); stock buttons are start-aligned. */
    property bool centered: false

    /*! Corner radius: CornerLarge, clamped to a pill. */
    property real radius: Theme.shape.large
    /*! 14 dp sides (ButtonDefaults.java:21). */
    property real horizontalPadding: Theme.space.xl
    /*! 6 dp top and bottom (ButtonDefaults.java:21). */
    property real verticalPadding: Theme.space.s
    /*! Icon 26 dp (FilledButtonTokens.java:31-33). */
    property real iconSize: Theme.size.icon
    /*! 6 dp from the icon to the text. */
    property real iconSpacing: Theme.space.s
    /*! Minimum height 52 dp. */
    property real minimumHeight: Theme.size.button
    /*! Label lines: 3 with a second line, 5 without (controls-components-17). */
    property int maximumLineCount: secondaryText === "" ? 5 : 3
    /*! Second line: at most 2 lines. */
    property int secondaryMaximumLineCount: 2
    /*! Type roles of the two lines. */
    property string labelRole: "labelMedium"
    property string secondaryLabelRole: "labelSmall"

    readonly property bool _filled: variant === "filled"
    readonly property bool _tonal: variant === "tonal"
    readonly property bool _outlined: variant === "outlined"
    readonly property bool _m2: Theme.materialVersion === 2

    function _a(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    // disabled content: #80868B on a tonal button, onSurface 38 % otherwise
    readonly property color _disabledContent: _tonal ? Theme.color.disabledContentFlat
        : _a(Theme.color.onSurface, Theme.alpha.disabledContent)

    /*! Container colour by variant and state. */
    property color containerColor: !enabled
        ? (_tonal ? Theme.color.surfaceContainer : _filled ? _a(Theme.color.onSurface, Theme.alpha.disabledContainer) : "transparent")
        : _filled ? Theme.color.primary : _tonal ? Theme.color.surfaceContainer : "transparent"
    /*! Label colour. */
    property color contentColor: !enabled ? _disabledContent
        : _filled ? Theme.color.onPrimary : Theme.color.onSurface
    /*! Second line colour: primary on a tonal button; the content colour in
        a Material 2 application. */
    property color secondaryContentColor: _m2 ? contentColor
        : !enabled ? _disabledContent
        : _filled ? _a(Theme.color.onPrimary, Theme.alpha.secondaryOnFilled)
        : _tonal ? Theme.color.primary : Theme.color.onSurfaceVariant
    /*! Icon colour (the content colour in a Material 2 application). */
    property color iconColor: _m2 ? contentColor
        : !enabled ? _disabledContent
        : _filled ? Theme.color.onPrimary : Theme.color.primary
    /*! The checked toggle row's gradient over the container, 0 (none) to 1. */
    property real checkedGradient: 0
    /*! Border (outlined only): 1 dp outlineVariant; onSurface 12 % disabled. */
    property color borderColor: !_outlined ? "transparent"
        : enabled ? Theme.color.outlineVariant : _a(Theme.color.onSurface, Theme.alpha.disabledContainer)
    property real borderWidth: _outlined ? Theme.dp(1) : 0

    /*! The container and ripple items (for controls built on Button). */
    readonly property alias container: _container
    readonly property alias ripple: _ripple
    readonly property alias label: _label
    readonly property alias secondaryLabel: _secondary
    /*! Items placed after the text (the switch, radio and checkbox slots). */
    default property alias trailing: _trailing.data
    /*! Width of the trailing slot (0 = none). */
    property real trailingWidth: 0
    /*! Space between the text and the trailing slot: 6 dp. */
    property real trailingSpacing: Theme.space.s

    implicitWidth: Theme.dp(160)
    implicitHeight: Math.max(minimumHeight, _content.implicitHeight + 2 * verticalPadding)

    Accessible.role: Accessible.Button
    Accessible.name: text
    Accessible.description: secondaryText

    /*! Height of the visible container (CompactButton: 32 dp in a 48 dp touch area). */
    property real containerHeight: height

    Rectangle {
        id: _container
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
        }
        height: button.containerHeight
        radius: Math.min(button.radius, height / 2, width / 2)
        color: button.containerColor
        border.width: button.borderWidth
        border.color: button.borderColor

        // the checked gradient: primary from 0 at the top left corner to
        // 32.5 % x checkedGradient at the bottom right one (Compose's
        // default linearGradient, corner to corner), made only while shown
        Loader {
            anchors.fill: parent
            active: button.checkedGradient > 0
            sourceComponent: Shape {
                readonly property color _p: Theme.color.primary
                readonly property bool _mirrored: button.LayoutMirroring.enabled
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: -1
                    strokeColor: "transparent"
                    fillGradient: LinearGradient {
                        x1: _mirrored ? _container.width : 0
                        y1: 0
                        x2: _mirrored ? 0 : _container.width
                        y2: _container.height
                        GradientStop { position: 0; color: Qt.rgba(_p.r, _p.g, _p.b, 0) }
                        GradientStop { position: 1; color: Qt.rgba(_p.r, _p.g, _p.b, Theme.alpha.checkedGradient * button.checkedGradient) }
                    }
                    PathRectangle {
                        x: 0; y: 0
                        width: _container.width; height: _container.height
                        radius: _container.radius
                    }
                }
            }
        }

        Ripple {
            id: _ripple
            radius: _container.radius
            color: button.contentColor
            pressed: button.pressed
            pressX: button.mouseX
            pressY: button.mouseY - _container.y
        }
    }

    Row {
        id: _content
        anchors {
            left: button.centered ? undefined : parent.left
            leftMargin: button.horizontalPadding
            horizontalCenter: button.centered ? parent.horizontalCenter : undefined
            verticalCenter: parent.verticalCenter
        }
        spacing: button.iconSpacing
        readonly property real _avail: button.width - 2 * button.horizontalPadding
                                       - (button.trailingWidth > 0 ? button.trailingWidth + button.trailingSpacing : 0)

        Icon {
            id: _icon
            visible: button.iconName !== ""
            name: button.iconName
            color: button.iconColor
            width: visible ? button.iconSize : 0
            height: width
            anchors.verticalCenter: parent.verticalCenter
        }
        Column {
            id: _texts
            anchors.verticalCenter: parent.verticalCenter
            width: button.centered
                   ? Math.min(Math.max(_label.implicitWidth, _secondary.implicitWidth), _maxW)
                   : _maxW
            readonly property real _maxW: Math.max(0, _content._avail - (_icon.visible ? _icon.width + _content.spacing : 0))
            Label {
                id: _label
                width: parent.width
                visible: text !== ""
                text: button.text
                role: button.labelRole
                color: button.contentColor
                wrapMode: Text.Wrap
                maximumLineCount: button.maximumLineCount
                horizontalAlignment: button.centered ? Text.AlignHCenter : Text.AlignLeft
            }
            Label {
                id: _secondary
                width: parent.width
                visible: text !== ""
                text: button.secondaryText
                role: button.secondaryLabelRole
                color: button.secondaryContentColor
                wrapMode: Text.Wrap
                maximumLineCount: button.secondaryMaximumLineCount
                horizontalAlignment: button.centered ? Text.AlignHCenter : Text.AlignLeft
            }
        }
    }

    Item {
        id: _trailing
        width: button.trailingWidth
        height: parent.height
        anchors {
            right: parent.right
            rightMargin: button.horizontalPadding
        }
    }
}
