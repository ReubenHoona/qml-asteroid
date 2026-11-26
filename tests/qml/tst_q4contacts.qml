import QtQuick
import QtTest
import org.asteroid.controls
import ContactsTest

// WO-61-Q4 copy of the A6 probe (a6h/tst_a6loop.qml): does scrolling the list in small steps (as tst_app's scrollRowTo) make the shared
// ScalingList log a height binding loop? ../org.asteroid.contacts is the contacts tree (CONTACTS=), which
// run-qemu.sh links beside the staged tests; without CONTACTS= the test is skipped.
// run-qemu: contacts
TestCase {
    id: tc
    name: "Q4contacts"
    when: windowShown
    visible: true
    width: 384
    height: 384

    // any binding loop fails (the A6 run logged ScalingList height loops on older controls)
    function init() { failOnWarning(/[Bb]inding loop/) }

    function test_scroll() {
        var m = function (key, nr) { return [{ k: key, t: "Mobile", nm: "10" + nr, d: 1 }] }
        Backend.reset()
        Backend.db = [
            { k: "t1", n: "Retest Contact", s: 0, p: 0, m: m("m1", "1"), info: {} },
            { k: "t2", n: "Sample Two", s: 0, p: 0, m: m("m2", "2"), info: {} },
            { k: "t3", n: "Test Three", s: 0, p: 0, m: m("m3", "3"), info: {} }
        ]
        var comp = Qt.createComponent(Qt.resolvedUrl("../org.asteroid.contacts/src/main.qml"))
        verify(comp.status === Component.Ready, comp.errorString())
        var a = comp.createObject(tc, { width: 384, height: 384 })
        tryCompare(a.browser.link, "phase", "ready")
        wait(800)
        var list = a.browser.layerStack.firstPageItem.list
        list.cacheBuffer = 100000
        for (var y = 0; y <= 260; y += 7) {
            list.contentY = -list.topMargin + y
            wait(30)
        }
        a.destroy()
    }
}
