import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.System;
import Toybox.BluetoothLowEnergy;
import Toybox.FitContributor;

class BmsView extends WatchUi.DataField {

    var _config;
    var _reading;
    var _driver;
    var _ble;
    var _layout;
    var _tickCount;
    var _registeredBmsType;
    var _bmsTypeChangedNeedsRestart;
    var _currentAvg;

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
        _driver     = BmsRegistry.create(_config.bmsType);
        _registeredBmsType = _config.bmsType;
        _ble        = new BleManager(_driver, _config, _reading);
        _currentAvg = new CurrentAverager();
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

        _layout = _pickLayout(null);
    }

    // Called by app on settings change. We can hot-reload everything *except*
    // the BMS type — BluetoothLowEnergy.registerProfile is one-shot per app
    // launch. On bms type change we mark a flag and the view nudges the user
    // to restart the activity.
    function reloadConfig() as Void {
        _config.reload();
        if (!_config.bmsType.equals(_registeredBmsType)) {
            _bmsTypeChangedNeedsRestart = true;
        }
        _layout = _pickLayout(null);
        WatchUi.requestUpdate();
    }

    function compute(info) {
        _tickCount++;

        if (_reading.connected) {
            _currentAvg.sample(_reading.currentA);
            _reading.currentAvgA = _currentAvg.average();
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

    function onLayout(dc) {
        _layout = _pickLayout(dc);
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
            LayoutHelpers.drawConnecting(dc, w, h);
            return;
        }

        var formatted = [];
        for (var i = 0; i < _config.fields.size(); i++) {
            var f = FieldFormatter.format(_config.fields[i], _reading, _config);
            if (f != null) { formatted.add(f); }
        }
        if (formatted.size() == 0) {
            LayoutHelpers.drawConnecting(dc, w, h);
            return;
        }
        _layout.draw(dc, formatted, fgColor, bgColor);
    }

    hidden function _pickLayout(dc) as Layout {
        var id = _config.layoutId;
        if (id.equals("one"))   { return new OneFieldLayout(); }
        if (id.equals("two"))   { return new TwoFieldLayout(); }
        if (id.equals("three")) { return new ThreeFieldLayout(); }
        if (id.equals("four"))  { return new FourFieldLayout(); }
        return _autoLayout(dc);
    }

    hidden function _autoLayout(dc) as Layout {
        var n = 0;
        for (var i = 0; i < _config.fields.size(); i++) {
            if (!_config.fields[i].equals("none")) { n++; }
        }
        if (n <= 1) { return new OneFieldLayout(); }
        if (n == 2) { return new TwoFieldLayout(); }
        if (n == 3) { return new ThreeFieldLayout(); }
        return new FourFieldLayout();
    }
}
