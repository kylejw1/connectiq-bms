import Toybox.Lang;

// Rolling-window mean of current readings. Smooths the displayed current so
// the data field shows a usable "average draw" instead of jumpy instantaneous
// values. Sampled once per compute() tick (~1 Hz), so window size in samples
// equals window size in seconds.
class CurrentAverager {

    var _window;
    var _samples;
    var _idx;
    var _count;

    function initialize(window as Number) {
        _window  = window;
        _samples = new [window];
        _idx     = 0;
        _count   = 0;
    }

    function sample(v) as Void {
        if (v == null) { return; }
        _samples[_idx] = v;
        _idx = (_idx + 1) % _window;
        if (_count < _window) { _count++; }
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
