import Toybox.Lang;

// Unified BMS state, union of fields any supported BMS can produce.
// Drivers fill in what they support; unsupported fields stay null.
// Views read this and decide what to render based on user-configured slots.
class BmsReading {
    var voltageV;          // Float, total pack voltage
    var currentA;          // Float, signed instantaneous (negative = charging)
    var currentAvgA;       // Float, rolling-window mean of currentA
    var powerW;            // Float, derived from voltage * |current|
    var capacityAh;        // Float, remaining capacity
    var designCapacityAh;  // Float, nominal/design capacity
    var socPct;            // Number, 0..100
    var cycleCount;        // Number
    var tempC;             // Float, hottest sensor (or only sensor)
    var tempMinC;          // Float, coldest sensor when multiple
    var cellCount;         // Number
    var cellMinV;          // Float
    var cellMaxV;          // Float
    var cellDeltaMv;       // Number, max - min in millivolts
    var protectionBits;    // Number, vendor-specific fault bitmask
    var connected;         // Bool
    var lastUpdateMs;      // Number

    function initialize() {
        reset();
    }

    function reset() {
        voltageV = null;
        currentA = null;
        currentAvgA = null;
        powerW = null;
        capacityAh = null;
        designCapacityAh = null;
        socPct = null;
        cycleCount = null;
        tempC = null;
        tempMinC = null;
        cellCount = null;
        cellMinV = null;
        cellMaxV = null;
        cellDeltaMv = null;
        protectionBits = null;
        connected = false;
        lastUpdateMs = 0;
    }
}
