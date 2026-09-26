import assert from "node:assert/strict";
import test from "node:test";
import { codeToANSI } from "../src/shiki.js";

test("local Shiki adapter renders TypeScript as ANSI", async () => {
  const output = await codeToANSI("const answer = 42;", "typescript", "github-dark");

  const plain = output.replace(/\x1b\[[0-9;]*m/g, "");

  assert.match(plain, /const answer = 42;/);
  assert.match(output, /\x1b\[38;2;\d+;\d+;\d+m/);
});
