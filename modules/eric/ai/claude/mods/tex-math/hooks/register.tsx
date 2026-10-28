import type { EngineInterface, Register, RenderChildren } from "claude-code";
import { fences, mathSpans, type Span } from "./scan";

type Rendered = { file: string; columns: number; rows: number };
type Chunk = { text: string; fence: boolean; spans: Span[] };

// reply text is the terminal's default color, which a mod cannot read
// these are catppuccin mocha's and latte's text colors
const DARK_FG = "#cdd6f4";
const LIGHT_FG = "#4c4f69";

// an inline formula waits in the prose as its index between two private-use marks
const MARK = /(\d+)/;
// the inline markdown a reply uses: code, bold, italic, strikethrough, links
const SPAN =
  /`([^`]+)`|\*\*(.+?)\*\*|(?<![\w*])[*_](?=\S)(.+?)(?<=\S)[*_](?![\w*])|~~(.+?)~~|\[([^\]]+)\]\(([^)\s]+)\)/g;
const LIST = /^(\s*)([-*+]|\d+[.)])\s+/;
const HEADING = /^#{1,6}\s+/;
const QUOTE = /^>\s?/;
// how long a failed helper keeps formulas as plain text before another try
const RETRY_MS = 60_000;

// the reply cut at its code fences, each other piece with its formulas
const chunks = (text: string) => {
  const out: Chunk[] = [];
  let last = 0;
  const tail: [number, number] = [text.length, text.length];
  for (const [start, end] of [...fences(text), tail]) {
    const prose = text.slice(last, start);
    if (prose) out.push({ text: prose, fence: false, spans: mathSpans(prose) });
    if (end > start)
      out.push({ text: text.slice(start, end), fence: true, spans: [] });
    last = end;
  }
  return out;
};

export const register: Register = (on) => {
  let failedAt = -Infinity;
  const cache = new Map<string, Promise<Rendered | null>>();

  on("ui.render", { component: "AssistantMessage" }, async ($, e, next) => {
    if (e.surface !== "terminal" || Date.now() - failedAt < RETRY_MS)
      return next(e);
    const parts = chunks(e.props.text);
    const spans = parts.flatMap((c) => c.spans);
    if (!spans.length) return next(e);
    const { Box, Text, Markdown, Image } = $.ui.resolve(e);

    const home = (await $.env.get("HOME")) ?? "/tmp";
    const fg = await textColor($, home);
    const columns = Math.max(1, Math.min((e.viewport?.columns ?? 80) - 4, 255));
    const mode = (s: Span) => (s.display ? "display" : "inline");
    const key = (s: Span) => `${fg}:${columns}:${mode(s)}:${s.tex}`;

    // one helper run draws a batch, shrinking a formula wider than the columns
    const draw = (batch: Span[]) => {
      const run = $.process
        .run(["tex-math-render"], {
          stdin: JSON.stringify({
            fg,
            columns,
            macros: `${$.plugin.root}/hooks/macros.tex`,
            cache: `${home}/.cache/tex-math`,
            items: batch.map((s) => ({ tex: s.tex, mode: mode(s) })),
          }),
          timeoutMs: 120_000,
        })
        .then((r) => {
          if (r.exitCode !== 0) {
            failedAt = Date.now();
            throw new Error(`tex-math-render failed: ${r.stderr}`);
          }
          return JSON.parse(r.stdout) as (Rendered | { error: string })[];
        });
      return batch.map((s, i) => {
        const p = run.then((rs) => {
          const r = rs[i];
          return r && "file" in r ? r : null;
        });
        // awaited later, so a rejection here is not unhandled
        p.catch(() => {});
        cache.set(key(s), p);
        return p;
      });
    };

    const todo = new Map<string, Span>();
    for (const s of spans) if (!cache.has(key(s))) todo.set(key(s), s);
    if (todo.size) draw([...todo.values()]);

    // a newer render aborts this one's helper run, so a shared result may reject
    // then the entry is dropped and this render draws those formulas itself
    const drawn = new Map<string, Rendered | null>();
    const retry = new Map<string, Span>();
    for (const s of spans) {
      if (drawn.has(key(s)) || retry.has(key(s))) continue;
      try {
        drawn.set(key(s), await cache.get(key(s))!);
      } catch {
        cache.delete(key(s));
        retry.set(key(s), s);
      }
    }
    if (retry.size) {
      const batch = [...retry.values()];
      const results = draw(batch);
      for (const [i, s] of batch.entries())
        drawn.set(key(s), await results[i]!);
    }

    // a file source keeps the pictures out of the tree's 2 MiB of image bytes
    const image = (r: Rendered, alt: string) => (
      <Image
        source={{ file: r.file, format: "png" }}
        columns={r.columns}
        rows={r.rows}
        alt={alt}
      />
    );

    // a line with inline math becomes a wrapping row of words and pictures
    const line = (src: string, marks: [Rendered, string][]) => {
      const parts: RenderChildren[] = [];
      const words = (s: string, style: Record<string, unknown> = {}) => {
        // split leaves each mark's index at an odd position
        for (const [i, piece] of s.split(MARK).entries()) {
          if (i % 2 === 1) {
            const [r, alt] = marks[Number(piece)]!;
            parts.push(image(r, alt));
            continue;
          }
          for (const word of piece
            .replace(/\\([\\`*_{}[\]()#+\-.!$~])/g, "$1")
            .split(/(?<=\s)/)) {
            if (word) parts.push(<Text {...style}>{word}</Text>);
          }
        }
      };
      // bold, italic, strikethrough and link text can hold math, so they recurse
      const spans = (s: string, style: Record<string, unknown>) => {
        let last = 0;
        for (const m of s.matchAll(SPAN)) {
          words(s.slice(last, m.index), style);
          last = m.index + m[0].length;
          const [, code, bold, italic, strike, label, href] = m;
          if (code !== undefined)
            parts.push(<Text color="permission">{code}</Text>);
          else if (bold !== undefined)
            spans(bold, { ...style, weight: "semibold" });
          else if (italic !== undefined)
            spans(italic, { ...style, italic: true });
          else if (strike !== undefined)
            spans(strike, { ...style, strikethrough: true });
          else if (href !== undefined) {
            spans(label ?? "", style);
            words(` (${href})`, style);
          }
        }
        words(s.slice(last), style);
      };
      let rest = src;
      const quote = rest.match(QUOTE);
      if (quote) {
        parts.push(<Text dimColor>{"│ "}</Text>);
        rest = rest.slice(quote[0].length);
      }
      const list = rest.match(LIST);
      const heading = rest.match(HEADING);
      const base = heading ? { weight: "semibold" } : {};
      if (list) {
        parts.push(
          <Text>{`${list[1]}${/\d/.test(list[2] ?? "") ? list[2] : "-"} `}</Text>,
        );
        rest = rest.slice(list[0].length);
      } else if (heading) {
        rest = rest.slice(heading[0].length);
      }
      spans(rest, base);
      return (
        <Box flexDirection="row" flexWrap="wrap">
          {parts}
        </Box>
      );
    };

    const prose = (text: string, marks: [Rendered, string][]) =>
      text
        .split(/\n{2,}/)
        .filter((para) => para.trim())
        .map((para) =>
          MARK.test(para) ? (
            <Box flexDirection="column">
              {para.split("\n").map((src) => line(src, marks))}
            </Box>
          ) : (
            <Markdown text={para} />
          ),
        );

    const blocks: RenderChildren[] = [];
    for (const chunk of parts) {
      if (chunk.fence) {
        // a fence nested in a list keeps its indent
        const indent = chunk.text.length - chunk.text.trimStart().length;
        const body = chunk.text.replace(
          new RegExp(`^[ \\t]{0,${indent}}`, "gm"),
          "",
        );
        blocks.push(
          <Box paddingLeft={indent}>
            <Markdown text={body} />
          </Box>,
        );
        continue;
      }
      // a formula that did not draw stays in the prose as its source
      const marks: [Rendered, string][] = [];
      let text = "";
      let last = 0;
      for (const s of chunk.spans) {
        const r = drawn.get(key(s));
        const src = chunk.text.slice(s.start, s.end);
        text += chunk.text.slice(last, s.start);
        last = s.end;
        if (!r) text += src;
        else if (!s.display) text += `${marks.push([r, src]) - 1}`;
        else {
          blocks.push(...prose(text, marks));
          text = "";
          blocks.push(<Box justifyContent="center">{image(r, src)}</Box>);
        }
      }
      blocks.push(...prose(text + chunk.text.slice(last), marks));
    }

    const body = (
      <Box flexDirection="column" gap={1} flexShrink={1}>
        {blocks}
      </Box>
    );
    if (!e.props.isFirstOfReply) return <Box paddingLeft={2}>{body}</Box>;
    return (
      <Box flexDirection="row">
        <Text>{"⏺ "}</Text>
        {body}
      </Box>
    );
  }).catch(($, e, next) => next(e));
};

// a custom theme's own text color wins, else the theme's light or dark base picks one
async function textColor($: EngineInterface, home: string) {
  const theme = String(
    (await $.config.list()).find((row) => row.key === "theme")?.value ?? "dark",
  );
  let base = theme;
  if (theme.startsWith("custom:")) {
    try {
      const file = JSON.parse(
        await $.fs.read(`${home}/.claude/themes/${theme.slice(7)}.json`),
      );
      if (/^#[0-9a-f]{6}$/i.test(file.overrides?.text ?? ""))
        return file.overrides.text as string;
      base = String(file.base ?? "dark");
    } catch {}
  }
  return base.includes("light") ? LIGHT_FG : DARK_FG;
}
