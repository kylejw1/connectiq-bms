import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.System;
import Toybox.BluetoothLowEnergy;

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

        var n = _config.pollIntervalTicks;
        if (n < 1) { n = 1; }
        if (_tickCount >= n) {
            _tickCount = 0;
            _ble.poll();
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
