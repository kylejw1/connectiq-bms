import Toybox.Lang;

// Maps a bmsType string (from settings) to a driver instance.
// Add a new BMS by implementing BmsDriver and adding a branch here.
module BmsRegistry {

    const TYPE_JBD   = "jbd";
    const TYPE_JK    = "jk";
    const TYPE_EM3EV = "em3ev";

    function create(typeId as String) as BmsDriver {
        if (typeId.equals(TYPE_JK)) {
            return new JkDriver();
        }
        if (typeId.equals(TYPE_EM3EV)) {
            return new Em3evDriver();
        }
        return new JbdDriver();
    }
}
