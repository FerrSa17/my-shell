.pragma library

// The outline of a rounded rectangle w x h (corner radius r) inset by `pad`, from the top centre,
// clockwise. outline(s, ...) is [x, y, outward normal x, y] at distance s along it.
function perimeter(w, h, r) { return 2 * (w - 2 * r) + 2 * (h - 2 * r) + 2 * Math.PI * r }

function outline(s, w, h, r, pad) {
    const x0 = pad, y0 = pad
    const segs = [
        [w / 2 - r, u => [x0 + w / 2 + u, y0, 0, -1]],
        [Math.PI * r / 2, u => { const a = -Math.PI / 2 + u / r; return [x0 + w - r + r * Math.cos(a), y0 + r + r * Math.sin(a), Math.cos(a), Math.sin(a)] }],
        [h - 2 * r, u => [x0 + w, y0 + r + u, 1, 0]],
        [Math.PI * r / 2, u => { const a = u / r; return [x0 + w - r + r * Math.cos(a), y0 + h - r + r * Math.sin(a), Math.cos(a), Math.sin(a)] }],
        [w - 2 * r, u => [x0 + w - r - u, y0 + h, 0, 1]],
        [Math.PI * r / 2, u => { const a = Math.PI / 2 + u / r; return [x0 + r + r * Math.cos(a), y0 + h - r + r * Math.sin(a), Math.cos(a), Math.sin(a)] }],
        [h - 2 * r, u => [x0, y0 + h - r - u, -1, 0]],
        [Math.PI * r / 2, u => { const a = Math.PI + u / r; return [x0 + r + r * Math.cos(a), y0 + r + r * Math.sin(a), Math.cos(a), Math.sin(a)] }],
        [w / 2 - r, u => [x0 + r + u, y0, 0, -1]]]
    for (const sg of segs) { if (s <= sg[0]) return sg[1](Math.max(0, s)); s -= sg[0] }
    return segs[segs.length - 1][1](segs[segs.length - 1][0])
}
