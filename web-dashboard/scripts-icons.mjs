import sharp from "sharp";
import { readFile } from "node:fs/promises";
const svg = await readFile("public/icon.svg");
for (const [name, size] of [
  ["icon-192.png", 192],
  ["icon-512.png", 512],
  ["apple-icon.png", 180],
])
  await sharp(svg)
    .resize(size, size)
    .png()
    .toFile("public/" + name);
