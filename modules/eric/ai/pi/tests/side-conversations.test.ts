import assert from "node:assert/strict";
import test from "node:test";

test("builds a tmux-only side session command with shell-safe values", async () => {
  const module = await import("../lib/side-session.ts").catch(() => undefined);
  assert.ok(module, "side session launcher is not implemented");
  const launch = module.buildTmuxLaunch({
    cwd: "/tmp/project with space",
    sessionPath: "/tmp/session's file.jsonl",
    name: "side-123",
    prompt: "check 'this'",
  });
  assert.deepEqual(launch.args.slice(0, 4), [
    "split-window",
    "-h",
    "-c",
    "/tmp/project with space",
  ]);
  assert.match(launch.args[4], /^pi --session /);
  assert.match(launch.args[4], /'"'"'/);
  assert.equal(launch.command, "tmux");
});

test("passes option-like prompts after the CLI option terminator", async () => {
  const module = await import("../lib/side-session.ts");
  const launch = module.buildTmuxLaunch({
    cwd: "/tmp/project",
    sessionPath: "/tmp/session.jsonl",
    name: "side-123",
    prompt: "--help",
  });
  assert.match(launch.args[4], / -- '--help'$/);
});
