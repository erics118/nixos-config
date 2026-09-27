import assert from "node:assert/strict";
import test from "node:test";
import type { Theme } from "@earendil-works/pi-coding-agent";
import { CURSOR_MARKER, Input } from "@earendil-works/pi-tui";
import {
  BTW_OVERLAY_OPTIONS,
  isBtwForkShortcut,
  renderBtwInput,
  renderBtwTurn,
} from "../extensions/side-conversations.ts";

const theme = {
  fg: (_color: string, text: string) => text,
  bold: (text: string) => text,
} as Theme;

test("anchors the drawer to the terminal bottom and captures input", () => {
  assert.equal(BTW_OVERLAY_OPTIONS.margin.bottom, 0);
  assert.equal(BTW_OVERLAY_OPTIONS.nonCapturing, false);
});

test("forks on bare f only after an answer with an empty composer", () => {
  assert.equal(isBtwForkShortcut("f", "", "complete"), true);
  assert.equal(isBtwForkShortcut("f", "draft", "complete"), false);
  assert.equal(isBtwForkShortcut("f", "", "pending"), false);
  assert.equal(isBtwForkShortcut("x", "", "complete"), false);
});

test("uses only the configured hardware cursor when focused", () => {
  const input = new Input();
  input.focused = true;
  input.setValue("draft");
  const rendered = renderBtwInput(input.render(20)[0] ?? "");

  assert.equal(rendered.includes(CURSOR_MARKER), true);
  assert.equal(rendered.includes("\x1b[7m"), false);
});

test("renders the native working indicator for an unanswered turn", () => {
  const lines = renderBtwTurn(
    { id: "turn-1", question: "what failed?", status: "pending", answer: "" },
    40,
    theme,
    "⠋ Answering",
  );

  assert.equal(lines.includes("  ⠋ Answering"), true);
  assert.equal(
    lines.some((line) => line.includes("Answering...")),
    false,
  );
});
