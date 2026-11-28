// Copyright (C) 2026 eos
// SPDX-License-Identifier: BSD-3-Clause
//
// R6 K-08: the crown on the time, date and number pickers (Picker.qml, RotaryInput's rotarySnapSpeed;
// stock Material 3 Picker: HighResSnapRotaryScrollableBehavior, M3S/PickerKt.java:257-322). Under the
// image's crown (crown-fast, 24 counts per detent from its dconf database) a picker column snaps as stock's:
// one option per detent turned slowly, at most two options per crown event (the speed part is the host test
// tests/crownspeed SnapSpeed). A snapping ListView without the property still steps one item per detent.
// One wheel event per gesture (350 ms apart), so no speed builds up.
import QtQuick
import QtTest
import org.asteroid.controls

TestCase {
    id: tc
    name: "R6K08"
    when: windowShown
    visible: true
    width: 384
    height: 384

    property var made: []
    function make(c) {
        var o = c.createObject(tc)
        made.push(o)
        return o
    }
    function cleanup() {
        for (var i = 0; i < made.length; i++)
            made[i].destroy()
        made = []
        wait(350)
    }
    // n counts forward (towards the end; negative: back), one wheel event in the middle of the window
    function crown(n) {
        mouseWheel(tc, 192, 192, 0, -120 * n)
    }
    function settle() {
        wait(350)
    }

    Component {
        id: pickerComp
        Picker {
            width: 384
            height: 384
            count: 60
            selectedOption: 30
        }
    }
    // the same column without the opt-in: a plain snapping list, one item per detent
    Component {
        id: plainComp
        ListView {
            width: 384
            height: 384
            model: 60
            spacing: 8
            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: 156
            preferredHighlightEnd: 228
            snapMode: ListView.SnapToItem
            delegate: Item { width: 384; height: 72 }
        }
    }

    function test_1_picker_opts_in() {
        var p = make(pickerComp)
        wait(50)
        compare(p.view.rotarySnapSpeed, true, "the column snaps at stock's crown speed")
    }

    function test_2_one_option_per_detent_slowly() {
        var p = make(pickerComp)
        wait(50)
        compare(p.selectedOption, 30)
        crown(24)
        settle()
        compare(p.selectedOption, 31, "a detent: one option")
        crown(12)
        settle()
        compare(p.selectedOption, 31, "half a detent, a new gesture: none (stock drops it)")
        crown(-24)
        settle()
        compare(p.selectedOption, 30, "a detent back: one option back")
    }

    function test_3_two_options_an_event_at_most() {
        var p = make(pickerComp)
        wait(50)
        crown(72)
        settle()
        compare(p.selectedOption, 32, "three detents in one event: two options (stock's cap), not three")
        crown(-72)
        settle()
        compare(p.selectedOption, 30, "and two back")
    }

    function test_4_plain_list_unchanged() {
        var v = make(plainComp)
        wait(50)
        var start = v.currentIndex
        crown(72)
        settle()
        compare(v.currentIndex, start + 3, "without the opt-in: one item per detent, three detents three items")
    }
}
