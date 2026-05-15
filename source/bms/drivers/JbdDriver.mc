import Toybox.Lang;
import Toybox.BluetoothLowEnergy;
import Toybox.System;

// JBD / Xiaoxiang BMS protocol driver.
// Service ff00, RX (notify) ff01, TX (write) ff02.
// Frame: DD <cmd> <status> <dataLen> <data...> <chkHi> <chkLo> 77
//
// We alternate two requests:
//   0x03 — basic info (V, A, Ah, SOC, temp, ...)
//   0x04 — cell voltages (per-cell mV)
class JbdDriver extends BmsDriver {

    const BASIC_INFO_REQUEST = [0xDD, 0xA5, 0x03, 0x00, 0xFF, 0xFD, 0x77]b;
    const CELL_INFO_REQUEST  = [0xDD, 0xA5, 0x04, 0x00, 0xFF, 0xFC, 0x77]b;

    function initialize() {
        BmsDriver.initialize();
    }

    function id() as String { return "jbd"; }

    function serviceUuid() as String { return "0000ff00-0000-1000-8000-00805f9b34fb"; }
    function rxUuid() as String      { return "0000ff01-0000-1000-8000-00805f9b34fb"; }
    function txUuid() as String      { return "0000ff02-0000-1000-8000-00805f9b34fb"; }

    function defaultNameHints() as Array {
        return ["xiaoxiang", "jbd", "sp2", "sp4"];
    }

    function pollRequests() as Array {
        return [BASIC_INFO_REQUEST, CELL_INFO_REQUEST];
    }

    function isFrameStartByte(b as Number) as Boolean {
        return b == 0xDD;
    }

    function expectedFrameLen(buf as ByteArray) as Number {
        if (buf.size() < 4) { return -1; }
        return buf[3] + 7;
    }

    function parseFrame(buf as ByteArray, reading as BmsReading) as Boolean {
        if (buf.size() < 7 || buf[0] != 0xDD) { return false; }
        if (buf[2] != 0x00) { return false; }  // status != OK
        var cmd = buf[1];
        if (cmd == 0x03) {
            return _parseBasicInfo(buf, reading);
        } else if (cmd == 0x04) {
            return _parseCellInfo(buf, reading);
        }
        return false;
    }

    hidden function _parseBasicInfo(buf as ByteArray, r as BmsReading) as Boolean {
        if (buf.size() < 29) { return false; }

        r.voltageV = ((buf[4] << 8) | buf[5]).toFloat() / 100.0;

        var rawCur = (buf[6] << 8) | buf[7];
        if (rawCur > 0x7FFF) { rawCur = rawCur - 0x10000; }
        r.currentA = rawCur.toFloat() / 100.0;

        r.capacityAh        = ((buf[8]  << 8) | buf[9]).toFloat() / 100.0;
        r.designCapacityAh  = ((buf[10] << 8) | buf[11]).toFloat() / 100.0;
        r.cycleCount        =  (buf[12] << 8) | buf[13];
        r.protectionBits    =  (buf[20] << 8) | buf[21];
        r.socPct            =   buf[23];
        r.cellCount         =   buf[25];

        var ntcCount = buf[26];
        var tempBase = 27;
        if (ntcCount > 0 && buf.size() >= tempBase + ntcCount * 2) {
            var tMin = null;
            var tMax = null;
            for (var i = 0; i < ntcCount; i++) {
                var raw = (buf[tempBase + i*2] << 8) | buf[tempBase + i*2 + 1];
                var c   = (raw - 2731).toFloat() / 10.0;
                if (tMin == null || c < tMin) { tMin = c; }
                if (tMax == null || c > tMax) { tMax = c; }
            }
            r.tempC    = tMax;
            r.tempMinC = tMin;
        }

        r.powerW = r.voltageV * (r.currentA != null ? r.currentA.abs() : 0.0);
        r.lastUpdateMs = System.getTimer();
        return true;
    }

    hidden function _parseCellInfo(buf as ByteArray, r as BmsReading) as Boolean {
        var dataLen = buf[3];
        if (dataLen < 2 || (dataLen & 1) != 0) { return false; }
        if (buf.size() < 4 + dataLen) { return false; }
        var n = dataLen / 2;
        var minMv = null;
        var maxMv = null;
        for (var i = 0; i < n; i++) {
            var mv = (buf[4 + i*2] << 8) | buf[4 + i*2 + 1];
            if (minMv == null || mv < minMv) { minMv = mv; }
            if (maxMv == null || mv > maxMv) { maxMv = mv; }
        }
        r.cellCount   = n;
        r.cellMinV    = minMv.toFloat() / 1000.0;
        r.cellMaxV    = maxMv.toFloat() / 1000.0;
        r.cellDeltaMv = maxMv - minMv;
        r.lastUpdateMs = System.getTimer();
        return true;
    }
}
