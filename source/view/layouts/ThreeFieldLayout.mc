import Toybox.Lang;

// Top row split in two, bottom row one wide cell. Matches the original
// V (top-left) / A (top-right) / Ah (bottom-center) arrangement. Top cells
// are pulled inward so unit suffixes don't fall in the round corners.
class ThreeFieldLayout extends Layout {
    function initialize() { Layout.initialize(); }

    function draw(dc, fields as Array, fgColor as Number, bgColor as Number) as Void {
        if (fields.size() == 0) { return; }
        var w = dc.getWidth();
        var h = dc.getHeight();

        var inset = ((w < h) ? w : h) / 16;

        var topY  = h / 4 + inset;
        var botY  = (h * 3) / 4 - inset / 2;
        var topH  = h / 2 - inset * 2;
        var botH  = h / 2 - inset;
        var halfW = w / 2;

        LayoutHelpers.drawCell(dc, halfW / 2 + inset, topY, halfW - inset * 2, topH,
            fields[0], fgColor);
        if (fields.size() > 1) {
            LayoutHelpers.drawCell(dc, halfW + halfW / 2 - inset, topY,
                halfW - inset * 2, topH, fields[1], fgColor);
        }
        if (fields.size() > 2) {
            LayoutHelpers.drawCell(dc, w / 2, botY, w - inset * 2, botH,
                fields[2], fgColor);
        }
    }
}
