import Toybox.Lang;
import Toybox.BluetoothLowEnergy;
import Toybox.System;

// Driver-agnostic BLE transport. Owns the BleDelegate lifecycle. Delegates
// vendor-specific decisions (UUIDs, framing, parsing) to a BmsDriver.
//
// Lifecycle:
//   init(drivers, config, reading)  — registers profiles for all candidates
//   start()                         — begin scanning
//   poll()                          — call from view.compute(); cycles requests
//
// Driver detection:
//   Manual mode (one driver): driver is known at init; name hints (including
//   any user filter) are used to pick the right device.
//   Auto mode (multiple drivers): _driver is null until a scan result matches
//   one of the candidates by name. Once detected, reconnects reuse that driver.
//
// registerProfile is one-shot per service UUID per app launch. Switching BMS
// type in settings requires an activity restart; the view handles that warning.
class BleManager extends BluetoothLowEnergy.BleDelegate {

    const RX_BUF_MAX = 256;

    var _drivers;           // Array<BmsDriver> — all candidates registered at init
    var _driver;            // Active driver: null until detected (auto), or fixed (manual)
    var _config;
    var _reading;

    var _rxUuid  = null;    // Set at connection time from the active driver
    var _device  = null;
    var _rxChar  = null;
    var _txChar  = null;

    var _rxBuf;
    var _pollIdx;
    var _anyProfileRegistered;

    function initialize(drivers as Array, config as Config, reading as BmsReading) {
        BleDelegate.initialize();
        _drivers = drivers;
        _config  = config;
        _reading = reading;
        _rxBuf   = []b;
        _pollIdx = 0;
        _anyProfileRegistered = false;

        // In manual mode (single driver) the driver is known immediately.
        _driver = (drivers.size() == 1) ? drivers[0] : null;

        for (var i = 0; i < drivers.size(); i++) {
            _registerProfile(drivers[i]);
        }

        if (_anyProfileRegistered) {
            BluetoothLowEnergy.setDelegate(self);
        }
    }

    hidden function _registerProfile(d as BmsDriver) as Void {
        var svc = d.serviceUuid();
        var rx  = d.rxUuid();
        var tx  = d.txUuid();
        if (svc.length() == 0 || rx.length() == 0 || tx.length() == 0) {
            System.println("BleManager: driver '" + d.id() + "' has no UUIDs — skipped");
            return;
        }
        var svcUuid = BluetoothLowEnergy.stringToUuid(svc);
        var rxUuid  = BluetoothLowEnergy.stringToUuid(rx);
        var txUuid  = BluetoothLowEnergy.stringToUuid(tx);
        BluetoothLowEnergy.registerProfile({
            :uuid => svcUuid,
            :characteristics => [
                { :uuid => rxUuid, :descriptors => [ BluetoothLowEnergy.cccdUuid() ] },
                { :uuid => txUuid }
            ]
        });
        _anyProfileRegistered = true;
        System.println("BleManager: registered profile for driver '" + d.id() + "'");
    }

    // The currently active driver — null if auto-detect hasn't matched yet.
    function activeDriver() as BmsDriver? {
        return _driver;
    }

    function start() as Void {
        if (!_anyProfileRegistered) { return; }
        System.println("BleManager: starting scan");
        BluetoothLowEnergy.setScanState(BluetoothLowEnergy.SCAN_STATE_SCANNING);
    }

    function stop() as Void {
        BluetoothLowEnergy.setScanState(BluetoothLowEnergy.SCAN_STATE_OFF);
    }

    function poll() as Void {
        if (_txChar == null || _driver == null) { return; }
        var requests = _driver.pollRequests();
        if (requests.size() == 0) { return; }
        var req = requests[_pollIdx];
        _pollIdx = (_pollIdx + 1) % requests.size();
        try {
            _txChar.requestWrite(req, { :writeType => _driver.writeType() });
        } catch (e) {
            System.println("BleManager: requestWrite failed: " + e.getErrorMessage());
        }
    }

    // ── BleDelegate callbacks ────────────────────────────────────────────────

    function onScanResults(scanResults) {
        var result = scanResults.next() as BluetoothLowEnergy.ScanResult;
        while (result != null) {
            var name = result.getDeviceName();
            if (name != null) {
                System.println("BleManager: scan saw '" + name + "'");
                var matched = _matchDriver(name.toLower());
                if (matched != null) {
                    _driver = matched;
                    System.println("BleManager: matched driver '" + matched.id() + "' on '" + name + "'");
                    BluetoothLowEnergy.setScanState(BluetoothLowEnergy.SCAN_STATE_OFF);
                    BluetoothLowEnergy.pairDevice(result);
                    return;
                }
            }
            result = scanResults.next() as BluetoothLowEnergy.ScanResult;
        }
    }

    // Returns the matching driver for a lowercased device name, or null.
    // If a driver is already set (manual or previously detected), only checks
    // that driver (respecting the user's name filter). Otherwise tries all
    // candidates using their default name hints.
    hidden function _matchDriver(lname as String) as BmsDriver? {
        if (_driver != null) {
            var hints = _config.deviceNameHints(_driver);
            for (var i = 0; i < hints.size(); i++) {
                var hint = hints[i].toLower();
                if (hint.length() > 0 && lname.find(hint) != null) {
                    return _driver;
                }
            }
            return null;
        }
        for (var d = 0; d < _drivers.size(); d++) {
            var hints = _drivers[d].defaultNameHints();
            for (var i = 0; i < hints.size(); i++) {
                var hint = hints[i].toLower();
                if (hint.length() > 0 && lname.find(hint) != null) {
                    return _drivers[d];
                }
            }
        }
        return null;
    }

    function onConnectedStateChanged(device, state) {
        System.println("BleManager: connection state " + state);
        if (state == BluetoothLowEnergy.CONNECTION_STATE_CONNECTED) {
            if (_driver == null) {
                System.println("BleManager: connected but no driver detected — ignoring");
                _reading.connected = false;
                return;
            }
            _device = device;
            var svcUuid = BluetoothLowEnergy.stringToUuid(_driver.serviceUuid());
            _rxUuid     = BluetoothLowEnergy.stringToUuid(_driver.rxUuid());
            var txUuid  = BluetoothLowEnergy.stringToUuid(_driver.txUuid());
            var svc = device.getService(svcUuid);
            if (svc == null) {
                System.println("BleManager: service not found on device");
                _reading.connected = false;
                return;
            }
            _rxChar = svc.getCharacteristic(_rxUuid);
            _txChar = svc.getCharacteristic(txUuid);
            if (_rxChar != null) {
                var cccd = _rxChar.getDescriptor(BluetoothLowEnergy.cccdUuid());
                if (cccd != null) {
                    cccd.requestWrite([0x01, 0x00]b);
                }
            }
            _reading.connected = (_rxChar != null && _txChar != null);
            System.println("BleManager: connected=" + _reading.connected);
        } else {
            _reading.connected = false;
            _device = null;
            _rxChar = null;
            _txChar = null;
            _rxUuid = null;
            _rxBuf  = []b;
            System.println("BleManager: disconnected, rescanning");
            start();
        }
    }

    function onCharacteristicChanged(char, value) {
        if (_rxUuid == null || !char.getUuid().equals(_rxUuid)) { return; }

        _rxBuf.addAll(value);

        while (_rxBuf.size() > 0 && !_driver.isFrameStartByte(_rxBuf[0])) {
            _rxBuf = _rxBuf.slice(1, _rxBuf.size());
        }

        if (_rxBuf.size() > RX_BUF_MAX) {
            System.println("BleManager: rx buffer overflow, flushing");
            _rxBuf = []b;
            return;
        }

        while (_rxBuf.size() >= 4) {
            var expected = _driver.expectedFrameLen(_rxBuf);
            if (expected <= 0 || _rxBuf.size() < expected) { break; }
            var frame = _rxBuf.slice(0, expected);
            _rxBuf = _rxBuf.slice(expected, _rxBuf.size());
            _driver.parseFrame(frame, _reading);
        }
    }
}
