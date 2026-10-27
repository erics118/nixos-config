// adapted from pi-math's src/transform.ts, https://github.com/monotykamary/pi-math
// MIT License, Copyright (c) 2026 Fadouse

export type Span = {
  start: number;
  end: number;
  tex: string;
  display: boolean;
};

const ENVIRONMENT =
  /^\\begin\{(equation\*?|displaymath|math|align\*?|alignat\*?|flalign\*?|gather\*?|multline\*?|split|aligned|alignedat|gathered|array|matrix|pmatrix|bmatrix|Bmatrix|vmatrix|Vmatrix|cases|CD)\}/;

const isEscaped = (text: string, index: number) => {
  let backslashes = 0;
  for (let i = index - 1; i >= 0 && text[i] === "\\"; i--) backslashes++;
  return backslashes % 2 === 1;
};

const countRun = (text: string, index: number, character: string) => {
  let end = index;
  while (text[end] === character) end++;
  return end - index;
};

// the end of a fenced code block starting here, which a fence still streaming in runs to the end
function skipFencedCode(text: string, index: number) {
  const character = text[index];
  if (character !== "`" && character !== "~") return undefined;
  const lineStart = text.lastIndexOf("\n", index - 1) + 1;
  if (!/^(?:[ \t]*>[ \t]?)*[ \t]*$/.test(text.slice(lineStart, index)))
    return undefined;
  const opening = countRun(text, index, character);
  if (opening < 3) return undefined;

  const openingEnd = text.indexOf("\n", index + opening);
  if (openingEnd < 0) return text.length;
  let next = openingEnd + 1;
  while (next <= text.length) {
    const nextEnd = text.indexOf("\n", next);
    const line = text
      .slice(next, nextEnd < 0 ? text.length : nextEnd)
      .replace(/\r$/, "");
    const close = /^(?:[ \t]*>[ \t]?)*[ \t]*(`+|~+)[ \t]*$/.exec(line)?.[1];
    if (close?.[0] === character && close.length >= opening)
      return nextEnd < 0 ? text.length : nextEnd + 1;
    if (nextEnd < 0) break;
    next = nextEnd + 1;
  }
  return text.length;
}

function skipInlineCode(text: string, index: number) {
  const run = countRun(text, index, "`");
  const marker = "`".repeat(run);
  let from = index + run;
  while (from < text.length) {
    const closing = text.indexOf(marker, from);
    if (closing < 0) return index + run;
    if (text[closing - 1] !== "`" && text[closing + run] !== "`")
      return closing + run;
    from = closing + 1;
  }
  return index + run;
}

function skipHtmlCode(text: string, lower: string, index: number) {
  if (text.startsWith("<!--", index)) {
    const closing = text.indexOf("-->", index + 4);
    return closing < 0 ? text.length : closing + 3;
  }
  const opening = /^<(code|pre)(?:\s|>)/i.exec(text.slice(index));
  if (!opening) return undefined;
  const openingEnd = text.indexOf(">", index + opening[0].length - 1);
  if (openingEnd < 0) return text.length;
  const tag = `</${opening[1]!.toLowerCase()}>`;
  const closing = lower.indexOf(tag, openingEnd + 1);
  return closing < 0 ? text.length : closing + tag.length;
}

function skipTexVerb(text: string, index: number) {
  if (
    !text.startsWith("\\verb", index) ||
    /[A-Za-z]/.test(text[index + 5] ?? "")
  )
    return undefined;
  let cursor = index + 5;
  if (text[cursor] === "*") cursor++;
  const delimiter = text[cursor];
  if (!delimiter || /[A-Za-z0-9\s]/u.test(delimiter)) return undefined;
  const closing = text.indexOf(delimiter, cursor + 1);
  return closing < 0 ? text.length : closing + 1;
}

// skips TeX comments and \verb, so a delimiter inside them does not close the formula
function findUnescaped(text: string, sequence: string, from: number) {
  let index = from;
  while (index < text.length) {
    if (text[index] === "%" && !isEscaped(text, index)) {
      const lineEnd = text.indexOf("\n", index + 1);
      if (lineEnd < 0) return -1;
      index = lineEnd + 1;
      continue;
    }
    if (text[index] === "\\" && !isEscaped(text, index)) {
      const verbEnd = skipTexVerb(text, index);
      if (verbEnd !== undefined) {
        index = verbEnd;
        continue;
      }
    }
    if (text.startsWith(sequence, index) && !isEscaped(text, index))
      return index;
    index++;
  }
  return -1;
}

// a stack of environments, so a nested \end does not close the outer one
function findEnvironmentEnd(text: string, from: number, name: string) {
  const stack = [name];
  let index = from;
  while (index < text.length) {
    if (text[index] === "%" && !isEscaped(text, index)) {
      const lineEnd = text.indexOf("\n", index + 1);
      if (lineEnd < 0) return -1;
      index = lineEnd + 1;
      continue;
    }
    if (text[index] !== "\\" || isEscaped(text, index)) {
      index++;
      continue;
    }
    const verbEnd = skipTexVerb(text, index);
    if (verbEnd !== undefined) {
      index = verbEnd;
      continue;
    }
    const token = /^\\(begin|end)\{([^{}]+)\}/.exec(text.slice(index));
    if (!token) {
      index++;
      continue;
    }
    if (token[1] === "begin") stack.push(token[2]!);
    else if (stack.at(-1) === token[2]) {
      stack.pop();
      if (stack.length === 0) return index + token[0].length;
    }
    index += token[0].length;
  }
  return -1;
}

// a closing $ hugs its formula and is not followed by a digit, so prices stay text
function findDollarCloser(text: string, from: number) {
  for (let index = from; index < text.length; index++) {
    const character = text[index];
    if (character === "\n" || character === "\r") return -1;
    if (character !== "$" || isEscaped(text, index)) continue;
    if (
      text[index + 1] === "$" ||
      text[index - 1] === "$" ||
      /\s/u.test(text[index - 1] ?? "")
    )
      continue;
    if (/\d/u.test(text[index + 1] ?? "")) continue;
    return index;
  }
  return -1;
}

// the fenced code blocks, as [start, end) ranges
export function fences(text: string) {
  const ranges: [number, number][] = [];
  for (let index = 0; index < text.length; index++) {
    const end = skipFencedCode(text, index);
    if (end === undefined) continue;
    ranges.push([text.lastIndexOf("\n", index - 1) + 1, end]);
    index = end - 1;
  }
  return ranges;
}

// the complete formulas outside code, in order
export function mathSpans(text: string) {
  const spans: Span[] = [];
  if (!/\$|\\\(|\\\[|\\begin\{/.test(text)) return spans;
  const lower = text.toLowerCase();
  let index = 0;
  const add = (start: number, end: number, tex: string, display: boolean) => {
    if (tex.trim()) spans.push({ start, end, tex: tex.trim(), display });
    index = end;
  };

  while (index < text.length) {
    const character = text[index]!;
    const fenceEnd = skipFencedCode(text, index);
    if (fenceEnd !== undefined) {
      index = fenceEnd;
      continue;
    }
    if (character === "`") {
      index = skipInlineCode(text, index);
      continue;
    }
    if (character === "<") {
      const htmlEnd = skipHtmlCode(text, lower, index);
      if (htmlEnd !== undefined) {
        index = htmlEnd;
        continue;
      }
    }
    if (character === "\\" && !isEscaped(text, index)) {
      const verbEnd = skipTexVerb(text, index);
      if (verbEnd !== undefined) {
        index = verbEnd;
        continue;
      }
    }

    if (character === "$" && !isEscaped(text, index)) {
      if (text[index + 1] === "$") {
        const closing = findUnescaped(text, "$$", index + 2);
        if (closing >= 0)
          add(index, closing + 2, text.slice(index + 2, closing), true);
        else index += 2;
        continue;
      }
      if (index + 1 < text.length && !/\s/u.test(text[index + 1]!)) {
        const closing = findDollarCloser(text, index + 1);
        const tex = closing >= 0 ? text.slice(index + 1, closing) : "";
        // an unescaped $ inside means this one is a price that ran into a later formula
        if (closing >= 0 && !/(?<!\\)\$/.test(tex)) {
          add(index, closing + 1, tex, false);
          continue;
        }
      }
    }

    if (character === "\\" && !isEscaped(text, index)) {
      const delimiter = text[index + 1];
      if (delimiter === "(" || delimiter === "[") {
        const closing = findUnescaped(
          text,
          delimiter === "(" ? "\\)" : "\\]",
          index + 2,
        );
        if (closing >= 0) {
          add(
            index,
            closing + 2,
            text.slice(index + 2, closing),
            delimiter === "[",
          );
          continue;
        }
      }
      const environment = ENVIRONMENT.exec(text.slice(index));
      if (environment) {
        const end = findEnvironmentEnd(
          text,
          index + environment[0].length,
          environment[1]!,
        );
        if (end >= 0) {
          add(index, end, text.slice(index, end), environment[1] !== "math");
          continue;
        }
      }
    }
    index++;
  }
  return spans;
}
