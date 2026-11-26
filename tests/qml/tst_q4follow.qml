// WO-61-Q4 follow-up from Settings (S1):
// - the scroll indicator: a shown Dialog is modal for RotaryInput. The
//   indicator of the screen under it goes when it opens (the Wear OS 6
//   confirmation S25 shows none), a touch on a dialog that fits shows none,
//   the crown does not scroll the list under it; a dialog whose content
//   scrolls shows its own indicator and takes the crown.
// - ListHeader.restAtTop: the page title stays at full size and alpha at the
//   list top (S1: brightest title pixel #E8E7EE exactly, as the emulator),
//   the edge effect coming in over the first 16 px of scroll.
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
    Flickable {
        id: list
        anchors.fill: parent
        contentHeight: col.height
        Column {
            id: col
            width: parent.width
            ListHeader { id: head; text: "Display"; minimumHeight: 0; color: Theme.color.onSurface }
            Repeater {
                model: 12
                ListItem { title: "Row " + index }
            }
        }
    }
    Item {
        id: host
        anchors.fill: parent
    }

    TestCase {
        id: tc
        name: "Q4follow"
        when: windowShown

        function near(a, b, tol, msg) {
            verify(Math.abs(a - b) <= tol, msg + ": " + a + " != " + b + " (tol " + tol + ")")
        }
        function cleanup() {
            mouseRelease(top, 1, 1)
            for (var i = host.children.length - 1; i >= 0; i--)
                host.children[i].destroy()
            head.restAtTop = false
            list.contentY = 0
            wait(50)
        }
        function make(src) {
            return Qt.createQmlObject('import QtQuick; import org.asteroid.controls; ' + src, host)
        }
        function indicator() {
            var kids = top.Window.contentItem.children
            for (var i = 0; i < kids.length; i++)
                if (kids[i].hasOwnProperty("flickable") && kids[i].hasOwnProperty("shown") && kids[i].hasOwnProperty("thumbColor"))
                    return kids[i]
            return null
        }
        function crown(counts) {
            var d = counts > 0 ? -120 : 120
            for (var i = 0; i < Math.abs(counts); i++) {
                mouseWheel(top, 192, 192, 0, d)
                wait(20)
            }
            wait(300)
        }
        function openSettled(d) {
            d.open()
            tryVerify(function() { return d.alpha === 1 && d.contentOffset === 0 }, 3000, "open")
        }

        // ---- the scroll indicator and the crown under a dialog ----
        function test_1_dialogCoversTheListIndicator() {
            list.contentY = 0
            mouseClick(list, 192, 250)          // a tap on a row of the list
            var pi = indicator()
            verify(pi !== null, "the position indicator exists")
            compare(pi.flickable, list, "the list under the finger")
            verify(pi.shown, "shown for the list (a new view flashes for 2 s)")
            var d = make('AlertDialog { anchors.fill: parent; title: "Restart"; text: "Are you sure?" }')
            verify(d.rotaryModal === false, "not modal while hidden")
            d.open()
            verify(d.rotaryModal, "modal while shown")
            verify(!pi.shown, "the list's indicator goes as the dialog opens")
            tryVerify(function() { return pi.opacity === 0 }, 2000, "faded out")
            waitForRendering(d)
            // a touch on a dialog that fits shows no indicator
            mousePress(d, 100, 150)
            wait(50)
            mouseRelease(d, 100, 150)
            verify(!pi.shown, "no indicator for a dialog that fits")
            compare(pi.opacity, 0)
            // the crown does not reach the list under it
            var cy = list.contentY
            crown(12)
            compare(list.contentY, cy, "the crown leaves the list under the dialog alone")
            verify(!pi.shown, "still no indicator")
            d.close()
            tryVerify(function() { return !d.active }, 3000)
            crown(12)
            verify(list.contentY > cy + 10, "without the dialog the crown scrolls the list: " + list.contentY)
        }

        function test_2_scrollingDialogShowsItsOwn() {
            var d = make('AlertDialog { anchors.fill: parent; title: "Wi-Fi"; text: "'
                         + "Wi-Fi uses more battery while it looks for networks. ".repeat(10) + '" }')
            openSettled(d)
            verify(d.scrolling)
            mousePress(d, 192, 200)
            wait(50)
            mouseRelease(d, 192, 200)
            var pi = indicator()
            compare(pi.flickable, d.flickable, "a dialog that scrolls has the indicator")
            verify(pi.shown, "shown")
            var cy = list.contentY, dy = d.flickable.contentY
            crown(12)
            verify(d.flickable.contentY > dy + 10, "the crown scrolls the dialog: " + d.flickable.contentY)
            compare(list.contentY, cy, "and not the list under it")
            d.close()
            tryVerify(function() { return !d.active }, 3000)
        }

        // ---- ListHeader.restAtTop ----
        function titleMax(img) {
            var m = 0
            for (var y = 0; y < 80; y++)
                for (var x = 100; x < 284; x++)
                    m = Math.max(m, img.pixel(x, y).r * 255 + img.pixel(x, y).g * 255 + img.pixel(x, y).b * 255)
            return m
        }
        function test_3_restAtTop() {
            list.contentY = 0
            head.restAtTop = false
            wait(100)
            var plain = head.label.opacity, plainScale = head.transform[0].xScale
            console.log("Q4 header at rest without restAtTop: alpha", plain.toFixed(4), "scale", plainScale.toFixed(4))
            verify(plain < 0.995, "this header is inside the edge area at rest: " + plain)
            waitForRendering(list)
            var m0 = titleMax(grabImage(top))
            head.restAtTop = true
            wait(100)
            compare(head.label.opacity, 1, "full alpha at the top")
            compare(head.transform[0].xScale, 1, "full size at the top")
            compare(head.transform[1].y, 0, "not moved")
            waitForRendering(list)
            var img = grabImage(top)
            img.save("shots/header-rest.png")
            var m1 = titleMax(img)
            console.log("Q4 brightest title pixel (r+g+b): plain", m0, "restAtTop", m1, "(#E8E7EE:", 0xE8 + 0xE7 + 0xEE, ")")
            compare(m1, 0xE8 + 0xE7 + 0xEE, "the title draws #E8E7EE exactly")
            verify(m0 < m1, "dimmer without it")
            // half way through the 16 px ramp: half the effect
            list.contentY = 8
            wait(100)
            var a8 = head.label.opacity
            head.restAtTop = false
            wait(100)
            var p8 = head.label.opacity
            near(a8, 1 - 0.5 * (1 - p8), 0.002, "8 px: half the effect")
            // past the ramp: the plain effect
            list.contentY = 60
            wait(100)
            var p60 = head.label.opacity, s60 = head.transform[0].xScale
            head.restAtTop = true
            wait(100)
            near(head.label.opacity, p60, 1e-6, "60 px: the plain alpha")
            near(head.transform[0].xScale, s60, 1e-6, "60 px: the plain scale")
            // pulled past the top: at rest
            list.contentY = -20
            wait(100)
            compare(head.label.opacity, 1, "pulled past the top: at rest")
            list.contentY = 0
            wait(100)
            compare(head.label.opacity, 1, "back at the top: at rest")
        }
    }
}
