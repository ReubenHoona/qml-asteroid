import QtQuick
import QtTest
import org.asteroid.controls

// WO-03 (image 60 defect list): D60-13 the time text scrolls away under the
// crown, D60-09 RotaryInput.flashIndicator(view). 384 x 384, 2 px per dp;
// the crown as the image sets it (crown-fast, 7.5 px per count from the
// image's dconf database, 24 counts per detent: 180 px).
TestCase {
    id: tc
    name: "WO03"
    when: windowShown
    visible: true
    width: 384
    height: 384

    function near(a, b, tol, msg) {
        verify(Math.abs(a - b) <= tol, msg + ": " + a + " != " + b + " (tol " + tol + ")")
    }
    function childWith(item, prop) {
        for (var i = 0; i < item.children.length; i++) {
            if (item.children[i][prop] !== undefined)
                return item.children[i]
        }
        return null
    }
    // the one shared indicator RotaryInput puts on top of the window
    function indicator() {
        var root = tc.Window.contentItem
        for (var i = 0; i < root.children.length; i++) {
            var c = root.children[i]
            if (c.thumbLength !== undefined && c.flash !== undefined)
                return c
        }
        return null
    }
    // one crown detent forward (towards the end of the list)
    function notch(item) {
        mouseWheel(item, 192, 192, 0, -120 * 24)
    }
    // wait until the crown glide has stopped writing contentY
    function settle(list) {
        var y = list.contentY
        for (var i = 0; i < 100; i++) {
            wait(50)
            if (list.contentY === y)
                return
            y = list.contentY
        }
    }

    // an application page as the Settings pages are: a list of 52 dp rows
    // under the time text, top margin as ScalingList (listTop)
    Component {
        id: appPage
        Application {
            width: 384
            height: 384
            showTime: true
            property alias list: lv
            ListView {
                id: lv
                anchors.fill: parent
                model: 20
                spacing: 8
                topMargin: Theme.margin.listTop
                bottomMargin: Theme.margin.listBottom
                delegate: Rectangle { width: lv.width; height: 104; color: "#2F3036" }
            }
        }
    }

    // ---- D60-13: the crown scrolls the time text away ----
    function test_1_crownScrollsTimeAway() {
        var app = createTemporaryObject(appPage, tc)
        verify(app !== null, "application page")
        var lv = app.list
        var sa = childWith(app, "idleDelay")
        var tt = childWith(app, "maxSweep")
        verify(sa !== null && tt !== null, "ScrollAway and TimeText")
        verify(tt.visible, "time text shown")
        wait(100)
        compare(lv.contentY, -lv.topMargin, "list at the top")
        compare(tt.opacity, 1, "time text opaque at rest")

        // a few counts: under the 36 dp (72 px) threshold
        mouseWheel(lv, 192, 192, 0, -120 * 4)
        compare(sa.flickable, lv, "the crown hands its view to the time text (indicator)")
        tryCompare(sa, "stage", 2, 500, "a crown scroll is Scrolling (ScreenContent.java:68-83)")
        settle(lv)
        var off = lv.contentY - lv.originY + lv.topMargin
        verify(off > 5 && off < 72, "a short crown scroll under 36 dp: " + off)
        compare(sa.stage, 2, "still Scrolling right after the crown stops")
        near(sa.progressValue, off / 72, 0.02, "p = offset / 36 dp")
        near(sa.scale, 1 - 0.5 * off / 72, 0.01, "scale 1 - 0.5 p")
        near(sa.translateY, -off / 72 * 48, 0.5, "up p x 24 dp")
        compare(sa.alphaValue, 1, "under 36 dp: alpha 1")
        near(tt.opacity, 1 - 0.5 * off / 72, 0.01, "time text opacity = alpha x scale")

        // five more detents, 100 ms apart: well past 36 dp
        for (var i = 0; i < 5; i++) {
            notch(lv)
            wait(100)
            compare(sa.stage, 2, "Scrolling while the crown turns (" + i + ")")
            if (lv.contentY - lv.originY + lv.topMargin > 72) {
                compare(sa.alphaValue, 0, "past 36 dp while turning: alpha snapped to 0")
                compare(tt.opacity, 0, "no time text over the first row while turning")
            }
        }
        settle(lv)
        off = lv.contentY - lv.originY + lv.topMargin
        verify(off > 72, "six detents are past 36 dp: " + off)
        compare(sa.progressValue, 1, "p = 1")
        compare(tt.opacity, 0, "no time text when the crown stops")
        wait(300)
        compare(tt.opacity, 0, "no time text 0.3 s after the crown stops")
        compare(sa.stage, 2, "0.3 s after: still Scrolling")

        // idle 2000 ms after the last move (ScreenContent$...$2$1.java:45):
        // back at full size, alpha over 250 ms, progress snaps
        wait(1200)
        compare(sa.stage, 2, "1.5 s after: not idle yet")
        compare(tt.opacity, 0, "1.5 s after: still away")
        tryCompare(sa, "stage", 1, 1500, "idle 2 s after the crown stops")
        compare(sa.progressValue, 0, "back at idle: progress snaps to 0")
        compare(sa.scale, 1, "full size")
        compare(sa.translateY, 0, "not shifted")
        wait(400)
        compare(sa.alphaValue, 1, "alpha back after 250 ms")
        compare(tt.opacity, 1, "time text back over the scrolled list (B42)")

        // one more detent at idle: gone again at once
        notch(lv)
        wait(60)
        compare(sa.stage, 2, "Scrolling again")
        compare(tt.opacity, 0, "gone again on the next detent")
    }

    // ---- D60-13: any position change without a finger is a scroll ----
    Item {
        id: fix
        width: 384
        height: 384
        visible: false
        Flickable { id: fa; anchors.fill: parent; contentHeight: 1200 }
        Flickable { id: fb; anchors.fill: parent; contentHeight: 1200; contentY: 300 }
        ScrollAway { id: sa2 }
    }
    function test_2_programmaticScroll() {
        fix.visible = true
        sa2.flickable = fa
        compare(sa2.stage, 0, "a new view starts New")
        fa.contentY = 36
        compare(sa2.stage, 2, "contentY written without a finger: Scrolling")
        wait(260)
        near(sa2.progressValue, 0.5, 0.01, "p = 36 px / 72 px")
        near(sa2.alpha, 0.75, 0.01, "alpha x scale")
        fa.contentY = 54
        near(sa2.progressValue, 0.75, 0.001, "follows the scroll directly (snap)")
        fa.contentY = 100
        compare(sa2.alphaValue, 0, "past 36 dp: alpha snaps to 0")
        // a layout change that moves no content is not a scroll
        tryCompare(sa2, "stage", 1, 2500, "idle 2 s after the last move")
        tryCompare(sa2, "alphaValue", 1, 600, "back at idle")
        fa.topMargin = 10
        compare(sa2.stage, 1, "a margin change is not a scroll")
        compare(sa2.alphaValue, 1, "time text stays")
        fa.topMargin = 0
        // switching views (offset 100 -> 300) is a new screen, not a scroll
        fa.contentY = 0
        sa2.flickable = fb
        compare(sa2.stage, 0, "another view: New, not Scrolling")
        compare(sa2.alphaValue, 1, "New and gone: shown")
        fb.contentY = 320
        compare(sa2.stage, 2, "then its own move is Scrolling")
        compare(sa2.alphaValue, 0, "and the time text goes")
        sa2.flickable = null
        fb.contentY = 300
        fix.visible = false
    }

    // ---- D60-13: the view's own fixup after a layout change is not a scroll ----
    // (stock: ScreenContent.java:68-83 sets Scrolling only while
    // isScrollInProgress; a LazyList re-measure runs outside scroll())
    Item {
        id: fix5
        width: 384
        height: 384
        visible: false
        Flickable {
            id: fc
            width: 384
            height: 384
            bottomMargin: 100
            contentHeight: col5.height
            Column {
                id: col5
                width: 384
                Repeater {
                    model: 10
                    Rectangle { width: 384; height: 104; color: "#2F3036" }
                }
                Rectangle { id: extra5; width: 384; height: 300; color: "#2F3036" }
            }
        }
        ListView {
            id: lw
            width: 384
            height: 384
            visible: false
            model: ListModel { id: lm5 }
            delegate: Rectangle {
                required property real h
                width: 384
                height: h
                color: "#2F3036"
            }
        }
        ListView {
            id: lvar
            width: 384
            height: 384
            visible: false
            cacheBuffer: 0
            model: 60
            delegate: Rectangle {
                required property int index
                width: 384
                height: 60 + ((index * 37) % 7) * 25
                color: "#2F3036"
            }
        }
        ScrollAway { id: sa5 }
    }
    // Idle with the time text back at full size
    function idleShown(sa, msg) {
        tryCompare(sa, "stage", 1, 2500, msg + ": idle")
        tryCompare(sa, "alphaValue", 1, 600, msg + ": time text back")
        compare(sa.progressValue, 0, msg + ": full size")
    }
    function staysShown(sa, msg) {
        compare(sa.stage, 1, msg + ": not a scroll, the stage stays Idle")
        compare(sa.alphaValue, 1, msg + ": the time text stays")
        compare(sa.progressValue, 0, msg + ": at full size")
    }

    function test_5_layoutFixupIsNoScroll() {
        fix5.visible = true
        // a Flickable at its end (10 x 104 + 300 + 100 margin - 384)
        fc.contentY = 1056
        sa5.flickable = fc
        idleShown(sa5, "Flickable at its end")
        // a row below collapses (a switch hides it): Flickable moves back
        // inside setContentHeight, before contentHeightChanged
        extra5.visible = false
        tryCompare(fc, "contentHeight", 1040, 500, "row hidden")
        compare(fc.contentY, 756, "content shrank: back to the new end")
        staysShown(sa5, "shrink at the end (Flickable)")
        // the bottom margin goes: back from outside the new bounds
        fc.bottomMargin = 0
        compare(fc.contentY, 656, "margin gone: back to the new end")
        staysShown(sa5, "margin change at the end")
        // the view grows taller at its end
        fc.height = 484
        compare(fc.contentY, 556, "taller view: back to the new end")
        staysShown(sa5, "view size change at the end")
        fc.height = 384
        // a fractional position (a crown glide stops anywhere) and the
        // content grows: the fixup rounds it to a whole pixel
        fc.contentY = 300.4
        compare(sa5.stage, 2, "a write is a scroll")
        idleShown(sa5, "at 300.4")
        extra5.visible = true
        tryCompare(fc, "contentHeight", 1340, 500, "row shown")
        compare(fc.contentY, 300, "content grew: the fixup rounds the position")
        staysShown(sa5, "rounding fixup (Flickable)")
        // after a fixup the next move is a scroll again
        wait(20)
        fc.contentY = 400
        compare(sa5.stage, 2, "a move after the layout pass is a scroll")
        compare(sa5.alphaValue, 0, "past 36 dp: gone")
        // at the beginning: the view follows its beginning when a top
        // margin goes (no offset change), then the margin changes again
        fc.topMargin = 40
        fc.contentY = -40
        idleShown(sa5, "at the beginning")
        fc.topMargin = 0
        compare(fc.contentY, 0, "margin gone: back to the new beginning")
        compare(sa5.offset, 0, "the offset stays")
        fc.topMargin = 20
        compare(fc.contentY, 0, "a margin added at the beginning moves nothing")
        compare(sa5.offset, 20, "the offset follows the margin")
        compare(sa5.stage, 1, "the beginning moved: not a scroll")
        fc.topMargin = 0
        compare(sa5.stage, 1, "margin gone again: not a scroll")
        sa5.flickable = null
        fc.visible = false

        // a ListView at its end: ListView moves in its layout pass
        lw.visible = true
        for (var i = 0; i < 20; i++)
            lm5.append({h: 104})
        wait(50)
        lw.positionViewAtEnd()
        compare(lw.contentY, 1696, "ListView at its end (20 x 104 - 384)")
        sa5.flickable = lw
        idleShown(sa5, "ListView at its end")
        lm5.remove(18, 2)
        tryCompare(lw, "contentY", 1488, 500, "rows removed: back to the new end")
        staysShown(sa5, "rows removed at the end (ListView)")
        lm5.setProperty(17, "h", 40)
        tryCompare(lw, "contentY", 1424, 500, "last row shrank: back to the new end")
        staysShown(sa5, "row shrank at the end (ListView)")
        wait(20)
        lw.contentY = 1000
        compare(sa5.stage, 2, "a move after the layout pass is a scroll (ListView)")
        // a fractional position and a row in view shrinks: ListView's layout
        // rounds the position before its contentHeightChanged
        lw.contentY = 600.4
        idleShown(sa5, "ListView at 600.4")
        compare(lw.contentY, 600.4, "still at 600.4")
        lm5.setProperty(5, "h", 50)
        tryCompare(lw, "contentY", 600, 500, "row shrank: the layout rounds the position")
        staysShown(sa5, "rounding fixup (ListView)")
        // scrolls that end on a bound are scrolls: forward to the end,
        // back to the beginning
        lw.positionViewAtEnd()
        verify(lw.atYEnd, "at the end")
        compare(sa5.stage, 2, "a scroll forward to the end is a scroll")
        idleShown(sa5, "ListView at its end again")
        lw.positionViewAtBeginning()
        verify(lw.atYBeginning, "at the beginning")
        compare(sa5.stage, 2, "a scroll back to the beginning is a scroll")
        sa5.flickable = null
        lw.visible = false

        // a scroll step that makes a ListView add rows of other heights:
        // its content height estimate changes inside the step (before
        // contentYChanged); the step is still a scroll
        lvar.visible = true
        sa5.flickable = lvar
        idleShown(sa5, "rows of mixed heights")
        var h0 = lvar.contentHeight
        lvar.contentY = 400
        verify(lvar.contentHeight !== h0, "the estimate changed in the step: " + h0 + " -> " + lvar.contentHeight)
        compare(sa5.stage, 2, "a scroll step that adds rows is a scroll")
        compare(sa5.alphaValue, 0, "past 36 dp: gone")
        sa5.flickable = null
        lvar.visible = false
        fix5.visible = false
    }

    // ---- D60-09: RotaryInput.flashIndicator(view) ----
    Item {
        id: fix9
        width: 384
        height: 384
        visible: false
        ListView {
            id: tall
            anchors.fill: parent
            model: 20
            delegate: Rectangle { width: 384; height: 104; color: "#2F3036" }
        }
        ListView {
            id: short
            anchors.fill: parent
            model: 2
            delegate: Rectangle { width: 384; height: 104; color: "#2F3036" }
        }
        ListView {
            id: wide
            anchors.fill: parent
            orientation: ListView.Horizontal
            model: 20
            delegate: Rectangle { width: 104; height: 384; color: "#2F3036" }
        }
        ListView {
            id: hidden
            anchors.fill: parent
            visible: false
            model: 20
            delegate: Rectangle { width: 384; height: 104; color: "#2F3036" }
        }
    }
    function test_3_flashIndicator() {
        fix9.visible = true
        wait(50)
        verify(typeof RotaryInput !== "undefined", "RotaryInput is a QML singleton")
        compare(RotaryInput.flashIndicator(null), false, "no view: nothing")
        verify(tall.contentHeight > tall.height, "tall list scrolls")
        compare(RotaryInput.flashIndicator(tall), true, "a list that scrolls: shown")
        var pi = indicator()
        verify(pi !== null, "the shared indicator is on the window")
        compare(pi.flickable, tall, "points at the view")
        compare(pi.shown, true, "shown")
        wait(600)
        verify(pi.opacity > 0.97, "faded in on the 1.0/400 spring: " + pi.opacity)
        wait(1100)
        compare(pi.shown, true, "still shown 1.7 s after")
        tryCompare(pi, "shown", false, 800, "hidden 2 s after the flash (E48)")
        tryCompare(pi, "opacity", 0, 1500, "faded out")

        compare(RotaryInput.flashIndicator(short), false, "a list that fits: nothing")
        compare(RotaryInput.flashIndicator(wide), false, "a horizontal list: nothing")
        compare(RotaryInput.flashIndicator(hidden), false, "a hidden list: nothing")
        compare(pi.flickable, tall, "the indicator stays where it was")
        compare(pi.shown, false, "and stays hidden")
        fix9.visible = false
    }

    // the flash on an application's list also hands it to the time text,
    // as a new screen (stage New, then Idle 2 s later)
    function test_4_flashHandsViewToTimeText() {
        var app = createTemporaryObject(appPage, tc)
        var lv = app.list
        var sa = childWith(app, "idleDelay")
        wait(100)
        compare(RotaryInput.flashIndicator(lv), true, "shown")
        compare(sa.flickable, lv, "the time text follows the flashed list")
        compare(sa.stage, 0, "a screen that opens is New")
        compare(sa.alpha, 1, "time text shown")
        tryCompare(sa, "stage", 1, 2500, "Idle 2 s later")
    }
}
