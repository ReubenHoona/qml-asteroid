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
import QtQuick.Window
import org.asteroid.controls

/*!
    \qmltype OptionCycler
    \inqmlmodule org.asteroid.controls

    \brief A row that shows a setting's value and lets the user pick another.

    Stock never cycles a value on tap (E20): the row shows the value as its
    second line and a tap opens a list of radio buttons (a choice page) with
    the row's label as its title; picking one closes the list. The choice
    page fills the window; swipe right to leave it without a change. The
    public API is unchanged: \l valueArray, \l currentValue and
    \l valueChanged.

    \qml
    import QtQuick
    import org.asteroid.controls

    Item {
        anchors.fill: parent
        property var designOptions: ["diamonds", "bubbles", "logos", "flashes"]

        OptionCycler {
            width: parent.width
            text: "Design"
            valueArray: designOptions
            currentValue: designOptions[0]
            onValueChanged: currentValue = value
        }
    }
    \endqml
*/
ListRow {
    id: root

    /*!
        \qmlproperty var OptionCycler::valueArray
        The values to choose from.
    */
    property var valueArray
    /*!
        \qmlproperty string OptionCycler::currentValue
        The currently selected value.
    */
    property string currentValue
    /*!
        \qmlsignal OptionCycler::valueChanged(string value)
        Emitted when the user picks a value, passing the new \a value.
    */
    signal valueChanged(string value)
    /*!
        \qmlproperty int OptionCycler::valueFontSize
        Size of the value text (the second line): labelSmall, 13 sp.
    */
    property int valueFontSize: Theme.type.labelSmall.pixelSize
    /*! The choice page is open. */
    readonly property bool choosing: _chooser.active
    /*! The choice page while it is open (for tests). */
    readonly property Item chooserItem: _chooser.item

    secondaryText: currentValue

    /*! Open the choice page. */
    function openChooser() {
        _chooser.active = true
    }
    /*! Close the choice page. */
    function closeChooser() {
        _chooser.active = false
    }
    /*! Pick \a value (as a tap on its radio row does). */
    function choose(value) {
        closeChooser()
        if (value !== currentValue)
            valueChanged(value)
    }

    onClicked: openChooser()

    Loader {
        id: _chooser
        active: false
        parent: root.Window.contentItem ? root.Window.contentItem : root
        anchors.fill: parent
        z: 1000
        sourceComponent: Rectangle {
            color: Theme.color.background
            // the window's content item is not below the application: it takes its layout direction
            LayoutMirroring.enabled: root.LayoutMirroring.enabled
            LayoutMirroring.childrenInherit: true
            MouseArea { anchors.fill: parent }   // the page below gets no taps

            BackSwipeArea {
                id: back
                anchors.fill: parent
                onFinished: {
                    if (committed)
                        root.closeChooser()
                    else
                        reset()
                }
                ListView {
                    id: list
                    anchors.fill: parent
                    topMargin: Theme.margin.listTop
                    bottomMargin: Theme.margin.listBottom
                    spacing: Theme.space.xs
                    model: root.valueArray
                    header: ListHeader { text: root.text }
                    delegate: RadioButton {
                        x: Theme.margin.listSide
                        width: list.width - 2 * Theme.margin.listSide
                        text: modelData
                        checked: modelData === root.currentValue
                        onClicked: root.choose(modelData)
                    }
                }
            }
        }
    }
}
