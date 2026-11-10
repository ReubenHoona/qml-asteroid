/*
 * Copyright (C) 2016 Florent Revest <revestflo@gmail.com>
 *               2015 Tim Süberkrüb <tim.sueberkrueb@web.de>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as
 * published by the Free Software Foundation, either version 2.1 of the
 * License, or (at your option) any later version.
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
import Nemo.Configuration
import org.asteroid.controls
import org.asteroid.utils

/*!
    \qmltype Application
    \inqmlmodule org.asteroid.controls
    \brief Shows a flat mesh background with indicators.

    The Application type is intended to be used as the top level QML object
    for graphical applications on AsteroidOS.  By default only the top and
    left indicators are visible and the bottom and right indicators are not.

    Here's a short example:

    \qml
    import QtQuick
    import org.asteroid.controls

    Application {
        // Wear OS applications are black (Theme.color.background); this one
        // opts in to the animated flat mesh background instead
        id: myapp
        meshBackground: true
        centerColor: "#00010B"
        outerColor: "#E044A6"
        // make all indicators visible
        rightIndicVisible: true
        bottomIndicVisible: true

        Rectangle {
            id: square
            anchors.centerIn: parent
            color: "yellow"
            width: parent.width * 0.4
            height: parent.height * 0.2
        }
    }
    \endqml
*/

Application_p {
    id: _application
    anchors.fill: parent

    /*!
        Draw the animated \l FlatMesh gradient behind the content. Off by
        default: every Wear OS application screen is plain black
        (colorScheme.background, AppScaffoldKt.java:28), which also leaves
        the AMOLED pixels off and the GPU idle after touches. Upstream
        applications that want the mesh set this to true.
     */
    property bool meshBackground: false
    /*!
        The background colour: \l Theme color.background (#000000).
     */
    property color backgroundColor: Theme.color.background
    /*!
        Outer color for the flat mesh (only drawn with meshBackground).
     */
    property color outerColor: "#df4829"
    /*!
        Inner color for the flat mesh (only drawn with meshBackground).
     */
    property color centerColor: "#ffaa39"

    function animIndicators() {
        rightIndicator.animate();
        leftIndicator.animate();
        topIndicator.animate();
        bottomIndicator.animate();
    }

    Rectangle {
        id: _background
        anchors.fill: parent
        anchors.bottomMargin: -DeviceSpecs.flatTireHeight
        color: backgroundColor
        visible: !meshBackground
    }

    Loader {
        id: _mesh
        anchors.fill: parent
        anchors.bottomMargin: -DeviceSpecs.flatTireHeight
        active: meshBackground
        sourceComponent: FlatMesh {
            centerColor: _application.centerColor
            outerColor: _application.outerColor
        }
    }

    /*!
        Show the time at the top of the screen, curved along its edge, as
        Wear OS does in its applications (\l TimeText). Defaults to the
        dconf key /org/asteroidos/ux/time-text (false).
    */
    property bool showTime: _timeTextSetting.value

    ConfigurationValue {
        id: _timeTextSetting
        key: "/org/asteroidos/ux/time-text"
        defaultValue: false
    }

    TimeText {
        visible: showTime
        z: 11
    }

    /*!
        Is the right indicator visible?
     */
    property alias rightIndicVisible:  rightIndicator.visible
    /*!
        Is the left indicator visible?
     */
    property alias leftIndicVisible:   leftIndicator.visible
    /*!
        Is the top indicator visible?
     */
    property alias topIndicVisible:    topIndicator.visible
    /*!
        Is the bottom indicator visible?
     */
    property alias bottomIndicVisible: bottomIndicator.visible

    Indicator {
        id: rightIndicator
        edge: Qt.RightEdge
        visible: false
        z: 10
        anchors.verticalCenterOffset: DeviceSpecs.flatTireHeight/2
    }

    Indicator {
        id: leftIndicator
        edge: Qt.LeftEdge
        visible: true
        z: 10
        anchors.verticalCenterOffset: DeviceSpecs.flatTireHeight/2
    }

    Indicator {
        id: topIndicator
        edge: Qt.TopEdge
        visible: true
        z: 10
    }

    Indicator {
        id: bottomIndicator
        edge: Qt.BottomEdge
        visible: false
        z: 10
    }
}
