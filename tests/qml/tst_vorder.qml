// Independent checks of WO-61-Q1 N61-01 (verifier): an Application that sets materialVersion: 2
// starts in the Material 2 colours, without a start-up colour animation, for an inline item and
// for ListView delegates; test_3 logs a Material 2 SwitchButton's colours.
import QtQuick
import QtTest
import org.asteroid.controls
Item {
    id: top
    width: 384; height: 384
    TestCase {
        name: "VOrder"
        when: windowShown
        function cleanup() { Theme.materialVersion = 3 }
        function test_1_inline() {
            Theme.materialVersion = 3
            var app = Qt.createQmlObject('import QtQuick; import org.asteroid.controls; Application { width: 384; height: 384; materialVersion: 2; property alias r: rr; property alias an: aa; property var log: []; Rectangle { id: rr; width: 10; height: 10; color: Theme.color.surfaceContainer; onColorChanged: log.push(String(color)); Behavior on color { ColorAnimation { id: aa; duration: 3000 } } } }', top)
            console.log("inline: running", app.an.running, "color", app.r.color, "log", JSON.stringify(app.log), "Theme mv", Theme.materialVersion)
            verify(!app.an.running, "no start-up colour animation")
            app.destroy(); wait(0)
        }
        function test_2_delegate() {
            Theme.materialVersion = 3
            var app = Qt.createQmlObject('import QtQuick; import org.asteroid.controls; Application { width: 384; height: 384; materialVersion: 2; property var items: []; ListView { anchors.fill: parent; model: 3; delegate: Rectangle { id: d; width: 100; height: 40; color: Theme.color.surfaceContainer; property alias an: a2; Component.onCompleted: items.push(d); Behavior on color { ColorAnimation { id: a2; duration: 3000 } } } } }', top)
            wait(50)
            var n = app.items.length, run = 0
            for (var i = 0; i < n; i++) if (app.items[i].an.running) run++
            console.log("delegate: items", n, "running", run, "color", n ? app.items[0].color : "-")
            verify(n > 0 && run === 0, "no delegate animation")
            app.destroy(); wait(0)
        }
        function test_3_switchButton() {
            Theme.materialVersion = 3
            var app = Qt.createQmlObject('import QtQuick; import org.asteroid.controls; Application { width: 384; height: 384; materialVersion: 2; property alias b: sb; SwitchButton { id: sb; width: 300; text: "x"; checked: true } }', top)
            console.log("switch: container", app.b.containerColor, "content", app.b.contentColor)
            app.destroy(); wait(0)
        }
    }
}
