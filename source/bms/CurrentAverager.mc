import Toybox.Lang;

// Rolling-window mean of current readings. Smooths the displayed current so
// the data field shows a usable "average draw" instead of jumpy instantaneous
// values. Sampled once per compute() tick (~1 Hz), giving ~30 s of history.
class CurrentAverager {
    const WINDOW = 30;

    var _samples;
    var _idx;
    var _count;

    function initialize() {
        _samples = new [WINDOW];
        _idx = 0;
        _count = 0;
    }

    function sample(v) as Void {
        if (v == null) { return; }
        _samples[_idx] = v;
        _idx = (_idx + 1) % WINDOW;
        if (_count < WINDOW) { _count++; }
    }

    function average() {
        if (_count == 0) { return null; }
        var sum = 0.0;
        for (var i = 0; i < _count; i++) {
            sum += _samples[i];
        }
        return sum / _count;
    }

    function reset() as Void {
        _idx = 0;
        _count = 0;
    }
}
