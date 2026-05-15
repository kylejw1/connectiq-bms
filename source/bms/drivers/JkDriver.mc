import Toybox.Lang;
import Toybox.System;

// JK BMS protocol driver — STUB.
// JK uses BLE service 0000ffe0 / characteristic 0000ffe1 (notify+write).
// Frame format starts with 0x4E 0x57 and includes a length and CRC.
// Reference command "device info" / "cell info":
//   AA 55 90 EB <cmd> 00 ... <crc>
// Drop-in implementation pending — currently this driver advertises no
// service so BleManager will refuse to use it (logged at startup).
class JkDriver extends BmsDriver {

    function initialize() {
        BmsDriver.initialize();
    }

    function id() as String { return "jk"; }

    function serviceUuid() as String { return ""; }
    function rxUuid() as String      { return ""; }
    function txUuid() as String      { return ""; }

    function defaultNameHints() as Array {
        return ["jk-", "jk_bms", "jkbms"];
    }

    function pollRequests() as Array { return []; }

    function expectedFrameLen(buf as ByteArray) as Number { return -1; }

    function isFrameStartByte(b as Number) as Boolean {
        return b == 0x4E;
    }

    function parseFrame(buf as ByteArray, reading as BmsReading) as Boolean {
        System.println("JkDriver: parseFrame not implemented");
        return false;
    }
}
