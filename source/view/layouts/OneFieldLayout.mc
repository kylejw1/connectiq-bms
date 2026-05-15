import Toybox.Lang;

class OneFieldLayout extends Layout {
    function initialize() { Layout.initialize(); }

    function draw(dc, fields as Array, fgColor as Number, bgColor as Number) as Void {
        if (fields.size() == 0) { return; }
        var w = dc.getWidth();
        var h = dc.getHeight();
        LayoutHelpers.drawCell(dc, w / 2, h / 2, w - 8, h - 8, fields[0], fgColor);
    }
}
