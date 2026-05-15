import Toybox.Lang;
import Toybox.BluetoothLowEnergy;
import Toybox.System;

// Driver-agnostic BLE transport. Owns the BleDelegate lifecycle. Delegates
// vendor-specific decisions (UUIDs, framing, parsing) to a BmsDriver.
//
// Lifecycle:
//   init(driver, config, reading)  — registers profile, sets delegate
//   start()                        — begin scanning for the configured device
//   poll()                         — call from view.compute(); cycles requests
//
// Notes / quirks:
//   - registerProfile can only be called once per app launch per service. If
//     the user switches BMS type in settings we cannot transparently rebind;
//     the app must be restarted. We log a clear message in that case.
//   - Frame reassembly: notifications can be fragmented arbitrarily. We
//     accumulate bytes, sanity-check the start byte, and consult the driver
//     for expected frame length.
class BleManager extends BluetoothLowEnergy.BleDelegate {

    const RX_BUF_MAX = 256;

    var _driver;
    var _config;
    var _reading;

    var _svcUuid;
    var _rxUuid;
    var _txUuid;

    var _device  = null;
    var _rxChar  = null;
    var _txChar  = null;

    var _rxBuf;
    var _pollIdx;
    var _profileRegistered;

    function initialize(driver as BmsDriver, config as Config, reading as BmsReading) {
        BleDelegate.initialize();
        _driver  = driver;
        _config  = config;
        _reading = reading;
        _rxBuf   = []b;
        _pollIdx = 0;
        _profileRegistered = false;

        var svc = driver.serviceUuid();
        var rx  = driver.rxUuid();
        var tx  = driver.txUuid();
        if (svc.length() == 0 || rx.length() == 0 || tx.length() == 0) {
            System.println("BleManager: driver '" + driver.id() + "' has no UUIDs — disabled");
            return;
        }

        _svcUuid = BluetoothLowEnergy.stringToUuid(svc);
        _rxUuid  = BluetoothLowEnergy.stringToUuid(rx);
        _txUuid  = BluetoothLowEnergy.stringToUuid(tx);

        BluetoothLowEnergy.registerProfile({
            :uuid => _svcUuid,
            :characteristics => [
                { :uuid => _rxUuid, :descriptors => [ BluetoothLowEnergy.cccdUuid() ] },
                { :uuid => _txUuid }
            ]
        });
        BluetoothLowEnergy.setDelegate(self);
        _profileRegistered = true;
        System.println("BleManager: profile registered for driver '" + driver.id() + "'");
    }

    function start() as Void {
        if (!_profileRegistered) {
            return;
        }
        System.println("BleManager: starting scan");
        BluetoothLowEnergy.setScanState(BluetoothLowEnergy.SCAN_STATE_SCANNING);
    }

    function stop() as Void {
        BluetoothLowEnergy.setScanState(BluetoothLowEnergy.SCAN_STATE_OFF);
    }

    // Called from view.compute(); rotates through driver's poll requests.
    function poll() as Void {
        if (_txChar == null) { return; }
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
        var hints = _config.deviceNameHints(_driver);
        var result = scanResults.next() as BluetoothLowEnergy.ScanResult;
        while (result != null) {
            var name = result.getDeviceName();
            if (name != null) {
                System.println("BleManager: scan saw '" + name + "'");
                var lname = name.toLower();
                for (var i = 0; i < hints.size(); i++) {
                    var hint = hints[i].toLower();
                    if (hint.length() > 0 && lname.find(hint) != null) {
                        System.println("BleManager: matched '" + name + "' on '" + hint + "'");
                        BluetoothLowEnergy.setScanState(BluetoothLowEnergy.SCAN_STATE_OFF);
                        BluetoothLowEnergy.pairDevice(result);
                        return;
                    }
                }
            }
            result = scanResults.next() as BluetoothLowEnergy.ScanResult;
        }
    }

    function onConnectedStateChanged(device, state) {
        System.println("BleManager: connection state " + state);
        if (state == BluetoothLowEnergy.CONNECTION_STATE_CONNECTED) {
            _device = device;
            var svc = device.getService(_svcUuid);
            if (svc == null) {
                System.println("BleManager: service not found on device");
                _reading.connected = false;
                return;
            }
            _rxChar = svc.getCharacteristic(_rxUuid);
            _txChar = svc.getCharacteristic(_txUuid);
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
            _rxBuf  = []b;
            System.println("BleManager: disconnected, rescanning");
            start();
        }
    }

    function onCharacteristicChanged(char, value) {
        if (!char.getUuid().equals(_rxUuid)) { return; }

        _rxBuf.addAll(value);

        // Flush junk before any valid start byte.
        while (_rxBuf.size() > 0 && !_driver.isFrameStartByte(_rxBuf[0])) {
            _rxBuf = _rxBuf.slice(1, _rxBuf.size());
        }

        // Cap runaway buffer.
        if (_rxBuf.size() > RX_BUF_MAX) {
            System.println("BleManager: rx buffer overflow, flushing");
            _rxBuf = []b;
            return;
        }

        // Try to extract one or more complete frames.
        while (_rxBuf.size() >= 4) {
            var expected = _driver.expectedFrameLen(_rxBuf);
            if (expected <= 0 || _rxBuf.size() < expected) { break; }
            var frame = _rxBuf.slice(0, expected);
            _rxBuf = _rxBuf.slice(expected, _rxBuf.size());
            _driver.parseFrame(frame, _reading);
        }
    }
}
