#!/usr/bin/env node
// reads {fg, columns, macros, cache, items: [{tex, mode}]} as json on stdin
// writes one {file, columns, rows} or {error} per item as a json array on stdout
import { execFile } from "node:child_process";
import { createHash } from "node:crypto";
import { mkdir, readFile, rename, rm, writeFile } from "node:fs/promises";
import { createRequire } from "node:module";
import { text } from "node:stream/consumers";
import { promisify } from "node:util";

const run = promisify(execFile);
const require = createRequire(import.meta.url);

// a terminal cell is half as wide as it is tall
// a row of text is this many em of math, so math's x-height matches the prose around it
const EM_PER_ROW = 1.04;
const ROW_PX = 50;
const MAX_PX = 4096;
const MAX_CELLS = 255;
const MAX_TEX = 20_000;
// clear space around the ink, in em
const PAD = 0.04;
// inline math that stacks one thing over another gets two full-size rows
const STACKED =
  /\\([dt]?frac|binom|over|atop|choose|substack|stackrel|overset|underset|begin)\b|\\(sum|prod|coprod|int|iint|iiint|oint|bigcup|bigcap|lim)\b\s*[_^]/;
// mathjax's svg leans on these rules of its stylesheet for table lines and glyph weight
const STYLE = `
g[data-mml-node="mtable"] > line[data-line], g[data-mml-node="mtable"] > rect[data-frame] { stroke-width: 70px; fill: none; }
g[data-mml-node="mtable"] > .mjx-dashed { stroke-dasharray: 140; }
g[data-mml-node="mtable"] > .mjx-dotted { stroke-linecap: round; stroke-dasharray: 0,140; }
path[data-c], use[data-c] { stroke-width: 3; }
`;

const input = JSON.parse(await text(process.stdin));
const macros = await readFile(input.macros, "utf8");
// the helper's own path names its build, so a new build draws everything again
const version = hash(`${import.meta.url}:${macros}`);
await mkdir(input.cache, { recursive: true });

let mathjax;
const typeset = async (tex, display) => {
  mathjax ??= start();
  const mj = await mathjax;
  const node = await mj.tex2svgPromise(tex, { display });
  return mj.startup.adaptor.innerHTML(node);
};

const results = [];
for (const item of input.items) {
  results.push(
    await draw(item).catch((e) => ({ error: String(e.message ?? e) })),
  );
}
process.stdout.write(JSON.stringify(results));

async function draw({ tex, mode }) {
  if (tex.length > MAX_TEX) throw new Error("formula too long");
  const key = hash(
    JSON.stringify([version, input.fg, input.columns, mode, tex]),
  );
  const file = `${input.cache}/${key}.png`;
  const meta = await readFile(`${file}.json`, "utf8").then(
    JSON.parse,
    () => null,
  );
  if (meta) return { file, ...meta };

  const svg = await typeset(normalize(tex), mode === "display");
  // glyphs mathjax's font lacks come out as text in some other font, which resvg would guess at
  if (/<text\b/.test(svg)) throw new Error("glyph outside the math font");
  const box = svg.match(/viewBox="([-\d.]+) ([-\d.]+) ([-\d.]+) ([-\d.]+)"/);
  if (!box) throw new Error("svg without a viewBox");
  const [x0, y0, w0, h0] = box.slice(1).map(Number);
  // drawn at one px per unit, so resvg's bounds come back in mathjax's units, 1000 to the em
  const body = svg
    .replace(/ data-latex="[^"]*"/g, "")
    .replace(/<svg[^>]*>/, "")
    .replace(/<\/svg>\s*$/, "");
  const ink = await bounds(body, x0, y0, w0, h0);
  const left = Math.min(x0, ink.x) / 1000 - PAD;
  const top = Math.min(y0, ink.y) / 1000 - PAD;
  const width = Math.max(x0 + w0, ink.x + ink.w) / 1000 + PAD - left;
  const height = Math.max(y0 + h0, ink.y + ink.h) / 1000 + PAD - top;

  const row = 1 / EM_PER_ROW;
  const col = row / 2;
  let scale = Math.min(
    1,
    (input.columns * col) / width,
    (MAX_CELLS * row) / height,
  );
  // inline math shrinks to one row unless it stacks or would drop below about 70% size
  const tall = height * scale;
  if (
    mode === "inline" &&
    !STACKED.test(tex) &&
    tall > row &&
    tall <= 1.45 * row
  )
    scale *= row / tall;
  const columns = Math.max(1, Math.ceil((width * scale) / col));
  const rows = Math.max(1, Math.ceil((height * scale) / row));
  const rowPx = Math.min(
    ROW_PX,
    Math.floor(MAX_PX / Math.max(columns / 2, rows)),
  );

  // the picture fills whole cells, with the ink centered in them
  const vw = (columns * col) / scale;
  const vh = (rows * row) / scale;
  const vx = (left + width / 2 - vw / 2) * 1000;
  const vy = (top + height / 2 - vh / 2) * 1000;
  const out = `<svg xmlns="http://www.w3.org/2000/svg" width="${(columns * rowPx) / 2}" height="${rows * rowPx}" viewBox="${vx} ${vy} ${vw * 1000} ${vh * 1000}" color="${input.fg}"><style>${STYLE}</style>${body}</svg>`;

  const tmp = `${file}.${process.pid}`;
  await writeFile(`${tmp}.svg`, out);
  try {
    await run("resvg", [`${tmp}.svg`, tmp]);
    await rename(tmp, file);
  } finally {
    await rm(`${tmp}.svg`, { force: true });
  }
  await writeFile(`${tmp}.json`, JSON.stringify({ columns, rows }));
  await rename(`${tmp}.json`, `${file}.json`);
  return { file, columns, rows };
}

// the ink's box, which can reach past mathjax's own box, as with a CD diagram's left labels
async function bounds(body, x0, y0, w0, h0) {
  const tmp = `${input.cache}/${process.pid}-${Math.random().toString(36).slice(2)}.svg`;
  await writeFile(
    tmp,
    `<svg xmlns="http://www.w3.org/2000/svg" width="${w0}" height="${h0}" viewBox="${x0} ${y0} ${w0} ${h0}"><style>${STYLE}</style><g id="ink">${body}</g></svg>`,
  );
  try {
    const { stdout } = await run("resvg", ["--query-all", tmp]);
    const [, x, y, w, h] =
      stdout
        .match(/^ink,(.*)$/m)?.[0]
        .split(",")
        .map(Number) ?? [];
    if (w === undefined) return { x: x0, y: y0, w: w0, h: h0 };
    return { x: x + x0, y: y + y0, w, h };
  } finally {
    await rm(tmp, { force: true });
  }
}

async function start() {
  const mj = require("mathjax");
  await mj.init({
    loader: {
      load: [
        "input/tex",
        "output/svg",
        "[tex]/physics",
        "[tex]/amscd",
        "[tex]/mathtools",
        "[tex]/cancel",
      ],
    },
    tex: {
      // without noundefined, an unknown macro fails instead of drawing its name in red
      packages: {
        "[+]": ["physics", "amscd", "mathtools", "cancel"],
        "[-]": ["noundefined"],
      },
      maxBuffer: MAX_TEX,
      maxMacros: 1000,
      // a formula mathjax cannot read fails alone instead of drawing its error box
      formatError: (_, err) => {
        throw err;
      },
    },
    // inline math is one picture, so mathjax must not break it into several svgs
    svg: { fontCache: "none", linebreaks: { inline: false } },
  });
  // the macros persist across formulas, so one typeset defines them all
  await mj.tex2svgPromise(macros, { display: true });
  return mj;
}

// a tag becomes a visible label beside the formula, since a numbered equation would fill the width
function normalize(tex) {
  return tex
    .replace(/\\label\s*\{[^{}]*\}/g, "")
    .replace(/\\tag\*\s*\{([^{}]*)\}/g, "\\qquad\\mathrm{$1}")
    .replace(/\\tag\s*\{([^{}]*)\}/g, "\\qquad\\mathrm{($1)}")
    .replace(/\\(?:notag|nonumber)\b/g, "")
    .trim();
}

function hash(s) {
  return createHash("sha256").update(s).digest("hex").slice(0, 32);
}
