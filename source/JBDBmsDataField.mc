// JBD BMS Connect IQ Data Field - PoC
// Targets: Fenix 7
// JBD BLE service: 0000ff00-0000-1000-8000-00805f9b34fb
// TX (watch -> BMS): 0000ff02-0000-1000-8000-00805f9b34fb
// RX (BMS -> watch): 0000ff01-0000-1000-8000-00805f9b34fb

import Toybox.Application;
import Toybox.WatchUi;
import Toybox.Graphics;

import Toybox.BluetoothLowEnergy;
import Toybox.Lang;
import Toybox.System;

var BASIC_INFO_REQUEST = [0xDD, 0xA5, 0x03, 0x00, 0xFF, 0xFD, 0x77]b;

// ── BMS State ─────────────────────────────────────────────────────────────────
class BmsData {
    var voltageV   = 0.0;
    var currentA   = 0.0;
    var socPct     = 0;
    var capacityAh = 0.0;
    var powerW     = 0.0;
    var tempC      = 0.0;
    var connected  = false;
    var lastUpdate = 0;
    var rawHex     = "";

    function initialize() {
    }

    function update(raw) {
        var buf = raw as Lang.ByteArray;
        if (buf.size() < 7) { return false; }
        if (buf[0] != 0xDD) { return false; }

        var dataLen = buf[3];

        voltageV   = ((buf[4] << 8) | buf[5]).toFloat() / 100.0;
        var rawCur = (buf[6] << 8) | buf[7];
        if (rawCur > 0x7FFF) { rawCur = rawCur - 0x10000; }
        currentA   = rawCur.toFloat() / 100.0;
        capacityAh = ((buf[8] << 8) | buf[9]).toFloat() / 100.0;
        socPct     = buf[23];
        var rawTmp = (buf[27] << 8) | buf[28];
        tempC      = (rawTmp - 2731).toFloat() / 10.0;
        powerW     = voltageV * currentA.abs();
        lastUpdate = System.getTimer();
        return true;
    }

    function verifyChecksum(buf) {
        var dataLen = buf[3];
        var sum = 0;
        for (var i = 4; i < 4 + dataLen; i++) {
            sum += buf[i];
        }
        var chk = (buf[4 + dataLen] << 8) | buf[4 + dataLen + 1];
        return ((sum + chk) & 0xFFFF) == 0x10000;
    }
}

// ── BLE Delegate ──────────────────────────────────────────────────────────────
class JbdBleDelegate extends BluetoothLowEnergy.BleDelegate {

    var _svcUuid;
    var _rxUuid;
    var _txUuid;
    var _bmsData;
    var _device  = null;
    var _rxChar  = null;
    var _txChar  = null;
    var _rxBuf;

    function initialize(bmsData) {
        BleDelegate.initialize();
        _bmsData = bmsData;
        _rxBuf   = []b;
        _svcUuid = BluetoothLowEnergy.stringToUuid("0000ff00-0000-1000-8000-00805f9b34fb");
        _rxUuid  = BluetoothLowEnergy.stringToUuid("0000ff01-0000-1000-8000-00805f9b34fb");
        _txUuid  = BluetoothLowEnergy.stringToUuid("0000ff02-0000-1000-8000-00805f9b34fb");
        System.println("BLE delegate initialized");
    }

    function onScanResults(scanResults) {
        var result = scanResults.next() as BluetoothLowEnergy.ScanResult;
        while (result != null) {
            var name = result.getDeviceName();
            System.println("SCAN found: " + (name != null ? name : "unnamed"));
            if (name != null) {
                var lname = name.toLower();
                if (lname.find("xiaoxiang") != null ||
                    lname.find("jbd") != null ||
                    lname.find("sp22s003") != null) {
                    System.println("SCAN matched: " + name + " — pairing");
                    BluetoothLowEnergy.setScanState(BluetoothLowEnergy.SCAN_STATE_OFF);
                    BluetoothLowEnergy.pairDevice(result);
                    return;
                }
            }
            result = scanResults.next() as BluetoothLowEnergy.ScanResult;
        }
    }

    function onConnectedStateChanged(device, state) {
        System.println("BLE state changed: " + state);
        if (state == BluetoothLowEnergy.CONNECTION_STATE_CONNECTED) {
            _device = device;
            System.println("BLE connected, looking for service ff00");
            var svc = device.getService(_svcUuid);
            if (svc != null) {
                System.println("BLE service found");
                _rxChar = svc.getCharacteristic(_rxUuid);
                _txChar = svc.getCharacteristic(_txUuid);
                System.println("BLE rx=" + (_rxChar != null ? "ok" : "NULL") +
                               " tx=" + (_txChar != null ? "ok" : "NULL"));
                if (_rxChar != null) {
                    var cccd = _rxChar.getDescriptor(BluetoothLowEnergy.cccdUuid());
                    if (cccd != null) {
                        System.println("BLE enabling notifications");
                        cccd.requestWrite([0x01, 0x00]b);
                    } else {
                        System.println("BLE cccd descriptor not found");
                    }
                }
            } else {
                System.println("BLE service ff00 NOT found");
            }
            _bmsData.connected = (_txChar != null && _rxChar != null);
            System.println("BLE connected=" + _bmsData.connected);
        } else {
            System.println("BLE disconnected, restarting scan");
            _bmsData.connected = false;
            _device  = null;
            _rxChar  = null;
            _txChar  = null;
            startScan();
        }
    }

    function onCharacteristicChanged(char, value) {
        if (char.getUuid().equals(_rxUuid)) {
            _rxBuf.addAll(value);
            var sz = _rxBuf.size();

            // If buffer doesn't start with DD, it's corrupted — flush it
            if (_rxBuf[0] != 0xDD) {
                System.println("BLE bad buffer start, flushing");
                _rxBuf = []b;
                return;
            }

            // Safety cap — if buffer grows beyond 64 bytes something is wrong
            if (sz > 64) {
                System.println("BLE buffer overflow, flushing");
                _rxBuf = []b;
                return;
            }

            if (sz >= 4) {
                var expectedLen = _rxBuf[3] + 7;
                System.println("BLE buf sz=" + sz + " expected=" + expectedLen);
                if (sz >= expectedLen) {
                    System.println("BLE parsing packet");
                    _bmsData.update(_rxBuf);
                    _rxBuf = []b;
                }
            }
        }
    }

    function requestBasicInfo() {
        if (_txChar != null) {
            try {
                _txChar.requestWrite(BASIC_INFO_REQUEST, {:writeType => BluetoothLowEnergy.WRITE_TYPE_WITH_RESPONSE});
            } catch (e) {
                System.println("requestWrite failed: " + e.getErrorMessage());
            }
        }
    }

    function startScan() {
        System.println("BLE starting scan");
        BluetoothLowEnergy.setScanState(BluetoothLowEnergy.SCAN_STATE_SCANNING);
    }
}

// ── Data Field View ───────────────────────────────────────────────────────────
class JBDBmsView extends WatchUi.DataField {

    var _bmsData;
    var _delegate;
    var _tickCount;

    function initialize() {
        DataField.initialize();
        _bmsData   = new BmsData();
        _tickCount = 0;
        _delegate  = new JbdBleDelegate(_bmsData);

        BluetoothLowEnergy.registerProfile({
            :uuid => _delegate._svcUuid,
            :characteristics => [
                {
                    :uuid => _delegate._rxUuid,
                    :descriptors => [ BluetoothLowEnergy.cccdUuid() ]
                },
                {
                    :uuid => _delegate._txUuid
                }
            ]
        });
        BluetoothLowEnergy.setDelegate(_delegate);
        _delegate.startScan();
    }

    function compute(info) {
        _tickCount++;
        if (_tickCount >= 2) {
            _tickCount = 0;
            _delegate.requestBasicInfo();
        }
    }

    function onLayout(dc) {
    }

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();

        var bgColor = getBackgroundColor();
        var fgColor = (bgColor == Graphics.COLOR_WHITE)
            ? Graphics.COLOR_BLACK : Graphics.COLOR_WHITE;

        dc.setColor(fgColor, bgColor);
        dc.clear();

        if (!_bmsData.connected) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w/2, h/2, Graphics.FONT_TINY, "--",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        var cx = w / 2;
        var topY = h / 4;
        var botY = (h * 3) / 4;

        // Volts — top left
        dc.setColor(fgColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx / 2, topY, Graphics.FONT_NUMBER_MEDIUM,
            _bmsData.voltageV.format("%.1f") + "V",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Amps — top right
        dc.drawText(cx + cx / 2, topY, Graphics.FONT_NUMBER_MEDIUM,
            _bmsData.currentA.format("%.1f") + "A",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Ah — bottom center
        var ahColor = _bmsData.capacityAh > 3.0 ? Graphics.COLOR_GREEN : Graphics.COLOR_RED;
        dc.setColor(ahColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, botY, Graphics.FONT_NUMBER_MEDIUM,
            _bmsData.capacityAh.format("%.1f") + "Ah",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

// ── App Entry Point ───────────────────────────────────────────────────────────
class JBDBmsDataFieldApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) {}
    function onStop(state) {}
    function getInitialView() {
        return [new JBDBmsView()];
    }
}