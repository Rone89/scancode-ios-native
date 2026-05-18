const fs = require("node:fs");
const path = require("node:path");
const zlib = require("node:zlib");

const workspace = "D:\\workspace\\scancode";
const outDir = path.join(workspace, "ScanCode", "Assets.xcassets", "AppIcon.appiconset");
fs.mkdirSync(outDir, { recursive: true });

const baseSize = 1024;
const pixels = Buffer.alloc(baseSize * baseSize * 4);

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

function setPixel(x, y, r, g, b, a = 255) {
  if (x < 0 || y < 0 || x >= baseSize || y >= baseSize) return;
  const offset = (y * baseSize + x) * 4;
  pixels[offset] = r;
  pixels[offset + 1] = g;
  pixels[offset + 2] = b;
  pixels[offset + 3] = a;
}

function blendPixel(x, y, color, alpha) {
  if (x < 0 || y < 0 || x >= baseSize || y >= baseSize) return;
  const offset = (y * baseSize + x) * 4;
  pixels[offset] = clamp(Math.round(pixels[offset] * (1 - alpha) + color[0] * alpha), 0, 255);
  pixels[offset + 1] = clamp(Math.round(pixels[offset + 1] * (1 - alpha) + color[1] * alpha), 0, 255);
  pixels[offset + 2] = clamp(Math.round(pixels[offset + 2] * (1 - alpha) + color[2] * alpha), 0, 255);
}

function insideRoundedRect(x, y, left, top, right, bottom, radius) {
  if (x >= left + radius && x <= right - radius && y >= top && y <= bottom) return true;
  if (x >= left && x <= right && y >= top + radius && y <= bottom - radius) return true;

  const corners = [
    [left + radius, top + radius],
    [right - radius, top + radius],
    [left + radius, bottom - radius],
    [right - radius, bottom - radius],
  ];

  return corners.some(([cx, cy]) => ((x - cx) ** 2 + (y - cy) ** 2) <= radius ** 2);
}

function writeChunk(tag, data) {
  const length = Buffer.alloc(4);
  length.writeUInt32BE(data.length, 0);

  const tagBuffer = Buffer.from(tag, "ascii");
  const crcBuffer = Buffer.concat([tagBuffer, data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE((crc32(crcBuffer) >>> 0), 0);

  return Buffer.concat([length, tagBuffer, data, crc]);
}

const crcTable = new Uint32Array(256).map((_, index) => {
  let c = index;
  for (let k = 0; k < 8; k += 1) {
    c = (c & 1) ? (0xedb88320 ^ (c >>> 1)) : (c >>> 1);
  }
  return c >>> 0;
});

function crc32(buffer) {
  let crc = 0xffffffff;
  for (const byte of buffer) {
    crc = crcTable[(crc ^ byte) & 0xff] ^ (crc >>> 8);
  }
  return (crc ^ 0xffffffff) >>> 0;
}

for (let y = 0; y < baseSize; y += 1) {
  for (let x = 0; x < baseSize; x += 1) {
    const nx = (x / (baseSize - 1)) * 2 - 1;
    const ny = (y / (baseSize - 1)) * 2 - 1;
    const radial = Math.sqrt(nx * nx + ny * ny);
    const diagonal = (nx + ny + 2) / 4;

    let r = 18 + (44 - 18) * Math.min(radial, 1);
    let g = 34 + (116 - 34) * Math.min(diagonal, 1);
    let b = 72 + (178 - 72) * Math.min(1 - radial * 0.5 + diagonal * 0.25, 1);

    const glow = Math.max(0, 1 - Math.abs(nx * 0.74 - ny * 0.28) * 1.8);
    r += glow * 16;
    g += glow * 20;
    b += glow * 28;

    setPixel(x, y, clamp(Math.round(r), 0, 255), clamp(Math.round(g), 0, 255), clamp(Math.round(b), 0, 255));
  }
}

for (let y = 0; y < baseSize; y += 1) {
  for (let x = 0; x < baseSize; x += 1) {
    const nx = x / (baseSize - 1);
    const ny = y / (baseSize - 1);
    const highlight = Math.max(0, 1 - ((nx - 0.29) ** 2 * 11 + (ny - 0.17) ** 2 * 30));
    if (highlight > 0) {
      blendPixel(x, y, [255, 255, 255], highlight * 0.24);
    }
  }
}

const panel = { left: 188, top: 188, right: 836, bottom: 836, radius: 188 };
for (let y = panel.top; y <= panel.bottom; y += 1) {
  for (let x = panel.left; x <= panel.right; x += 1) {
    if (insideRoundedRect(x, y, panel.left, panel.top, panel.right, panel.bottom, panel.radius)) {
      blendPixel(x, y, [246, 251, 255], 0.17);
    }
  }
}

const scannerLeft = 306;
const scannerRight = baseSize - scannerLeft;
const scannerTop = 306;
const scannerBottom = baseSize - scannerTop;
const thickness = 28;
const length = 126;
const glowColor = [84, 224, 255];
const lineColor = [228, 252, 255];

for (let dx = 0; dx < length; dx += 1) {
  for (let t = 0; t < thickness; t += 1) {
    const points = [
      [scannerLeft + dx, scannerTop + t],
      [scannerLeft + t, scannerTop + dx],
      [scannerRight - dx, scannerTop + t],
      [scannerRight - t, scannerTop + dx],
      [scannerLeft + dx, scannerBottom - t],
      [scannerLeft + t, scannerBottom - dx],
      [scannerRight - dx, scannerBottom - t],
      [scannerRight - t, scannerBottom - dx],
    ];

    for (const [px, py] of points) {
      for (let oy = -12; oy <= 12; oy += 1) {
        for (let ox = -12; ox <= 12; ox += 1) {
          const dist = Math.sqrt(ox * ox + oy * oy);
          if (dist <= 12) {
            blendPixel(px + ox, py + oy, glowColor, (1 - dist / 12) * 0.18);
          }
        }
      }
      setPixel(px, py, lineColor[0], lineColor[1], lineColor[2], 255);
    }
  }
}

const pattern = [
  "11100110",
  "10011100",
  "10110110",
  "01101001",
  "11010011",
  "00111100",
  "10100101",
  "01110010",
];
const moduleSize = 40;
const originX = 386;
const originY = 386;
for (let row = 0; row < pattern.length; row += 1) {
  for (let col = 0; col < pattern[row].length; col += 1) {
    if (pattern[row][col] !== "1") continue;
    const startX = originX + col * moduleSize;
    const startY = originY + row * moduleSize;
    for (let y = startY; y < startY + moduleSize - 8; y += 1) {
      for (let x = startX; x < startX + moduleSize - 8; x += 1) {
        const inset = Math.min(x - startX, y - startY, startX + moduleSize - 9 - x, startY + moduleSize - 9 - y);
        const color = inset < 5 ? [120, 231, 255] : [248, 253, 255];
        setPixel(x, y, color[0], color[1], color[2], 255);
      }
    }
  }
}

for (let y = 244; y < 428; y += 1) {
  for (let x = 604; x < 788; x += 1) {
    const dx = (x - 696) / 88;
    const dy = (y - 336) / 88;
    const dist = Math.sqrt(dx * dx + dy * dy);
    if (dist < 1) {
      blendPixel(x, y, [255, 255, 255], (1 - dist) * 0.52);
    }
  }
}

function writePng(filePath, width, height, rgba) {
  const scanlines = Buffer.alloc(height * (width * 4 + 1));
  for (let y = 0; y < height; y += 1) {
    const scanlineOffset = y * (width * 4 + 1);
    scanlines[scanlineOffset] = 0;
    rgba.copy(scanlines, scanlineOffset + 1, y * width * 4, (y + 1) * width * 4);
  }

  const header = Buffer.from("\x89PNG\r\n\x1a\n", "binary");
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8;
  ihdr[9] = 6;
  ihdr[10] = 0;
  ihdr[11] = 0;
  ihdr[12] = 0;

  const png = Buffer.concat([
    header,
    writeChunk("IHDR", ihdr),
    writeChunk("IDAT", zlib.deflateSync(scanlines, { level: 9 })),
    writeChunk("IEND", Buffer.alloc(0)),
  ]);

  fs.writeFileSync(filePath, png);
}

function scaleNearest(size) {
  const out = Buffer.alloc(size * size * 4);
  for (let y = 0; y < size; y += 1) {
    const sy = clamp(Math.round(((y + 0.5) * baseSize / size) - 0.5), 0, baseSize - 1);
    for (let x = 0; x < size; x += 1) {
      const sx = clamp(Math.round(((x + 0.5) * baseSize / size) - 0.5), 0, baseSize - 1);
      const src = (sy * baseSize + sx) * 4;
      const dst = (y * size + x) * 4;
      out[dst] = pixels[src];
      out[dst + 1] = pixels[src + 1];
      out[dst + 2] = pixels[src + 2];
      out[dst + 3] = pixels[src + 3];
    }
  }
  return out;
}

const sizes = {
  "AppIcon-20@1x.png": 20,
  "AppIcon-20@2x.png": 40,
  "AppIcon-20@3x.png": 60,
  "AppIcon-29@1x.png": 29,
  "AppIcon-29@2x.png": 58,
  "AppIcon-29@3x.png": 87,
  "AppIcon-40@1x.png": 40,
  "AppIcon-40@2x.png": 80,
  "AppIcon-40@3x.png": 120,
  "AppIcon-60@2x.png": 120,
  "AppIcon-60@3x.png": 180,
  "AppIcon-76@1x.png": 76,
  "AppIcon-76@2x.png": 152,
  "AppIcon-83.5@2x.png": 167,
  "AppIcon-1024@1x.png": 1024,
};

for (const [filename, size] of Object.entries(sizes)) {
  const image = size === baseSize ? pixels : scaleNearest(size);
  writePng(path.join(outDir, filename), size, size, image);
}

console.log("Generated app icons:", Object.keys(sizes).length);
