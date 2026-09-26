import assert from "node:assert/strict";
import test from "node:test";
import { parseDiff } from "../src/core/diff.js";
import { renderUnified, resolveDiffColors } from "../src/review/hunk-preview.js";

test("shared diff renderer does not reset Pi's tool background", async () => {
  const diff = parseDiff(
    "const before = 1;\nconst value = 1;\nconst after = 1;\n",
    "const before = 1;\nconst value = 2;\nconst after = 1;\n",
  );
  const successBackground = "\x1b[48;2;12;34;56m";
  const theme = {
    bg: (_name: string, text: string) => `${successBackground}${text}\x1b[0m`,
  };
  const output = await renderUnified(diff, "typescript", diff.lines.length, resolveDiffColors(theme), 120);

  assert.ok(output.includes(successBackground));
  assert.ok(!output.includes("\x1b[49m"));
});
