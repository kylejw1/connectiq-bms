import Toybox.Lang;
import Toybox.Graphics;

class FormattedField {
    var value;
    var unit;
    var color;    // null = use the cell's fgColor (theme-aware)
    var bgColor;  // null = transparent (no warning highlight)

    function initialize(v, u, c) {
        value   = v;
        unit    = u;
        color   = c;
        bgColor = null;
    }
}

// Pure formatting: slot key + reading + config -> printable value+unit+color.
// Returns null when the field is "none" or the reading lacks the data.
module FieldFormatter {

    const C_CHARGING = Graphics.COLOR_BLUE;
    const C_LOW      = Graphics.COLOR_RED;
    const C_OK       = Graphics.COLOR_GREEN;
    const C_WARN     = Graphics.COLOR_YELLOW;
    const C_MUTED    = Graphics.COLOR_LT_GRAY;
    const C_ALERT_BG = Graphics.COLOR_RED;
    const C_ALERT_FG = Graphics.COLOR_WHITE;

    function format(key as String, r as BmsReading, cfg as Config) as FormattedField? {
        if (key == null || key.equals("none")) { return null; }

        if (key.equals("voltage"))         { return _voltage(r, cfg); }
        if (key.equals("current"))         { return _current(r); }
        if (key.equals("power"))           { return _power(r); }
        if (key.equals("capacity"))        { return _capacity(r, cfg); }
        if (key.equals("design_capacity")) { return _designCapacity(r); }
        if (key.equals("soc"))             { return _soc(r, cfg); }
        if (key.equals("temp"))            { return _temp(r.tempC,    cfg); }
        if (key.equals("temp_min"))        { return _temp(r.tempMinC, cfg); }
        if (key.equals("cell_min"))        { return _cellV(r.cellMinV); }
        if (key.equals("cell_max"))        { return _cellV(r.cellMaxV); }
        if (key.equals("cell_delta"))      { return _cellDelta(r); }
        if (key.equals("cycles"))          { return _cycles(r); }

        return null;
    }

    function _muted(label) as FormattedField? {
        return new FormattedField("--", label, C_MUTED);
    }

    function _alert(value, unit) as FormattedField? {
        var f = new FormattedField(value, unit, C_ALERT_FG);
        f.bgColor = C_ALERT_BG;
        return f;
    }

    function _voltage(r as BmsReading, cfg as Config) as FormattedField? {
        if (r.voltageV == null) { return _muted("V"); }
        var text = r.voltageV.format("%.1f");
        if (r.voltageV < cfg.lowVoltageThreshold) { return _alert(text, "V"); }
        return new FormattedField(text, "V", null);
    }

    function _current(r as BmsReading) as FormattedField? {
        // Prefer the smoothed average; fall back to instantaneous while the
        // averager warms up (first sample). null only when never connected.
        var a = (r.currentAvgA != null) ? r.currentAvgA : r.currentA;
        if (a == null) { return _muted("A"); }
        var c = (a < 0) ? C_CHARGING : null;
        return new FormattedField(a.format("%.1f"), "A", c);
    }

    function _power(r as BmsReading) as FormattedField? {
        if (r.powerW == null) { return _muted("W"); }
        return new FormattedField(r.powerW.format("%.0f"), "W", null);
    }

    function _capacity(r as BmsReading, cfg as Config) as FormattedField? {
        if (r.capacityAh == null) { return _muted("Ah"); }
        var c = (r.capacityAh < cfg.lowAhThreshold) ? C_LOW : C_OK;
        return new FormattedField(r.capacityAh.format("%.1f"), "Ah", c);
    }

    function _designCapacity(r as BmsReading) as FormattedField? {
        if (r.designCapacityAh == null) { return _muted("Ah"); }
        return new FormattedField(r.designCapacityAh.format("%.1f"), "Ah", C_MUTED);
    }

    function _soc(r as BmsReading, cfg as Config) as FormattedField? {
        if (r.socPct == null) { return _muted("%"); }
        var text = r.socPct.toString();
        if (r.socPct < cfg.lowSocPct) { return _alert(text, "%"); }
        var c = (r.socPct < cfg.warnSocPct) ? C_WARN : C_OK;
        return new FormattedField(text, "%", c);
    }

    function _temp(tC, cfg as Config) as FormattedField? {
        if (tC == null) { return _muted("°"); }
        if (cfg.tempUnit.equals("f")) {
            var f = tC * 9.0 / 5.0 + 32.0;
            return new FormattedField(f.format("%.0f"), "°F", null);
        }
        return new FormattedField(tC.format("%.0f"), "°C", null);
    }

    function _cellV(v) as FormattedField? {
        if (v == null) { return _muted("V"); }
        return new FormattedField(v.format("%.2f"), "V", null);
    }

    function _cellDelta(r as BmsReading) as FormattedField? {
        if (r.cellDeltaMv == null) { return _muted("mV"); }
        var c = (r.cellDeltaMv > 50) ? C_WARN : C_OK;
        return new FormattedField(r.cellDeltaMv.toString(), "mV", c);
    }

    function _cycles(r as BmsReading) as FormattedField? {
        if (r.cycleCount == null) { return _muted(""); }
        return new FormattedField(r.cycleCount.toString(), "cyc", C_MUTED);
    }
}
