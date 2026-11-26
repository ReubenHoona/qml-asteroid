import QtQuick
import QtTest
import org.asteroid.controls

// W1-qa-dialogs: Dialog, AlertDialog, Confirmation (success, failure, open
// on phone), Toast, StatusPage. 384 x 384, 2 px per dp. Numbers from the
// gaps dialogs-pickers-feedback-01..05, 07, 08, 10, 11, 21, 23, 24.
// WO-61-Q4 copy: test_01-03, 10 and 15 expect the Wear OS 6 dialog (N61-11
// two round buttons, N61-12 fade and rise, no zoom, behind not scaled).
TestCase {
    id: tc
    name: "Dialogs"
    when: windowShown
    visible: true
    width: 384
    height: 384

    function near(a, b, tol, msg) {
        verify(Math.abs(a - b) <= tol, msg + ": " + a + " != " + b + " (tol " + tol + ")")
    }
    function sameColor(a, b, msg) {
        var A = Qt.color(a), B = Qt.color(b)
        verify(Math.abs(A.r - B.r) < 0.004 && Math.abs(A.g - B.g) < 0.004 && Math.abs(A.b - B.b) < 0.004
               && Math.abs(A.a - B.a) < 0.004, msg + ": " + A + " != " + B + " (a " + A.a + " / " + B.a + ")")
    }
    function settle(d) {
        tryVerify(function() { return !d.active }, 3000, "closed")
    }
    function cleanup() {
        mouseRelease(tc, 1, 1)
        for (var i = 0; i < closers.length; i++)
            closers[i]()
    }
    property var closers: [
        function() { dlg.close(); behindPage.scale = 1 },
        function() { alert.close() },
        function() { conf.close() },
        function() { toast.hide() }
    ]
    function sceneRect(item) {
        var p = item.mapToItem(tc, 0, 0)
        return { x: p.x, y: p.y, w: item.width, h: item.height }
    }

    Rectangle {
        id: behindPage
        anchors.fill: parent
        color: "#202020"
    }

    // ---- Dialog (gap 01) ----
    Dialog {
        id: dlg
        behind: behindPage
        Rectangle { id: dlgBox; anchors.centerIn: parent; width: 100; height: 100; color: "red" }
    }
    SignalSpy { id: dlgClosed; target: dlg; signalName: "closed" }
    SignalSpy { id: dlgDismiss; target: dlg; signalName: "dismissRequested" }

    function test_01_dialogNumbers() {
        compare(dlg.enterRise, 0.10, "content enters from +10 % of the height (M15)")
        compare(dlg.exitRise, -0.05, "and leaves to -5 %")
        compare(dlg.enterDuration, 200, "show 200 ms")
        compare(dlg.exitDuration, 150, "hide 150 ms")
        compare(dlg.contentScale, 1, "no zoom")
        verify(!dlg.visible, "hidden at rest")
        verify(!dlg.holdingDisplay, "a plain dialog never holds the display")
    }

    function test_02_dialogOpenClose() {
        dlgClosed.clear()
        dlg.open()
        verify(dlg.visible && dlg.shown, "shown")
        verify(dlg.contentOffset > 0, "starts lower: " + dlg.contentOffset)
        verify(dlg.alpha < 1.0, "starts transparent: " + dlg.alpha)
        tryVerify(function() { return dlg.contentOffset === 0 && dlg.alpha === 1 }, 2000, "settled")
        compare(behindPage.scale, 1, "behind not scaled")
        sameColor(dlg.surface.children[0].color, "#000000", "opaque black background")
        compare(dlg.surface.children[0].opacity, 1, "no dim: opaque")
        dlg.close()
        tryVerify(function() { return dlg.contentOffset < 0 }, 1000, "rises on as it leaves")
        dlgClosed.wait(3000)
        verify(!dlg.visible, "hidden after the exit")
        near(dlg.contentOffset, -19.2, 0.01, "exit ends 5 % higher")
        compare(behindPage.scale, 1, "behind never scaled")
    }

    function test_03_dialogSwipe() {
        dlgClosed.clear(); dlgDismiss.clear()
        dlg.open()
        tryVerify(function() { return Math.abs(dlg.alpha - 1) < 0.003 }, 2000)
        mousePress(dlg, 60, 192)
        for (var x = 70; x <= 230; x += 10) {
            mouseMove(dlg, x, 192)
            wait(16)
        }
        verify(dlg.swipeOffset > 100, "the dialog follows the finger: " + dlg.swipeOffset)
        var p = dlg.swipeOffset / dlg.width
        verify(p > 0.2, "past a fifth of the width: " + p)
        compare(behindPage.scale, 1, "behind at its own size (Wear OS 6 does not scale it)")
        mouseMove(dlg, 300, 192)
        mouseRelease(dlg, 300, 192)
        dlgDismiss.wait(1000)
        dlgClosed.wait(3000)
        verify(!dlg.visible, "swiped away")
    }

    // ---- AlertDialog (gaps 02, 03, 04, 05, 24) ----
    AlertDialog {
        id: alert
        title: "Turn on Bedtime?"
        text: "Notifications are silenced"
    }
    SignalSpy { id: alertConfirmed; target: alert; signalName: "confirmed" }
    SignalSpy { id: alertDismissed; target: alert; signalName: "dismissed" }

    function test_10_alertLayout() {
        alert.buttons = "confirmDismiss"; alert.iconName = ""; alert.text = "Notifications are silenced"
        alert.open()
        tryVerify(function() { return alert.alpha === 1 && alert.contentOffset === 0 }, 2000)
        verify(alert.twoButtons, "the Wear OS 6 two-button confirmation")
        compare(alert.topPadding, 47, "top 12.48 %")
        compare(alert.sidePadding, 20, "sides: ceil(5.2 % of 384 px)")
        compare(alert.bottomPadding, 23, "bottom 6.24 %")
        var t = alert.titleLabel, x = alert.textLabel
        compare(t.font.pixelSize, 32, "title titleMedium 16 sp")
        compare(t.maximumLineCount, 3, "title at most 3 lines")
        compare(t.elide, Text.ElideRight, "title ellipsis")
        compare(t.horizontalAlignment, Text.AlignHCenter, "title centred")
        near(sceneRect(t).x, 52, 0.5, "title 16 dp inside the guidelines")
        near(sceneRect(t).w, 280, 0.5, "title width")
        sameColor(t.color, "#e8e7ee", "title onSurface")
        compare(x.font.pixelSize, 28, "text bodyMedium 14 sp")
        sameColor(x.color, "#e8e7ee", "text onSurface")
        compare(x.horizontalAlignment, Text.AlignHCenter, "text centred")
        near(sceneRect(x).x, 20 + 0.0416 * 384, 0.5, "text 4.16 % inside the 20 px side")
        near(sceneRect(x).y - (sceneRect(t).y + t.height), 24, 0.5, "12 dp between title and text")
        var d = alert.dismissButton, c = alert.confirmButton
        compare(d.width, 104, "dismiss 52 dp"); compare(d.height, 104, "dismiss round")
        compare(d.children[0].radius, 52, "dismiss a circle")
        sameColor(d.children[0].color, "#2f3036", "dismiss surfaceContainer")
        compare(d.children[1].width, 48, "close icon 24 dp")
        compare(d.children[1].strokes.length, 2, "close drawn")
        sameColor(d.children[1].color, "#e8e7ee", "close icon onSurface")
        compare(c.width, 104, "confirm 52 dp"); compare(c.height, 104, "confirm round")
        compare(c.children[0].rotation, 0, "confirm not turned")
        compare(c.children[0].radius, 52, "confirm a circle")
        sameColor(c.children[0].color, "#dbe2f9", "confirm primary")
        compare(c.children[1].width, 48, "check 24 dp")
        sameColor(c.children[1].color, "#383f51", "check onPrimary")
        near(sceneRect(d).x, 76, 0.5, "dismiss x 76"); near(sceneRect(c).x, 204, 0.5, "confirm x 204")
        near(sceneRect(c).x - (sceneRect(d).x + 104), 24, 0.5, "12 dp between the buttons")
        near(sceneRect(d).y, 257, 0.5, "buttons at y 257"); near(sceneRect(c).y, 257, 0.5, "both")
        verify(!alert.scrolling, "fits: fixed layout")
        verify(!alert.flickable.interactive, "fixed layout does not scroll")
        verify(alert.flickable.topMargin > 47, "short content centred: " + alert.flickable.topMargin)
        verify(!alert.holdingDisplay, "alert dialogs never hold the display")
        for (var j = 0; j < alert.children.length; j++) if (alert.children[j].sourceComponent !== undefined && alert.children[j].item !== undefined) verify(alert.children[j].item === null, "no DisplayBlanking in an alert dialog")
        compare(c.Accessible.name, "Confirm", "confirm accessible name")
        compare(d.Accessible.name, "Dismiss", "dismiss accessible name")
        compare(c.Accessible.role, Accessible.Button, "confirm role")
        compare(d.Accessible.role, Accessible.Button, "dismiss role")
    }

    function test_11_alertButtons() {
        alert.buttons = "confirmDismiss"
        alertConfirmed.clear(); alertDismissed.clear()
        alert.open()
        tryVerify(function() { return alert.alpha === 1 && alert.contentOffset === 0 }, 2000)
        mouseClick(alert.confirmButton, 63, 54)
        compare(alertConfirmed.count, 1, "confirm")
        settle(alert)
        alert.open()
        tryVerify(function() { return alert.alpha === 1 && alert.contentOffset === 0 }, 2000)
        mouseClick(alert.dismissButton, 60, 60)
        compare(alertDismissed.count, 1, "dismiss")
        settle(alert)
    }

    // a tap while the dialog leaves is not an answer: X, then a quick tap where the
    // check is (during the 150 ms exit) must not confirm; a double tap on the check
    // confirms once
    function test_11b_alertNoAnswerWhileLeaving() {
        alert.buttons = "confirmDismiss"
        alertConfirmed.clear(); alertDismissed.clear()
        alert.open()
        tryVerify(function() { return alert.alpha === 1 && alert.contentOffset === 0 }, 2000)
        mouseClick(alert.dismissButton, 60, 60)
        verify(alert.active, "still leaving")
        mouseClick(alert.confirmButton, 63, 54)
        compare(alertDismissed.count, 1, "dismissed once")
        compare(alertConfirmed.count, 0, "the tap during the exit did not confirm")
        settle(alert)
        alert.open()
        tryVerify(function() { return alert.alpha === 1 && alert.contentOffset === 0 }, 2000)
        mouseClick(alert.confirmButton, 63, 54)
        mouseClick(alert.confirmButton, 63, 54)
        compare(alertConfirmed.count, 1, "a double tap confirms once")
        settle(alert)
    }

    function test_12_alertEdgeButton() {
        alert.buttons = "edge"
        alert.open()
        tryVerify(function() { return alert.alpha === 1 && alert.contentOffset === 0 }, 2000)
        var e = alert.edgeButton
        verify(e.visible, "edge button shown")
        compare(e.preferredHeight, 140, "70 dp edge button")
        tryCompare(e, "height", 140, 2000, "in full")
        near(sceneRect(e).y + e.height, 384 - Theme.size.edgeButtonBottomGap, 0.5, "hugging the bottom edge")
        sameColor(e.containerColor, "#dbe2f9", "primary")
        compare(e.children[e.children.length - 1].width, 56, "28 dp check")
        verify(!alert.dismissButton.parent.parent.visible, "no cross")
        compare(alert.edgeGap, 8, "4 dp above it with a text")
        compare(alert.bottomPadding, 140 + Theme.size.edgeButtonBottomGap + 8, "content ends above the edge button")
        var saved = alert.text
        alert.text = ""
        compare(alert.edgeGap, 32, "16 dp with only a title")
        alert.text = saved
        compare(e.Accessible.name, "Confirm", "edge button named Confirm")
        alert.close(); settle(alert)
        alert.buttons = "none"
        near(alert.bottomPadding, 0.3646 * 384, 0.01, "no edge button: 36.46 % of the height")
        alert.buttons = "confirmDismiss"
    }

    function test_13_alertIcon() {
        alert.iconName = "ios-moon"
        compare(alert.topPadding, 39, "two buttons with an icon: 10.4 % (wear_alertdialog_top_padding_icon_fraction)")
        compare(alert.iconSize, 64, "icon 32 dp")
        alert.iconName = ""
    }

    AlertDialog {
        id: rowsAlert
        title: "Bedtime mode"
        text: "Turn it on?"
        CheckboxButton { id: dontShow; width: parent ? parent.width : 300; text: "Don't show again" }
    }
    function test_14_alertRows() {
        rowsAlert.open()
        tryVerify(function() { return rowsAlert.alpha === 1 && rowsAlert.contentOffset === 0 }, 2000)
        verify(dontShow.visible, "a content row between the text and the buttons")
        var tr = sceneRect(rowsAlert.textLabel), r = sceneRect(dontShow), b = sceneRect(rowsAlert.dismissButton.parent.parent)
        verify(r.y > tr.y + tr.h, "row under the text")
        verify(b.y > r.y + r.h, "buttons under the row")
        near(r.w, 384 - 40, 0.5, "full width row inside the 20 px sides")
        rowsAlert.close(); settle(rowsAlert)
    }

    function test_15_alertLong() {
        var long = ""
        for (var i = 0; i < 40; i++) long += "Wi-Fi uses more battery while it looks for networks. "
        alert.text = long
        alert.open()
        tryVerify(function() { return alert.alpha === 1 && alert.contentOffset === 0 }, 2000)
        verify(alert.scrolling, "long content scrolls")
        verify(alert.flickable.interactive, "the list can be dragged")
        compare(alert.flickable.topMargin, 47, "starts at item 0 under the top padding")
        compare(alert.flickable.contentY, -47, "at the start")
        // the title row at the top edge is not scaled at the start; rows
        // near the bottom edge shrink and fade (EdgeEffect)
        var textRow = alert.textLabel.parent
        verify(textRow.opacity <= 1, "text row alpha from the edge effect")
        alert.flickable.contentY = alert.flickable.contentHeight - 384 + 39
        wait(50)
        var titleInner = alert.titleLabel.parent
        verify(titleInner.opacity < 1, "the title fades at the top edge once scrolled: " + titleInner.opacity)
        verify(titleInner.transform[0].xScale < 1, "and shrinks: " + titleInner.transform[0].xScale)
        alert.close(); settle(alert)
        alert.text = "Notifications are silenced"
    }

    // ---- Confirmation (gaps 07, 08, 10, 23) ----
    Confirmation { id: conf }
    SignalSpy { id: confFinished; target: conf; signalName: "finished" }

    function test_20_successLook() {
        compare(conf.defaultDuration, 4000, "4 s by default")
        compare(conf.duration, 4000, "duration 4 s")
        conf.show("Sent")
        compare(conf.type, "success")
        verify(conf.holdingDisplay, "screen held on while a confirmation shows")
        var bl = conf.children[0]
        for (var j = 0; j < conf.children.length; j++) if (conf.children[j].item !== undefined && conf.children[j].active !== undefined && conf.children[j].sourceComponent !== undefined) bl = conf.children[j]
        verify(bl.item !== null && bl.item.preventBlanking === true, "DisplayBlanking.preventBlanking set")
        var k = conf.container
        compare(k.rotation, 45, "pill turned 45 degrees")
        near(k.height, 0.537 * 384, 0.01, "53.7 % wide pill")
        sameColor(k.color, "#383f51", "onPrimary container")
        near(k.width, 0.537 * 384, 0.5, "starts at 206 px long")
        tryVerify(function() { return k.width > 0.6 * 384 }, 1500, "grows")
        var peak = 0
        for (var i = 0; i < 40; i++) { peak = Math.max(peak, k.width); wait(10) }
        tryVerify(function() { return Math.abs(k.width - 0.648 * 384) < 0.5 }, 2000, "settles at 64.8 %")
        verify(peak > 0.648 * 384 + 1, "under-damped (0.55): it overshoots, peak " + peak)
        var g = conf.glyph
        compare(g.glyph, "check")
        compare(g.strokes.length, 1, "one stroke")
        compare(g.width, 104, "52 dp check")
        near(g.strokeWidth, 7, 0.01, "7 px stroke")
        sameColor(g.color, "#dbe2f9", "check in primary")
        tryCompare(g, "progress", 1, 2000, "check drawn")
        var t = conf.curvedText
        compare(t.pixelSize, 36, "arcLarge 18 sp")
        compare(t._role.weight, 599, "weight 599")
        compare(t.maxSweep, 120, "at most 120 degrees")
        compare(t.edgeMargin, 4, "4 px from the edge")
        verify(t.fits && t.visible, "short text curves")
        verify(t.sweep > 0 && t.sweep <= 120, "sweep " + t.sweep)
        tryCompare(t, "opacity", 1, 2000, "text fades in")
        // a tap does nothing
        mouseClick(conf, 192, 192)
        wait(50)
        verify(conf.shown, "a tap does not close it")
    }

    function test_21_successDuration() {
        confFinished.clear()
        var t0 = Date.now()
        conf.show("Saved")
        confFinished.wait(8000)
        var dt = Date.now() - t0
        verify(dt >= 4000, "stays at least 4000 ms: " + dt)
        verify(dt < 6500, "then goes: " + dt)
        verify(!conf.holdingDisplay, "display hold released")
        var bl2 = null
        for (var j = 0; j < conf.children.length; j++) if (conf.children[j].sourceComponent !== undefined && conf.children[j].item !== undefined) bl2 = conf.children[j]
        verify(bl2 && bl2.item && bl2.item.preventBlanking === false, "DisplayBlanking.preventBlanking cleared")
        verify(!conf.visible, "hidden")
    }

    function test_22_successSwipe() {
        confFinished.clear()
        conf.show("Sent")
        tryVerify(function() { return Math.abs(conf.alpha - 1) < 0.003 }, 2000)
        mousePress(conf, 60, 192)
        for (var x = 70; x <= 300; x += 10) { mouseMove(conf, x, 192); wait(16) }
        mouseRelease(conf, 300, 192)
        confFinished.wait(3000)
        verify(!conf.visible, "a swipe closes it early")
    }

    function test_23_failure() {
        var minX = 0
        var watch = function() { minX = Math.min(minX, conf._shakeX) }
        conf._shakeXChanged.connect(watch)
        conf.show("Not sent", false)
        compare(conf.type, "failure")
        verify(!conf.success)
        var k = conf.container
        near(k.width, 0.537 * 384, 0.01, "206 px container")
        compare(k.width, k.height, "square")
        compare(k.rotation, 0, "not turned")
        sameColor(k.color, Qt.rgba(0x3c / 255, 0x05 / 255, 0x07 / 255, 0.8), "onError at 80 %")
        tryVerify(function() { return Math.abs(k.radius - 72) < 0.01 }, 1500, "circle -> 36 dp corners")
        var g = conf.glyph
        compare(g.glyph, "failure")
        compare(g.strokes.length, 2, "two strokes")
        compare(g.width, 104)
        sameColor(g.color, Theme.color.errorDim, "glyph errorDim")
        tryCompare(g, "progress2", 1, 2000, "second stroke drawn")
        tryVerify(function() { return minX <= -14.9 }, 2000, "shakes to -15 px")
        tryVerify(function() { return Math.abs(conf._shakeX) < 0.11 }, 2000, "and back to 0")
        conf._shakeXChanged.disconnect(watch)
        verify(conf.holdingDisplay, "held on")
        compare(conf.curvedText.maxSweep, 120)
    }

    function test_24_openOnPhone() {
        conf.close(); settle(conf)
        conf.showOpenOnPhone()
        var t0 = Date.now()
        compare(conf.type, "openOnPhone")
        compare(conf.text, "Check your phone", "default text")
        tryVerify(function() { return conf.alpha === 1 && conf.contentOffset === 0 }, 2000, "entered")
        var k = conf.container, r = conf.ring
        var box = 0.648 * 384
        // stock Lambda7: the disc is the 249 px box padded 10 dp x f
        near(k.width, box - 40, 0.01, "209 px disc at the start")
        compare(k.height, k.width)
        compare(k.radius, k.height / 2, "a circle")
        near(sceneRect(k).x + k.width / 2, 192, 0.01, "disc centred x")
        near(sceneRect(k).y, 0.157 * 384 + 20, 0.5, "disc centred in the box 15.7 % from the top")
        sameColor(k.color, "#404759", "primaryContainer")
        // the ring on the full box: stroke 5 dp x f at (minDim - stroke) / 2
        near(r.width, box, 0.01, "ring box 249 px")
        near(sceneRect(r).y, 0.157 * 384, 0.5, "ring box 15.7 % from the top")
        near(sceneRect(r).x, (384 - box) / 2, 0.01, "ring box centred")
        compare(r.stroke, 10, "ring 5 dp wide")
        near(r.r, (box - 10) / 2, 0.001, "radius (minDim - stroke) / 2")
        near(r.r - r.stroke / 2 - k.width / 2, 10, 0.01, "10 px black gap between ring and disc")
        verify(r.visible)
        compare(conf.endSpatialSpring.stiffness, 500, "end: defaultSpatial stiffness")
        compare(conf.endSpatialSpring.dampingRatio, 1, "end: defaultSpatial damping")
        compare(conf.endEffectsSpring.stiffness, 500, "end: defaultEffects stiffness")
        compare(conf.endEffectsSpring.dampingRatio, 1, "end: defaultEffects damping")
        compare(conf.glyph.glyph, "phone")
        compare(conf.glyph.strokes.length, 2, "phone and speaker")
        compare(conf.glyph.width, 104, "52 dp phone")
        sameColor(conf.glyph.color, "#d9e0f7", "onPrimaryContainer phone")
        compare(conf.curvedText.maxSweep, 200, "at most 200 degrees")
        verify(conf.holdingDisplay, "held on")
        wait(1500)
        compare(conf._f, 1, "padding on until duration - 500 ms")
        var p = r.progress
        verify(p > 0.2 && p < 0.7, "fills linearly over 3500 ms: " + p + " at " + (Date.now() - t0) + " ms")
        tryVerify(function() { return conf._ring >= 1 }, 4000, "full ring")
        var tFull = Date.now() - t0
        verify(tFull >= 3400, "full after duration - 500 ms: " + tFull)
        tryCompare(conf, "_end", 1, 1500, "last 500 ms")
        tryCompare(conf, "_f", 0, 1500, "padding and stroke to 0")
        near(k.width, box, 0.01, "disc grows to the 249 px box")
        near(sceneRect(k).y, 0.157 * 384, 0.5, "box top")
        compare(r.stroke, 0, "ring stroke 0")
        sameColor(k.color, "#d9e0f7", "colours swapped: container")
        sameColor(conf.glyph.color, "#404759", "colours swapped: icon")
        compare(r.opacity, 0, "ring gone")
        confFinished.clear()
        confFinished.wait(3000)
    }

    function test_25_linear() {
        conf.show("Your reply was sent to everyone in this conversation just now", true)
        verify(conf.linear, "long text: the linear layout")
        tryVerify(function() { return conf.alpha === 1 && conf.contentOffset === 0 }, 2000, "entered")
        var k = conf.container
        compare(k.width, 160, "80 dp container")
        compare(k.rotation, 0)
        tryVerify(function() { return Math.abs(k.radius - 52) < 0.01 }, 1500, "morphs to 26 dp corners")
        compare(conf.glyph.width, 72, "36 dp icon")
        var l = conf.linearText
        verify(l.visible && !conf.curvedText.visible, "straight text")
        compare(l.font.pixelSize, 32, "titleMedium")
        compare(l.maximumLineCount, 3)
        near(l.x, 0.12 * 384, 0.5, "46 px sides")
        near(sceneRect(l).y - (sceneRect(k).y + k.height), 16, 0.5, "16 px gap")
        conf.close(); settle(conf)
    }

    function test_26_reduceMotion() {
        // WearSpring and Motion.duration snap with Reduce animations; the
        // timing stays (duration and display hold)
        compare(Motion.duration(267), 267 * Motion.animationScale)
    }

    // ---- Toast (gap 11) ----
    Toast { id: toast }
    function test_30_toastLook() {
        toast.show("Copied")
        verify(toast.visible)
        tryVerify(function() { return toast.bubble.scale === 1 }, 2000, "in")
        var b = toast.bubble, l = toast.label
        near(sceneRect(b).x + b.width / 2, 192, 0.5, "centred x")
        near(sceneRect(b).y + b.height / 2, 192, 0.5, "centred y")
        compare(b.radius, 48, "24 dp corners")
        sameColor(b.color, "#e6ffffff", "#E6FFFFFF")
        compare(l.font.pixelSize, 26, "13 sp")
        sameColor(l.color, "#000000", "black text")
        near(l.font.letterSpacing, 0.023 * 26, 1 / 64, "0.023 em (26.6 fixed point)")
        compare(l.maximumLineCount, 2)
        compare(l.elide, Text.ElideRight)
        compare(l.x, 32, "16 dp start padding")
        near(b.width - l.x - l.width, 32, 0.5, "16 dp end padding")
        near(b.height, l.height + 48, 0.5, "12 dp above and below the text")
        verify(!toast.icon.visible, "no icon")
        compare(toast.duration, 2000, "short 2000 ms")
        toast.hide()
        tryVerify(function() { return !toast.active }, 2000)
        var long = ""
        for (var i = 0; i < 30; i++) long += "word "
        toast.show(long, true, "")
        compare(toast.duration, 3500, "long 3500 ms")
        near(b.width, 384 - 64, 0.5, "16 dp from the screen sides at most")
        verify(l.lineCount <= 2, "2 lines at most")
        toast.hide()
        tryVerify(function() { return !toast.active }, 2000)
    }

    function test_31_toastIcon() {
        toast.show("Mode on", false, "file:///usr/share/icons/asteroid/ios-moon.svg")
        verify(toast.icon.visible, "icon shown")
        compare(toast.icon.width, 48, "24 dp icon")
        compare(toast.icon.x, 32, "at the start")
        compare(toast.label.x, 32 + 48 + 20, "10 dp gap to the text")
        verify(toast.bubble.height >= 48 + 40, "10 dp above and below the icon")
        toast.hide()
        tryVerify(function() { return !toast.active }, 2000)
    }

    function test_32_toastTiming() {
        var t0 = Date.now()
        toast.show("Saved")
        near(toast.bubble.scale, 0.9, 0.05, "enters from 0.9")
        tryVerify(function() { return toast.bubble.opacity === 1 }, 1000, "alpha in")
        var tAlpha = Date.now() - t0
        tryVerify(function() { return toast.bubble.scale === 1 && toast.label.opacity === 1 }, 1500, "scale and text in")
        var tIn = Date.now() - t0
        verify(tAlpha < tIn, "alpha (66 ms) before the scale (333 ms): " + tAlpha + " / " + tIn)
        verify(tIn >= 330, "scale in 333 ms: " + tIn)
        tryVerify(function() { return toast.bubble.scale < 1 }, 3000, "leaves")
        var tOut = Date.now() - t0
        verify(tOut >= 2000, "after 2000 ms: " + tOut)
        verify(toast.bubble.opacity === 1, "alpha waits 150 ms")
        tryVerify(function() { return !toast.active }, 1500, "gone")
        var tGone = Date.now() - t0
        verify(tGone - tOut >= 240, "out 250 ms: " + (tGone - tOut))
        near(toast.bubble.scale, 0.9, 0.001, "leaves to 0.9")
        verify(!toast.enabled, "takes no touches")
    }

    // ---- StatusPage (gap 21) ----
    Item {
        id: statusHost
        anchors.fill: parent
        visible: false
        StatusPage {
            id: status
            icon: "ios-cloud-outline"
            text: "Can't download weather data."
            actionText: "Retry"
        }
    }
    SignalSpy { id: statusAction; target: status; signalName: "actionClicked" }
    function test_40_statusPage() {
        statusHost.visible = true
        var ic = status.iconItem, l = status.label, a = status.actionButton
        compare(ic.width, 56, "28 dp icon")
        sameColor(ic.color, "#cecdd4", "onSurfaceVariant icon")
        compare(l.font.pixelSize, 28, "bodyMedium")
        sameColor(l.color, "#cecdd4", "same muted colour")
        compare(l.horizontalAlignment, Text.AlignHCenter)
        verify(l.width <= 280, "at most 140 dp wide")
        near(sceneRect(l).y - (sceneRect(ic).y + ic.height), 12, 0.5, "6 dp under the icon")
        verify(a.visible, "action button")
        compare(a.variant, "tonal", "filled tonal")
        near(sceneRect(a).y - (sceneRect(l).y + l.height), 16, 0.5, "8 dp under the text")
        var top = sceneRect(ic).y, bottom = sceneRect(a).y + a.height
        near((top + bottom) / 2, 192, 1, "group centred")
        mouseClick(a, a.width / 2, a.height / 2)
        compare(statusAction.count, 1, "action")
        status.actionText = ""
        verify(!a.visible, "no button without an action")
        statusHost.visible = false
    }
}
