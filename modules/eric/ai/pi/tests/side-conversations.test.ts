import assert from "node:assert/strict";
import test from "node:test";
import { parseSideArgs } from "../lib/side-session.ts";

test("defaults to fork with no text", () => {
  assert.deepEqual(parseSideArgs(""), { mode: "fork", text: "" });
  assert.deepEqual(parseSideArgs("   "), { mode: "fork", text: "" });
});

test("splits the mode from the rest of the text", () => {
  assert.deepEqual(parseSideArgs("fork what is  x?"), {
    mode: "fork",
    text: "what is  x?",
  });
  assert.deepEqual(parseSideArgs("handoff   add a test "), {
    mode: "handoff",
    text: "add a test",
  });
  assert.deepEqual(parseSideArgs("new"), { mode: "new", text: "" });
});

test("keeps an unknown first word as the mode, so agent-side can reject it", () => {
  assert.deepEqual(parseSideArgs("bogus thing"), {
    mode: "bogus",
    text: "thing",
  });
});
