import Toybox.Lang;
import Toybox.Graphics;
import Toybox.WatchUi;

// Base layout class. Subclasses implement draw(); LayoutHelpers offers shared
// cell-rendering utilities so each concrete layout stays small.
class Layout {
    function draw(dc, fields as Array, fgColor as Number, bgColor as Number) as Void {}
}

module LayoutHelpers {

    // Draw one formatted field at center (cx, cy) inside a (w, h) bounding box.
    // Renders a warning background if field.bgColor is set, then value+unit
    // centered, with the biggest font that fits the value text in availW.
    function drawCell(dc, cx as Number, cy as Number, w as Number, h as Number,
                      field as FormattedField, fgColor as Number) as Void {
        if (field == null) { return; }

        // Warning highlight (low V, low SOC, etc.)
        if (field.bgColor != null) {
            dc.setColor(field.bgColor, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(cx - w / 2, cy - h / 2, w, h, 6);
        }

        var unitFont = Graphics.FONT_XTINY;
        var unitText = field.unit != null ? field.unit : "";
        var unitW    = unitText.length() > 0
            ? dc.getTextWidthInPixels(unitText, unitFont) + 4
            : 0;

        // Leave breathing room for the cell boundary (inset 4px each side).
        var availW = w - unitW - 8;
        if (availW < 20) { availW = w - unitW; }
        var availH = h - 4;

        var valueText = field.value;
        var valueFont = _fitFont(dc, valueText, availW, availH);

        var valueW = dc.getTextWidthInPixels(valueText, valueFont);
        var totalW = valueW + unitW;
        var startX = cx - totalW / 2;

        var color = field.color != null ? field.color : fgColor;
        var unitColor = field.bgColor != null ? field.color : fgColor;

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(startX + valueW / 2, cy, valueFont, valueText,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        if (unitText.length() > 0) {
            dc.setColor(unitColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(startX + valueW + 4, cy + 4, unitFont, unitText,
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    function _fitFont(dc, text as String, maxW as Number, maxH as Number) as Number {
        // Note: FONT_NUMBER_THAI_HOT and FONT_NUMBER_HOT are intentionally
        // excluded — they overflow round screens for 4-up grids.
        var fonts = [
            Graphics.FONT_NUMBER_MEDIUM,
            Graphics.FONT_NUMBER_MILD,
            Graphics.FONT_LARGE,
            Graphics.FONT_MEDIUM,
            Graphics.FONT_SMALL,
            Graphics.FONT_TINY,
        ];
        for (var i = 0; i < fonts.size(); i++) {
            var f = fonts[i];
            var w = dc.getTextWidthInPixels(text, f);
            var h = Graphics.getFontHeight(f);
            if (w <= maxW && h <= maxH) { return f; }
        }
        return Graphics.FONT_TINY;
    }

    // Static "connecting" indicator: battery silhouette with a fill segment
    // and a label underneath. No animation.
    function drawConnecting(dc, w as Number, h as Number) as Void {
        var cx = w / 2;
        var cy = h / 2;
        var size = (w < h ? w : h);

        var bw = (size * 32) / 100;   // battery body width
        var bh = (size * 20) / 100;   // battery body height
        var tw = (bw * 35) / 100;     // terminal nub width
        var th = (bh * 22) / 100;     // terminal nub height
        if (th < 3) { th = 3; }

        var bodyX = cx - bw / 2;
        var bodyY = cy - bh / 2;

        // Body outline (2px stroke)
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawRoundedRectangle(bodyX, bodyY, bw, bh, 3);
        dc.setPenWidth(1);

        // Terminal nub on top
        dc.fillRectangle(cx - tw / 2, bodyY - th, tw, th);

        // Single fill segment as a static "low/charging" indicator
        var pad = (bh > 16) ? 3 : 2;
        var segW = (bw - pad * 2) / 4;
        dc.fillRectangle(bodyX + pad, bodyY + pad, segW, bh - pad * 2);

        // Label
        var labelFont = (size < 180) ? Graphics.FONT_XTINY : Graphics.FONT_TINY;
        var labelH = Graphics.getFontHeight(labelFont);
        var labelY = bodyY + bh + (labelH / 2) + 4;
        if (labelY + labelH / 2 < h) {
            dc.drawText(cx, labelY, labelFont, "Connecting",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }
}
