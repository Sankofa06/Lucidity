// Fleet/pwa/scripts/make-icons.mjs
//
// What: Dependency-free PWA icon generator.
// Does: Renders the Lucidity mark (dark field, indigo-cyan radial glow with a
//       bright core) directly to PNG using node:zlib — no canvas/image deps.
// Touches: writes Fleet/pwa/public/icons/icon-{192,512}.png.
// Touched by: run manually (`node scripts/make-icons.mjs`) when the mark changes.

import { deflateSync } from "node:zlib";
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const outDir = join(here, "..", "public", "icons");
mkdirSync(outDir, { recursive: true });

function crc32(buf) {
    let c, table = [];
    for (let n = 0; n < 256; n++) {
        c = n;
        for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
        table[n] = c >>> 0;
    }
    let crc = 0xffffffff;
    for (const b of buf) crc = table[(crc ^ b) & 0xff] ^ (crc >>> 8);
    return (crc ^ 0xffffffff) >>> 0;
}

function chunk(type, data) {
    const len = Buffer.alloc(4);
    len.writeUInt32BE(data.length);
    const body = Buffer.concat([Buffer.from(type, "ascii"), data]);
    const crc = Buffer.alloc(4);
    crc.writeUInt32BE(crc32(body));
    return Buffer.concat([len, body, crc]);
}

function makePng(size) {
    const raw = Buffer.alloc(size * (size * 4 + 1));
    const cx = size / 2, cy = size / 2, maxR = size / 2;
    for (let y = 0; y < size; y++) {
        raw[y * (size * 4 + 1)] = 0; // filter: none
        for (let x = 0; x < size; x++) {
            const dx = (x - cx) / maxR, dy = (y - cy) / maxR;
            const d = Math.sqrt(dx * dx + dy * dy);
            // Dark field
            let r = 14, g = 16, b = 22;
            // Indigo→cyan glow, brightest at the core
            const glow = Math.max(0, 1 - d * 1.35);
            r += Math.round(70 * glow * glow);
            g += Math.round(90 * glow * glow + 60 * glow ** 4);
            b += Math.round(210 * glow);
            // Bright core
            const core = Math.max(0, 1 - d * 5);
            r += Math.round(160 * core);
            g += Math.round(190 * core);
            b += Math.round(40 * core);
            const o = y * (size * 4 + 1) + 1 + x * 4;
            raw[o] = Math.min(255, r);
            raw[o + 1] = Math.min(255, g);
            raw[o + 2] = Math.min(255, b);
            raw[o + 3] = 255;
        }
    }
    const ihdr = Buffer.alloc(13);
    ihdr.writeUInt32BE(size, 0);
    ihdr.writeUInt32BE(size, 4);
    ihdr[8] = 8;  // bit depth
    ihdr[9] = 6;  // RGBA
    return Buffer.concat([
        Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
        chunk("IHDR", ihdr),
        chunk("IDAT", deflateSync(raw)),
        chunk("IEND", Buffer.alloc(0)),
    ]);
}

for (const size of [192, 512]) {
    writeFileSync(join(outDir, `icon-${size}.png`), makePng(size));
    console.log(`wrote icon-${size}.png`);
}
