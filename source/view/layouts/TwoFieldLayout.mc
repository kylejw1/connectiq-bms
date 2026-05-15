import Toybox.Lang;

// Two-up. Side-by-side if the dc is wider than tall, stacked otherwise.
class TwoFieldLayout extends Layout {
    function initialize() { Layout.initialize(); }

    function draw(dc, fields as Array, fgColor as Number, bgColor as Number) as Void {
        if (fields.size() == 0) { return; }
        var w = dc.getWidth();
        var h = dc.getHeight();

        if (w >= h) {
            var cellW = w / 2;
            LayoutHelpers.drawCell(dc, cellW / 2,        h / 2, cellW - 8, h - 8,
                fields[0], fgColor);
            if (fields.size() > 1) {
                LayoutHelpers.drawCell(dc, cellW + cellW / 2, h / 2, cellW - 8, h - 8,
                    fields[1], fgColor);
            }
        } else {
            var cellH = h / 2;
            LayoutHelpers.drawCell(dc, w / 2, cellH / 2,        w - 8, cellH - 8,
                fields[0], fgColor);
            if (fields.size() > 1) {
                LayoutHelpers.drawCell(dc, w / 2, cellH + cellH / 2, w - 8, cellH - 8,
                    fields[1], fgColor);
            }
        }
    }
}
