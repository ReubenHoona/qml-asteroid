// Copyright (C) 2026 eos
// SPDX-License-Identifier: BSD-3-Clause
//
// R5-fu B-10: the dictation earcon. The voice screen (VoiceInput) asks ngfd for dictation_start (eos' start tone
// with the mic thud, events.d/dictation.ini) when the microphone is ready and for ui_mic (the thud) at the end, as
// Gboard plays its start tone and mic haptic (text-input-29). Only the event names are checked (Haptics.played):
// nothing is played here (no ngfd on the host).
// run-qemu: mocks
import QtQuick
import QtTest
import org.asteroid.controls
import VoiceTest

Item {
    id: top
    width: 384
    height: 384

    Item {
        id: host
        anchors.fill: parent
    }
    SignalSpy {
        id: played
        target: Haptics
        signalName: "played"
    }

    TestCase {
        id: tc
        name: "R5fu"
        when: windowShown

        function init() {
            Backend.reset()
            played.clear()
        }
        function cleanup() {
            for (var i = host.children.length - 1; i >= 0; i--)
                host.children[i].destroy()
            wait(0)
        }
        function voice(props) {
            return Qt.createQmlObject('import QtQuick; import org.asteroid.controls; VoiceInput { anchors.fill: parent; '
                                      + props + ' }', host)
        }
        function events() {
            var out = []
            for (var i = 0; i < played.count; i++)
                out.push(played.signalArguments[i][0])
            return out.join(",")
        }

        function test_b10_dictation_earcon() {
            var v = voice('engine: "assistant"')
            wait(50)
            compare(Backend.count("Dictate"), 1)
            compare(events(), "", "nothing before the microphone is ready")
            v.engineState(7, "listening")
            compare(v.phase, "ready")
            compare(events(), "dictation_start", "the start tone and the thud")
            v.enginePartial(7, "hello")
            compare(v.phase, "hearing")
            compare(events(), "dictation_start", "nothing while it hears")
            v.engineResult(7, '{"type":"dictation","text":"hello there"}')
            compare(v.phase, "done")
            compare(events(), "dictation_start,ui_mic", "the thud at the end")
            // a new utterance: the tone again when the microphone is ready
            v.stepBack()
            wait(50)
            v.engineState(7, "listening")
            compare(events(), "dictation_start,ui_mic,dictation_start")
            // no longPress thud any more (the old stand-in)
            verify(events().indexOf("ui_long_press") < 0)
        }

        function test_b10_no_tone_in_a_call() {
            Backend.callState = 2
            var v = voice('engine: "assistant"')
            wait(50)
            compare(v.phase, "failed")
            compare(events(), "", "no dictation, no tone")
        }
    }
}
