// FP-Q1 (r2-63): no dictation in a phone call (the launcher's CallState() > 0, CR-03),
// stock's message "Cannot record audio while in a call" (Gboard audio_unavailable_error_title,
// cro.java voice key: AudioManager in call -> WearFullscreenToast with gm_filled_mic_off),
// SetInUse("mic", on) around recording (CR-04), and Icon's alpha after a dim colour.
// Needs the D-Bus double (mocks/: Nemo.DBus + VoiceTest.Backend) and the rootfs
// icons (test_7 draws one; without them the Icon finds no file):
// run-qemu: mocks icons
import QtQuick
import QtTest
import org.asteroid.controls
import VoiceTest

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
        name: "FPQ1"
        when: windowShown

        readonly property string inCall: "Cannot record audio while in a call"

        function near(a, b, tol, msg) {
            verify(Math.abs(a - b) <= tol, msg + ": " + a + " != " + b + " (tol " + tol + ")")
        }
        function init() {
            Backend.reset()
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
        function keyboard(props) {
            return Qt.createQmlObject('import QtQuick; import org.asteroid.controls; WearKeyboard { anchors.fill: parent; '
                                      + props + ' }', host)
        }

        function test_1_callStates_data() {
            return [{ tag: "none", s: 0 }, { tag: "ringing", s: 1 }, { tag: "in progress", s: 2 }]
        }
        function test_1_callStates(d) {
            Backend.callState = d.s
            var v = voice('engine: "assistant"')
            wait(50)
            compare(Backend.count("CallState"), 1, "the launcher is asked once")
            if (d.s === 0) {
                compare(Backend.count("Dictate"), 1, "dictation starts outside a call")
                verify(v.recording, "recording")
                compare(Backend.inUse().join(","), "mic=true", "the microphone claimed once")
                var c = Backend.calls.filter(function (x) { return x.method === "SetInUse" })[0]
                compare(c.service + " " + c.path + " " + c.iface, "org.asteroidos.launcher /org/asteroidos/launcher/ongoing org.asteroidos.launcher.Ongoing")
            } else {
                compare(Backend.count("Dictate"), 0, "no dictation in a call")
                compare(v.phase, "failed")
                compare(v.errorCode, "in-call")
                compare(v.shownText, tc.inCall, "stock's message")
                verify(!v.recording, "not recording")
                compare(Backend.inUse().length, 0, "nothing claimed")
            }
            v.destroy()
            wait(0)
            compare(Backend.inUse().join(","), d.s === 0 ? "mic=true,mic=false" : "", "released when the screen goes")
        }

        // the claim follows the recording: result, restart, a call that begins mid-dictation
        function test_2_aroundRecording() {
            var v = voice('engine: "assistant"')
            wait(50)
            v.engineState(7, "listening")
            compare(v.phase, "ready")
            v.enginePartial(7, "hello")
            compare(v.phase, "hearing")
            compare(Backend.inUse().join(","), "mic=true", "claimed while it listens")
            v.engineResult(7, '{"type":"dictation","text":"hello there"}')
            compare(v.phase, "done")
            verify(!v.recording)
            compare(Backend.inUse().join(","), "mic=true,mic=false", "released at the result")
            v.stepBack()
            wait(50)
            compare(Backend.count("Dictate"), 2, "restarted")
            compare(Backend.inUse().join(","), "mic=true,mic=false,mic=true", "claimed again")
            // a call rings while it records: the engine is cancelled, the screen says why
            Backend.setCallState(1)
            compare(v.callState, 1)
            compare(Backend.count("Cancel"), 1, "the engine cancelled")
            compare(v.phase, "failed")
            compare(v.errorCode, "in-call")
            compare(v.shownText, tc.inCall)
            compare(Backend.inUse().join(","), "mic=true,mic=false,mic=true,mic=false", "released")
            // the microphone tapped during the call: nothing starts
            v.micTapped()
            wait(50)
            compare(Backend.count("Dictate"), 2, "no dictation while the call lasts")
            compare(v.phase, "failed")
            // the call ends: a tap starts dictation again
            Backend.setCallState(0)
            v.micTapped()
            wait(50)
            compare(Backend.count("Dictate"), 3, "dictation after the call")
            verify(v.recording)
            v.dismiss()
            compare(Backend.inUse().join(","), "mic=true,mic=false,mic=true,mic=false,mic=true,mic=false", "released at dismiss")
        }

        // btsyncd (a voice reply): the same gate and claim
        function test_3_btsyncd() {
            Backend.callState = 2
            var v = voice('engine: "btsyncd"; mode: "reply"; notificationId: 42')
            wait(50)
            compare(Backend.count("Start"), 0, "no dictation in a call")
            compare(v.shownText, tc.inCall)
            v.destroy()
            wait(0)
            Backend.reset()
            v = voice('engine: "btsyncd"; mode: "reply"; notificationId: 42')
            wait(50)
            var s = Backend.calls.filter(function (x) { return x.method === "Start" })
            compare(s.length, 1, "Start outside a call")
            compare(s[0].args[0], 42, "for the notification")
            compare(v.phase, "ready")
            compare(Backend.inUse().join(","), "mic=true")
            v.engineFinal("on my way")
            compare(v.phase, "done")
            compare(Backend.inUse().join(","), "mic=true,mic=false")
        }

        // the engine starts only after the launcher answered (the reply comes later on a real bus)
        function test_4_asyncGate() {
            Backend.async = true
            Backend.callState = 2
            var v = voice('engine: "assistant"')
            compare(v.phase, "initializing", "waiting for the launcher")
            verify(!v.recording, "no microphone yet")
            compare(Backend.count("Dictate"), 0)
            wait(150)
            compare(v.phase, "failed", "in a call")
            compare(Backend.count("Dictate"), 0, "never started")
            compare(Backend.inUse().length, 0)
            v.destroy()
            wait(0)
            Backend.reset()
            Backend.async = true
            v = voice('engine: "assistant"')
            compare(Backend.count("Dictate"), 0)
            wait(150)
            compare(Backend.count("Dictate"), 1, "started after the answer")
            // dismissed while the answer is on its way: nothing starts
            v.destroy()
            wait(0)
            Backend.reset()
            Backend.async = true
            v = voice('engine: "assistant"')
            v.dismiss()
            wait(150)
            compare(Backend.count("Dictate"), 0, "dismissed before the answer: no dictation")
            compare(Backend.inUse().length, 0)
        }

        // no launcher (no Call object): no call known, dictation works as before; engine "none"
        function test_5_noLauncherAndNone() {
            Backend.launcherUp = false
            var v = voice('engine: "assistant"')
            wait(50)
            compare(Backend.count("Dictate"), 1, "no launcher: dictation")
            v.destroy()
            wait(0)
            Backend.reset()
            var restarts = 0
            v = voice('engine: "none"; autoStart: false')
            v.restartRequested.connect(function () { restarts++ })
            v.start()
            compare(restarts, 1, "engine none: the owner starts at once")
            compare(Backend.count("CallState"), 0, "not asked")
            compare(Backend.inUse().length, 0, "the owner claims, not the screen")
            Backend.setCallState(2)
            v.start()
            compare(restarts, 1, "in a call (from the signal): not started")
            compare(v.shownText, tc.inCall)
        }

        // the keyboard's microphone in a call: stock's full screen notice, no voice screen
        function test_6_keyboardMic() {
            Backend.callState = 2
            var kb = keyboard('')
            wait(400)   // the keyboard's 200 ms fade in
            compare(kb.callState, 2, "read from the launcher")
            verify(kb._dictationAvailable, "the assistant is installed")
            var n = findChild(kb, "keyboardNotice")
            verify(n !== null && !n.visible, "no notice yet")
            kb.showVoice()
            verify(n.visible, "the notice")
            compare(findChild(kb, "keyboardNoticeText").text, tc.inCall)
            verify(!kb._voiceOpen, "no voice screen")
            compare(Backend.count("Dictate"), 0)
            waitForRendering(n)
            grabImage(top).save("shots/fpq1-notice.png")
            var c = findChild(kb, "keyboardNoticeConfirm")
            near(c.width, 104, 0.5, "52 dp check button")
            mouseClick(c, c.width / 2, c.height / 2)
            verify(!n.visible, "the check closes it")
            kb.showVoice()
            verify(n.visible)
            mouseDrag(n, 60, 200, 200, 0)
            verify(!n.visible, "a right swipe closes it")
            kb.showVoice()
            verify(n.visible)
            wait(3700)
            verify(!n.visible, "gone by itself after 3.5 s")
            // the call ends (CallStateChanged): the microphone opens the voice screen
            Backend.setCallState(0)
            compare(kb.callState, 0)
            kb.showVoice()
            verify(kb._voiceOpen, "the voice screen")
            wait(50)
            compare(Backend.count("Dictate"), 1)
            compare(Backend.inUse().join(","), "mic=true")
            // a call begins while it records: the voice screen stops and says why
            Backend.setCallState(2)
            var vs = kb._voiceScreen
            compare(vs.phase, "failed")
            compare(vs.shownText, tc.inCall)
            compare(Backend.inUse().join(","), "mic=true,mic=false")
        }

        // Icon: a translucent (disabled) colour, then opaque again: full alpha back (QA-ICON-ALPHA)
        function lum(img, w, h) {
            var m = 0
            for (var y = 0; y < h; y++)
                for (var x = 0; x < w; x++)
                    m = Math.max(m, img.pixel(x, y).r)
            return m
        }
        function test_7_iconAlpha() {
            var ic = Qt.createQmlObject('import QtQuick; import org.asteroid.controls; Icon { width: 48; height: 48; name: "ios-mic-off"; color: "white" }', host)
            waitForRendering(ic)
            var a = lum(grabImage(ic), 48, 48)
            verify(a > 0.9, "drawn white: " + a)
            ic.color = Qt.rgba(1, 1, 1, 0.38)
            waitForRendering(ic)
            var b = lum(grabImage(ic), 48, 48)
            verify(b < 0.5, "dimmed: " + b)
            ic.color = "white"
            waitForRendering(ic)
            near(lum(grabImage(ic), 48, 48), a, 0.01, "full alpha again")
        }
    }
}
