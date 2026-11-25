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

    // The layout follows the language (locale-formats-05): rows, anchors, lists
    // and the directional icons mirror in Arabic, Hebrew, Persian ... as stock's
    // supportsRtl layouts do. The swipe back and the swipe to dismiss stay as they
    // are (they work on the touch position, BasicSwipeToDismissBox says "regardless
    // of layout direction"), and so do the keyboard's keys (WearKeyboard).
    LayoutMirroring.enabled: Theme.rtl
    LayoutMirroring.childrenInherit: true

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

    /*!
        The Wear Material generation of this application: 3 (default) or 2.
        On Wear OS 6 Clock (Stopwatch, Timer, Alarm), Contacts, Phone and
        Messages are Wear Material 2 apps with fixed colours; an application
        that follows one of them sets \c{materialVersion: 2}. The value is
        written to \l{Theme}{Theme.materialVersion} (each application is its
        own process, so it stays local): the colour roles take the
        Material 2 palette and the Color theme is not applied.
     */
    property int materialVersion: 3
    onMaterialVersionChanged: Theme.materialVersion = materialVersion
    Component.onCompleted: Theme.materialVersion = materialVersion

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

    /*!
        The distance of the time text from the screen edge in px:
        \c{Theme.size.timeTextEdgeMargin} (3.5 dp; 4.5 dp in a Material 2
        application) by default. An application whose stock screen has the
        time higher or lower sets its own (Media Controls: 1 dp, digit top
        y 10, S33).
    */
    property real timeTextMargin: Theme.size.timeTextEdgeMargin

    ConfigurationValue {
        id: _timeTextSetting
        key: "/org/asteroidos/ux/time-text"
        defaultValue: false
    }

    /*!
        The page's scrolling view: the time text scrolls away with it as
        stock does (\l ScrollAway, E46). Unset, the view a finger or the
        crown last scrolled is used (the position indicator reports it).
    */
    property Item scrollFlickable: null
    // set by PositionIndicator when it attaches to a view of this application
    readonly property bool _asteroidAppRoot: true
    property Item _autoScrollFlickable: null

    ScrollAway {
        id: _scrollAway
        flickable: _application.scrollFlickable ? _application.scrollFlickable : _application._autoScrollFlickable
    }

    TimeText {
        id: _timeText
        visible: showTime
        edgeMargin: _application.timeTextMargin
        z: 11
        opacity: _scrollAway.alpha
        transform: [
            Scale {
                origin.x: _timeText.width / 2
                origin.y: 0
                xScale: _scrollAway.scale
                yScale: _scrollAway.scale
            },
            Translate { y: _scrollAway.translateY }
        ]
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
        visible: false  // stock app screens draw no edge hints (AppScaffoldKt.java)
        z: 10
        anchors.verticalCenterOffset: DeviceSpecs.flatTireHeight/2
    }

    Indicator {
        id: topIndicator
        edge: Qt.TopEdge
        visible: false  // stock app screens draw no edge hints (AppScaffoldKt.java)
        z: 10
    }

    Indicator {
        id: bottomIndicator
        edge: Qt.BottomEdge
        visible: false
        z: 10
    }
}
