// Test double for the session bus of FP-Q1: the launcher's Call (CallState,
// CallStateChanged) and Ongoing (SetInUse) objects, the bus daemon's
// ListActivatableNames and the dictation engines. Every call is recorded.
pragma Singleton
import QtQuick

QtObject {
    id: be
    property int callState: 0
    // false: the launcher's objects answer with an error (no launcher)
    property bool launcherUp: true
    // true: the replies come 50 ms later (as a real bus, asynchronously)
    property bool async: false
    property var calls: []
    property var objects: []
    property var _queue: []

    function reset() {
        callState = 0
        launcherUp = true
        async = false
        calls = []
        _queue = []
    }
    function register(o) {
        var a = objects.slice()
        a.push(o)
        objects = a
    }
    function unregister(o) {
        objects = objects.filter(function (x) { return x !== o })
    }
    function count(method) {
        return calls.filter(function (c) { return c.method === method }).length
    }
    // the SetInUse calls as "kind=active"
    function inUse() {
        return calls.filter(function (c) { return c.method === "SetInUse" })
                    .map(function (c) { return c.args[0] + "=" + c.args[1] })
    }
    function _reply(iface, method) {
        if (iface === "org.asteroidos.launcher.Call")
            return launcherUp && method === "CallState" ? { "ok": true, "value": callState } : { "ok": false }
        if (iface === "org.asteroidos.launcher.Ongoing")
            return launcherUp ? { "ok": true } : { "ok": false }
        if (iface === "org.freedesktop.DBus" && method === "ListActivatableNames")
            return { "ok": true, "value": ["org.asteroidos.assistant"] }
        if (iface === "org.asteroidos.assistant" && method === "Dictate")
            return { "ok": true, "value": 7 }
        if (iface === "org.asteroidos.btsyncd.Voice" && method === "Start")
            return { "ok": true, "value": 3 }
        return { "ok": true }
    }
    function dbus(obj, method, args, callback, errorCallback) {
        calls = calls.concat([{ "service": obj.service, "path": obj.path, "iface": obj.iface,
                                "method": method, "args": args }])
        var r = _reply(obj.iface, method)
        var deliver = function () {
            if (r.ok) {
                if (typeof callback === "function")
                    callback(r.value)
            } else if (typeof errorCallback === "function") {
                errorCallback()
            }
        }
        if (async) {
            _queue.push(deliver)
            _timer.restart()
        } else {
            deliver()
        }
    }
    property Timer _timer: Timer {
        interval: 50
        onTriggered: {
            var q = be._queue
            be._queue = []
            for (var i = 0; i < q.length; i++)
                q[i]()
        }
    }
    // the launcher's CallStateChanged(i) to every Call object listening
    function setCallState(s) {
        callState = s
        var o = objects.slice()
        for (var i = 0; i < o.length; i++) {
            if (o[i].iface === "org.asteroidos.launcher.Call" && o[i].signalsEnabled
                    && typeof o[i].rcCallStateChanged === "function")
                o[i].rcCallStateChanged(s)
        }
    }
}
