import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.System;
import Toybox.BluetoothLowEnergy;
import Toybox.FitContributor;

class BmsView extends WatchUi.DataField {

    var _config;
    var _reading;
    var _ble;
    var _layout;
    var _tickCount;
    var _registeredBmsType;
    var _bmsTypeChangedNeedsRestart;
    var _currentAvg;
    var _activitySumA;
    var _activityCountA;

    // FIT record fields — surfaced as time-series graphs in Garmin Connect
    // after the activity syncs to the phone.
    var _fitVoltage;
    var _fitCurrentAvg;
    var _fitPowerAvg;
    var _fitSoc;

    function initialize() {
        DataField.initialize();
        _tickCount = 0;
        _bmsTypeChangedNeedsRestart = false;

        _config     = new Config();
        _reading    = new BmsReading();
        _registeredBmsType = _config.bmsType;
        var drivers = _config.bmsType.equals("auto")
            ? BmsRegistry.createAll()
            : [BmsRegistry.create(_config.bmsType)];
        _ble        = new BleManager(drivers, _config, _reading);
        _currentAvg     = new CurrentAverager(_config.rollingWindowSecs);
        _activitySumA   = 0.0;
        _activityCountA = 0;
        _ble.start();

        _fitVoltage = createField(
            "Battery Voltage", 0,
            FitContributor.DATA_TYPE_FLOAT,
            { :mesgType => FitContributor.MESG_TYPE_RECORD, :units => "V" }
        );
        _fitCurrentAvg = createField(
            "Battery Current (avg)", 1,
            FitContributor.DATA_TYPE_FLOAT,
            { :mesgType => FitContributor.MESG_TYPE_RECORD, :units => "A" }
        );
        _fitPowerAvg = createField(
            "Battery Power (avg)", 2,
            FitContributor.DATA_TYPE_FLOAT,
            { :mesgType => FitContributor.MESG_TYPE_RECORD, :units => "W" }
        );
        _fitSoc = createField(
            "Battery SOC", 3,
            FitContributor.DATA_TYPE_UINT8,
            { :mesgType => FitContributor.MESG_TYPE_RECORD, :units => "%" }
        );

        _layout = new AutoLayout();
    }

    // Called by app on settings change. We can hot-reload everything *except*
    // the BMS type — BluetoothLowEnergy.registerProfile is one-shot per app
    // launch. On bms type change we mark a flag and the view nudges the user
    // to restart the activity.
    function reloadConfig() as Void {
        var prevWindow = _config.rollingWindowSecs;
        _config.reload();
        if (!_config.bmsType.equals(_registeredBmsType)) {
            _bmsTypeChangedNeedsRestart = true;
        }
        if (_config.rollingWindowSecs != prevWindow) {
            _currentAvg = new CurrentAverager(_config.rollingWindowSecs);
        }
        WatchUi.requestUpdate();
    }

    function compute(info) {
        _tickCount++;

        if (_reading.connected) {
            var mode = _config.currentMode;
            if (mode == Config.CURRENT_INSTANT) {
                _reading.currentAvgA = null;  // FieldFormatter falls back to currentA
            } else if (mode == Config.CURRENT_ROLLING) {
                _currentAvg.sample(_reading.currentA);
                _reading.currentAvgA = _currentAvg.average();
            } else {
                if (_reading.currentA != null) {
                    _activitySumA   += _reading.currentA;
                    _activityCountA += 1;
                }
                _reading.currentAvgA = (_activityCountA > 0)
                    ? (_activitySumA / _activityCountA) : null;
            }
        } else {
            _currentAvg.reset();
            _reading.currentAvgA = null;
        }

        _recordFit();

        var n = _config.pollIntervalTicks;
        if (n < 1) { n = 1; }
        if (_tickCount >= n) {
            _tickCount = 0;
            _ble.poll();
        }
    }

    // Push current reading into the FIT record stream. Skip writes when the
    // value is missing so Garmin Connect shows gaps rather than zero-spikes
    // before connection / on dropout.
    hidden function _recordFit() as Void {
        if (!_reading.connected) { return; }

        if (_reading.voltageV != null) {
            _fitVoltage.setData(_reading.voltageV);
        }
        var avgA = _reading.currentAvgA;
        if (avgA != null) {
            _fitCurrentAvg.setData(avgA);
            if (_reading.voltageV != null) {
                _fitPowerAvg.setData(_reading.voltageV * avgA);
            }
        }
        if (_reading.socPct != null) {
            _fitSoc.setData(_reading.socPct);
        }
    }

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();

        var bgColor = getBackgroundColor();
        var fgColor = (bgColor == Graphics.COLOR_WHITE)
            ? Graphics.COLOR_BLACK : Graphics.COLOR_WHITE;

        dc.setColor(fgColor, bgColor);
        dc.clear();

        if (_bmsTypeChangedNeedsRestart) {
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h / 2, Graphics.FONT_TINY,
                "Restart activity",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        if (!_reading.connected) {
            LayoutHelpers.drawConnecting(dc, w, h, _deviceHintStr());
            return;
        }

        var formatted = [];
        for (var i = 0; i < _config.fields.size(); i++) {
            var f = FieldFormatter.format(_config.fields[i], _reading, _config);
            if (f != null) { formatted.add(f); }
        }
        if (formatted.size() == 0) {
            LayoutHelpers.drawConnecting(dc, w, h, _deviceHintStr());
            return;
        }
        _layout.draw(dc, formatted, fgColor, bgColor);
    }

    hidden function _deviceHintStr() as String {
        var driver = _ble.activeDriver();
        if (driver == null) {
            return "auto-detect";
        }
        var hints = _config.deviceNameHints(driver);
        var s = "";
        for (var i = 0; i < hints.size(); i++) {
            if (i > 0) { s += ", "; }
            s += hints[i];
        }
        return s;
    }

}
