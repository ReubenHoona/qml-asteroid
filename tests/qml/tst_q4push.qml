// WO-61-Q4 N61-13 (left as it is): the stock Wear OS 6 Settings push (the
// emulator's 1x recording V12, Settings > Display) measured from the pixels
// against the LayerStack push tokens. The incoming page is scaled about the
// screen centre (its clock's top row: y 40, 36, 31, 27, 25, 22, 20, 19, 18
// against 16 at rest, so s = (192 - y) / 176) and the old page slides left,
// shrinks and dims (a whole-page fit outside the incoming circle). Both
// follow the current tokens (Compose PredictiveBackNavHost, as CP3A); a
// full-size page over an old page that stays put does not.
import QtQuick
import QtTest
import org.asteroid.controls

TestCase {
    id: tc
    name: "Q4push"

    function near(a, b, tol, msg) {
        verify(Math.abs(a - b) <= tol, msg + ": " + a + " != " + b + " (tol " + tol + ")")
    }
    WearSpring { id: ws }
    // a token spring from 0 to 1 at ms
    function prog(spring, ms) {
        return ws.sample(spring.stiffness, spring.dampingRatio, 0, 1, 0, ms)
    }
    // ms from the first moving frame (V12 frame 15, 1205.7 ms; the start
    // taken as 1190 ms, the frame before was at rest at 1186.8 ms)
    readonly property var newPageScale: [[48.4, 0.864], [65.7, 0.886], [83.5, 0.915], [99.8, 0.938], [117.2, 0.949],
                                         [133.4, 0.966], [151.3, 0.977], [168.7, 0.983], [184.1, 0.989]]
    readonly property var oldPage: [[31.5, -12, 0.98, 0.82], [48.4, -24, 0.96, 0.71], [65.7, -32, 0.96, 0.62],
                                    [83.5, -44, 0.94, 0.65], [99.8, -56, 0.92, 0.55], [117.2, -64, 0.92, 0.54]]

    function test_1_incomingPageScales() {
        var p = Motion.push
        compare(p.enterScale, 0.8, "the incoming page from 0.8")
        var log = []
        for (var i = 0; i < newPageScale.length; i++) {
            var t = newPageScale[i][0], s = p.enterScale + (1 - p.enterScale) * prog(p.enterScaleSpring, t)
            near(s, newPageScale[i][1], 0.015, "incoming page scale as stock at " + t + " ms")
            verify(Math.abs(1 - newPageScale[i][1]) > 0.01, "stock is not full size at " + t + " ms")
            log.push(t + " ms " + s.toFixed(3) + " (" + newPageScale[i][1] + ")")
        }
        console.log("Q4 push, incoming scale:", log.join("; "))
    }

    function test_2_oldPageMoves() {
        var p = Motion.push
        var log = []
        for (var i = 0; i < oldPage.length; i++) {
            var t = oldPage[i][0]
            var x = 384 * p.exitOffset * prog(p.exitX, t)
            var s = 1 - (1 - p.exitScale) * prog(p.exitScaleSpring, t)
            var a = 1 - (1 - p.exitAlpha) * prog(p.exitAlphaSpring, t)
            log.push(t + " ms x " + x.toFixed(0) + " (" + oldPage[i][1] + ") s " + s.toFixed(2) + " (" + oldPage[i][2]
                     + ") a " + a.toFixed(2) + " (" + oldPage[i][3] + ")")
            verify(oldPage[i][1] < -5 && oldPage[i][3] < 0.9, "stock: the old page moves and dims at " + t + " ms")
            near(s, oldPage[i][2], 0.03, "old page scale as stock at " + t + " ms")
            near(a, oldPage[i][3], 0.12, "old page alpha near stock at " + t + " ms")
            near(x, oldPage[i][1], Math.max(12, 0.7 * Math.abs(oldPage[i][1])), "old page x near stock at " + t + " ms")
        }
        console.log("Q4 push, old page:", log.join("; "))
    }
}
