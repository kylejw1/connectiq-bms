import Toybox.Lang;

// Single layout that handles 1-8 fields.
//
// 1 field  — one full-size centered cell
// 2+ fields — 2-column grid with ceil(n/2) rows; if n is odd the last cell
//             spans the full width (centered). First and last rows are inset
//             inward to keep text clear of the round screen corners.
class AutoLayout extends Layout {
    function initialize() { Layout.initialize(); }

    function draw(dc, fields as Array, fgColor as Number, bgColor as Number) as Void {
        var n = fields.size();
        if (n == 0) { return; }
        var w = dc.getWidth();
        var h = dc.getHeight();

        if (n == 1) {
            LayoutHelpers.drawCell(dc, w / 2, h / 2, w - 8, h - 8, fields[0], fgColor);
            return;
        }

        var rows  = (n + 1) / 2;  // integer ceil: works because Monkey C truncates
        var inset = _cornerInset(w, h, rows);
        var cellW = w / 2 - inset * 2;
        var cellH = h / rows - inset * 2;
        var leftX  = w / 4 + inset;
        var rightX = (3 * w) / 4 - inset;

        var idx = 0;
        for (var row = 0; row < rows && idx < n; row++) {
            var cy       = _rowCy(h, rows, row, inset);
            var lastCell = (row == rows - 1) && (n % 2 == 1);
            if (lastCell) {
                LayoutHelpers.drawCell(dc, w / 2, cy, w - inset * 2, cellH, fields[idx], fgColor);
                idx++;
            } else {
                LayoutHelpers.drawCell(dc, leftX,  cy, cellW, cellH, fields[idx], fgColor);
                idx++;
                if (idx < n) {
                    LayoutHelpers.drawCell(dc, rightX, cy, cellW, cellH, fields[idx], fgColor);
                    idx++;
                }
            }
        }
    }

    // Nominal row center plus a push inward for the top and bottom rows.
    hidden function _rowCy(h as Number, rows as Number, row as Number, inset as Number) as Number {
        var cy = h * (2 * row + 1) / (2 * rows);
        if (row == 0)        { cy += inset; }
        if (row == rows - 1) { cy -= inset; }
        return cy;
    }

    // Inset scales with row count: more rows → smaller inset per row.
    hidden function _cornerInset(w as Number, h as Number, rows as Number) as Number {
        var size = w < h ? w : h;
        if (rows <= 2) { return size / 16; }
        if (rows == 3) { return size / 20; }
        return size / 24;
    }
}
