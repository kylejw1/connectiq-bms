import Toybox.Lang;
import Toybox.BluetoothLowEnergy;

// Base class for vendor-specific BMS protocol drivers.
// BleManager owns the transport; the driver describes UUIDs, what to ask for,
// and how to interpret what comes back.
//
// Subclasses must override:
//   serviceUuid / rxUuid / txUuid     — the BLE characteristics to talk to
//   defaultNameHints                  — substrings used to match the device by name
//   pollRequests                      — ordered list of write payloads to cycle through
//   expectedFrameLen                  — given the bytes received so far, return total
//                                       expected length, or -1 if still indeterminate
//   parseFrame                        — fill a BmsReading from a complete frame;
//                                       return true if anything was successfully parsed
class BmsDriver {
    function initialize() {}

    function id() as String {
        return "base";
    }

    function serviceUuid() as String {
        return "";
    }

    function rxUuid() as String {
        return "";
    }

    function txUuid() as String {
        return "";
    }

    function defaultNameHints() as Array {
        return [];
    }

    function pollRequests() as Array {
        return [];
    }

    function writeType() as Number {
        return BluetoothLowEnergy.WRITE_TYPE_WITH_RESPONSE;
    }

    function expectedFrameLen(buf as ByteArray) as Number {
        return -1;
    }

    function isFrameStartByte(b as Number) as Boolean {
        return true;
    }

    function parseFrame(buf as ByteArray, reading as BmsReading) as Boolean {
        return false;
    }
}
