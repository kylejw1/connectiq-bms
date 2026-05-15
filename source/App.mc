import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class BmsDataFieldApp extends Application.AppBase {

    var _view;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {}
    function onStop(state)  {}

    function getInitialView() {
        _view = new BmsView();
        return [_view];
    }

    function onSettingsChanged() {
        if (_view != null) {
            _view.reloadConfig();
            WatchUi.requestUpdate();
        }
    }
}
