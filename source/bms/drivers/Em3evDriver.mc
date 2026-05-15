import Toybox.Lang;
import Toybox.System;

// EM3EV BMS driver — STUB.
// EM3EV ships packs with several different BMS variants over time; many recent
// ones speak the JBD/Xiaoxiang protocol and would be served by selecting "jbd"
// with a name filter that matches your specific pack. If you hit a pack with a
// truly different protocol, fill this in. For now this exists so future support
// has a clean place to land.
class Em3evDriver extends BmsDriver {

    function initialize() {
        BmsDriver.initialize();
    }

    function id() as String { return "em3ev"; }

    function serviceUuid() as String { return ""; }
    function rxUuid() as String      { return ""; }
    function txUuid() as String      { return ""; }

    function defaultNameHints() as Array {
        return ["em3ev"];
    }

    function pollRequests() as Array { return []; }

    function expectedFrameLen(buf as ByteArray) as Number { return -1; }

    function parseFrame(buf as ByteArray, reading as BmsReading) as Boolean {
        System.println("Em3evDriver: parseFrame not implemented");
        return false;
    }
}
