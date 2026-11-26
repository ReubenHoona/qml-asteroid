// WO-61-Q4 follow-up: no binding loop while a two-button and an info
// AlertDialog open, scroll and close (the Settings runs logged "Binding loop
// detected" at AlertDialog.qml:333 and :343: the two-button text boxes wrote
// a padding worked out from contentHeight back into the text). Every test
// fails on any binding-loop warning.
import QtQuick
import QtTest
import org.asteroid.controls

Item {
    id: top
    width: 384
    height: 384

    Rectangle {
        anchors.fill: parent
        color: "#000000"
    }
    Item {
        id: host
        anchors.fill: parent
    }

    TestCase {
        id: tc
        name: "Q4loops"
        when: windowShown

        function init() {
            failOnWarning(/[Bb]inding loop/)
        }
        function cleanup() {
            for (var i = host.children.length - 1; i >= 0; i--)
                host.children[i].destroy()
            wait(0)
        }
        function make(src) {
            return Qt.createQmlObject('import QtQuick; import org.asteroid.controls; ' + src, host)
        }
        // open, scroll through (when it scrolls), close; twice, the second
        // time reopened while it fades out
        function cycle(d) {
            for (var round = 0; round < 2; round++) {
                d.open()
                tryVerify(function() { return d.alpha === 1 && d.contentOffset === 0 }, 3000, "open")
                waitForRendering(d)
                if (d.scrolling) {
                    var f = d.flickable
                    var end = f.contentHeight + f.bottomMargin - f.height
                    for (var y = -f.topMargin; y <= end; y += 37) {
                        f.contentY = y
                        wait(16)
                    }
                    mouseDrag(d, 192, 300, 0, -120)
                    wait(100)
                    f.contentY = -f.topMargin
                    wait(16)
                }
                d.close()
                if (round === 0) {
                    wait(40)
                    d.open()
                    tryVerify(function() { return d.alpha === 1 }, 3000, "reopened")
                    d.close()
                }
                tryVerify(function() { return !d.active }, 3000, "closed")
            }
        }
        readonly property string long: "Wi-Fi uses more battery while it looks for networks. ".repeat(10)

        function test_1_twoButtons() {
            cycle(make('AlertDialog { anchors.fill: parent; title: "Restart"; text: "Are you sure?" }'))
            cycle(make('AlertDialog { anchors.fill: parent; titleRole: "titleLarge"; title: "Restart"; text: "Are you sure?" }'))
            cycle(make('AlertDialog { anchors.fill: parent; title: "Turn on Bedtime mode?"; text: "Notifications and the screen stay off" }'))
        }
        function test_2_twoButtonsScrolling() {
            var d = make('AlertDialog { anchors.fill: parent; title: "Wi-Fi"; text: "' + long + '" }')
            cycle(d)
            verify(d.scrolling, "it scrolled")
            // the text changes while shown (a caller that fills it in late)
            d.open()
            tryVerify(function() { return d.alpha === 1 }, 3000)
            d.text = "Are you sure?"
            wait(50)
            d.title = "A title that wraps onto a second line here"
            wait(50)
            d.close()
            tryVerify(function() { return !d.active }, 3000)
        }
        function test_3_iconAndRows() {
            cycle(make('AlertDialog { anchors.fill: parent; title: "Bedtime"; text: "' + long + '"; iconName: "ios-moon"; '
                       + 'CheckboxButton { width: parent ? parent.width : 300; text: "Do not ask again" } }'))
        }
        function test_4_info() {
            cycle(make('AlertDialog { anchors.fill: parent; buttons: "info"; text: "For legal notices, see device paired with your watch" }'))
            var d = make('AlertDialog { anchors.fill: parent; buttons: "info"; text: "' + long + '" }')
            cycle(d)
            verify(d.scrolling, "the long info scrolled")
        }
        // a shared list scrolled in small steps (the Contacts tst_app's
        // scrollRowTo: 7 px at a time): the ScalingList row keeps its
        // natural height (N61-04), so its height binding never sees the
        // edge effect; and a Flickable of packed rows with a ListHeader
        function test_6_listsInSmallSteps() {
            var l = make('ScalingList { anchors.fill: parent; model: 40; cacheBuffer: 100000; '
                         + 'itemDelegate: Item { property int index: 0; width: parent ? parent.width : 0; '
                         + 'height: index % 5 === 0 ? sub.implicitHeight : row.implicitHeight; '
                         + 'ListSubHeader { id: sub; visible: index % 5 === 0; text: "Letter " + index } '
                         + 'ListItem { id: row; visible: index % 5 !== 0; width: parent.width; title: "Row " + index } } }')
            for (var y = 0; y <= 900; y += 7) {
                l.contentY = -l.topMargin + y
                wait(5)
            }
            l.contentY = -l.topMargin
            wait(50)
            var f = make('Flickable { anchors.fill: parent; contentHeight: c.height; '
                         + 'Column { id: c; width: parent.width; ListHeader { text: "Display"; restAtTop: true } '
                         + 'Repeater { model: 20; ListItem { title: "Row " + index } } } }')
            for (y = 0; y <= 600; y += 7) {
                f.contentY = y
                wait(5)
            }
            f.contentY = 0
            wait(50)
        }
        function test_5_styleSwitch() {
            // a caller that turns one dialog from the info popup to the two
            // buttons and back (Settings ConfirmDialog: ask() and tell())
            var d = make('AlertDialog { anchors.fill: parent; title: "Restart"; text: "Are you sure?" }')
            cycle(d)
            d.buttons = "info"; d.title = ""
            cycle(d)
            d.buttons = "edge"; d.title = "About Wi-Fi"
            cycle(d)
            d.buttons = "confirmDismiss"
            cycle(d)
        }
    }
}
