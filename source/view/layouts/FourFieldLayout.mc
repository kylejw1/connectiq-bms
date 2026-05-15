import Toybox.Lang;

// 2x2 grid. Corner cells are pulled inward by ~1/16 of the short side so
// numbers + unit suffixes stay inside the round screen's safe area.
class FourFieldLayout extends Layout {
    function initialize() { Layout.initialize(); }

    function draw(dc, fields as Array, fgColor as Number, bgColor as Number) as Void {
        if (fields.size() == 0) { return; }
        var w = dc.getWidth();
        var h = dc.getHeight();

        var inset = ((w < h) ? w : h) / 16;

        var leftX  = w / 4 + inset;
        var rightX = (3 * w) / 4 - inset;
        var topY   = h / 4 + inset;
        var botY   = (3 * h) / 4 - inset;

        var cellW = w / 2 - inset * 2;
        var cellH = h / 2 - inset * 2;

        var positions = [
            [leftX,  topY],
            [rightX, topY],
            [leftX,  botY],
            [rightX, botY],
        ];
        for (var i = 0; i < fields.size() && i < 4; i++) {
            LayoutHelpers.drawCell(dc, positions[i][0], positions[i][1],
                cellW, cellH, fields[i], fgColor);
        }
    }
}
