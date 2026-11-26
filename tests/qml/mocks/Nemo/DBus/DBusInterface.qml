// Test double: Nemo.DBus' DBusInterface. Each call goes to VoiceTest's
// Backend, which records it and answers; Backend.setCallState() calls the
// object's rcCallStateChanged when signalsEnabled.
import QtQuick
import VoiceTest

QtObject {
    id: obj
    property int bus
    property string service
    property string path
    property string iface
    property bool signalsEnabled: false

    function typedCall(method, args, callback, errorCallback) {
        var plain = []
        if (args)
            for (var i = 0; i < args.length; i++)
                plain.push(args[i] !== null && typeof args[i] === "object" && args[i].hasOwnProperty("value") ? args[i].value : args[i])
        Backend.dbus(obj, method, plain, callback, errorCallback)
        return true
    }
    function call(method, args, callback, errorCallback) {
        return typedCall(method, args, callback, errorCallback)
    }
    Component.onCompleted: Backend.register(obj)
    Component.onDestruction: Backend.unregister(obj)
}
