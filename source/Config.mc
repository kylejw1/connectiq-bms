import Toybox.Lang;
import Toybox.Application;

// Typed wrapper around Application.Properties. Read once at init and after
// every onSettingsChanged(); callers hold the Config reference and re-read
// fields via the same accessor methods, so refresh is just `_config.reload()`.
//
// Connect IQ list-typed settings only accept numeric values, so the
// user-facing enum properties are stored as small integer codes and decoded
// to string ids here.
class Config {

    // bmsType codes
    static const BMS_JBD   = 0;
    static const BMS_JK    = 1;
    static const BMS_EM3EV = 2;

    // layoutId codes
    static const LAYOUT_AUTO  = 0;
    static const LAYOUT_ONE   = 1;
    static const LAYOUT_TWO   = 2;
    static const LAYOUT_THREE = 3;
    static const LAYOUT_FOUR  = 4;

    // field codes — keep in sync with settings.xml listEntries
    static const F_NONE             = 0;
    static const F_VOLTAGE          = 1;
    static const F_CURRENT          = 2;
    static const F_POWER            = 3;
    static const F_CAPACITY         = 4;
    static const F_DESIGN_CAPACITY  = 5;
    static const F_SOC              = 6;
    static const F_TEMP             = 7;
    static const F_TEMP_MIN         = 8;
    static const F_CELL_MIN         = 9;
    static const F_CELL_MAX         = 10;
    static const F_CELL_DELTA       = 11;
    static const F_CYCLES           = 12;

    var bmsType;            // String id, e.g. "jbd"
    var deviceNameFilter;   // String
    var layoutId;           // String id, e.g. "auto"
    var fields;             // Array of String slot keys
    var tempUnit;             // String "c" or "f"
    var lowAhThreshold;       // Float
    var lowVoltageThreshold;  // Float — below this -> red warning bg
    var lowSocPct;            // Number — below this % -> red warning bg
    var warnSocPct;           // Number — below this % -> yellow text (no bg)
    var pollIntervalTicks;    // Number

    function initialize() {
        reload();
    }

    function reload() as Void {
        bmsType           = _decodeBmsType   (_getNumber("bmsType",  BMS_JBD));
        deviceNameFilter  = _getString("deviceNameFilter", "");
        layoutId          = _decodeLayout    (_getNumber("layoutId", LAYOUT_AUTO));
        fields            = [
            _decodeField(_getNumber("field1", F_VOLTAGE)),
            _decodeField(_getNumber("field2", F_CURRENT)),
            _decodeField(_getNumber("field3", F_CAPACITY)),
            _decodeField(_getNumber("field4", F_SOC)),
        ];
        tempUnit            = (_getNumber("tempUnit", 0) == 1) ? "f" : "c";
        lowAhThreshold      = _getFloat("lowAhThreshold", 3.0);
        lowVoltageThreshold = _getFloat("lowVoltageThreshold", 42.0);
        lowSocPct           = _getNumber("lowSocPct", 30);
        warnSocPct          = _getNumber("warnSocPct", 50);
        pollIntervalTicks   = _getNumber("pollIntervalTicks", 2);
    }

    // If the user typed a filter, split on commas. Otherwise fall back to the
    // driver's defaults.
    function deviceNameHints(driver as BmsDriver) as Array {
        var f = deviceNameFilter;
        if (f != null && f.length() > 0) {
            return _splitCsv(f);
        }
        return driver.defaultNameHints();
    }

    // ── decoders ────────────────────────────────────────────────────────────

    function _decodeBmsType(c as Number) as String {
        if (c == BMS_JK)    { return "jk"; }
        if (c == BMS_EM3EV) { return "em3ev"; }
        return "jbd";
    }

    function _decodeLayout(c as Number) as String {
        if (c == LAYOUT_ONE)   { return "one"; }
        if (c == LAYOUT_TWO)   { return "two"; }
        if (c == LAYOUT_THREE) { return "three"; }
        if (c == LAYOUT_FOUR)  { return "four"; }
        return "auto";
    }

    function _decodeField(c as Number) as String {
        if (c == F_VOLTAGE)         { return "voltage"; }
        if (c == F_CURRENT)         { return "current"; }
        if (c == F_POWER)           { return "power"; }
        if (c == F_CAPACITY)        { return "capacity"; }
        if (c == F_DESIGN_CAPACITY) { return "design_capacity"; }
        if (c == F_SOC)             { return "soc"; }
        if (c == F_TEMP)            { return "temp"; }
        if (c == F_TEMP_MIN)        { return "temp_min"; }
        if (c == F_CELL_MIN)        { return "cell_min"; }
        if (c == F_CELL_MAX)        { return "cell_max"; }
        if (c == F_CELL_DELTA)      { return "cell_delta"; }
        if (c == F_CYCLES)          { return "cycles"; }
        return "none";
    }

    // ── primitive getters ───────────────────────────────────────────────────

    function _getString(key, fallback) as String {
        var v = Application.Properties.getValue(key);
        if (v == null) { return fallback; }
        return v.toString();
    }

    function _getNumber(key, fallback) as Number {
        var v = Application.Properties.getValue(key);
        if (v == null) { return fallback; }
        if (v instanceof Number) { return v; }
        if (v instanceof Float)  { return v.toNumber(); }
        return fallback;
    }

    function _getFloat(key, fallback) as Float {
        var v = Application.Properties.getValue(key);
        if (v == null) { return fallback; }
        if (v instanceof Float)  { return v; }
        if (v instanceof Number) { return v.toFloat(); }
        return fallback;
    }

    function _splitCsv(s as String) as Array {
        var out = [];
        var cur = "";
        for (var i = 0; i < s.length(); i++) {
            var ch = s.substring(i, i + 1);
            if (ch.equals(",")) {
                if (cur.length() > 0) { out.add(_trim(cur)); }
                cur = "";
            } else {
                cur += ch;
            }
        }
        if (cur.length() > 0) { out.add(_trim(cur)); }
        return out;
    }

    function _trim(s as String) as String {
        var start = 0;
        var end = s.length();
        while (start < end && s.substring(start, start + 1).equals(" ")) { start++; }
        while (end > start && s.substring(end - 1, end).equals(" "))     { end--; }
        return s.substring(start, end);
    }
}
