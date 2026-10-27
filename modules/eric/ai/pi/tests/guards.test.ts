import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import {
  chmodSync,
  mkdirSync,
  mkdtempSync,
  renameSync,
  rmSync,
  symlinkSync,
  writeFileSync,
} from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";

// guards.ts reads $HOME once at import, so the fake home must be set first
const home = mkdtempSync(path.join(os.tmpdir(), "pi-guards-home-"));
process.env.HOME = home;
mkdirSync(path.join(home, ".agents"));
const hooksLink = path.join(home, ".agents", "hooks");
symlinkSync(path.resolve(import.meta.dirname, "../../hooks"), hooksLink);
const repo = mkdtempSync(path.join(os.tmpdir(), "pi-guards-repo-"));
execFileSync("git", ["init", "-q", repo]);
// commits pass the commit gate, so the attribution rewrite shows
execFileSync("git", ["-C", repo, "config", "eric-agent.commit", "on"]);

const module = await import("../extensions/guards.ts");
const handlers = new Map<
  string,
  (event: unknown, ctx: unknown) => Promise<unknown>
>();
module.default({
  on: (event, handler) => handlers.set(event, handler as never),
} as never);

// runs fn with ~/.agents/hooks swapped for a dir holding only the given guard.sh, or none
async function withGuard(script: string | undefined, fn: () => Promise<void>) {
  const dir = mkdtempSync(path.join(os.tmpdir(), "pi-guards-fake-"));
  if (script !== undefined) {
    writeFileSync(path.join(dir, "guard.sh"), script);
    chmodSync(path.join(dir, "guard.sh"), 0o755);
  }
  renameSync(hooksLink, `${hooksLink}.real`);
  symlinkSync(dir, hooksLink);
  try {
    await fn();
  } finally {
    rmSync(hooksLink);
    renameSync(`${hooksLink}.real`, hooksLink);
  }
}

function bash(command: string, ui?: boolean) {
  const event = { toolName: "bash", input: { command } };
  return {
    event,
    result: handlers.get("tool_call")!(event, {
      cwd: repo,
      hasUI: ui !== undefined,
      ui: { confirm: async () => ui },
    }),
  };
}

test("blocks a command a hook denies", async () => {
  const result = (await bash("git push").result) as {
    block: boolean;
    reason: string;
  };
  assert.equal(result.block, true);
  assert.match(result.reason, /Agent pushes are off/);
});

test("passes a command every hook allows", async () => {
  assert.equal(await bash("git status").result, undefined);
});

test("an ask blocks without a UI and follows the user's answer with one", async () => {
  assert.equal(
    ((await bash("git reset --hard").result) as { block: boolean }).block,
    true,
  );
  assert.equal(
    ((await bash("git reset --hard", false).result) as { block: boolean })
      .block,
    true,
  );
  assert.equal(await bash("git reset --hard", true).result, undefined);
});

test("applies a hook's rewritten command", async () => {
  const { event, result } = bash(
    "git commit -m 'x\nCo-Authored-By: Claude <noreply@anthropic.com>'",
  );
  assert.equal(await result, undefined);
  assert.doesNotMatch(event.input.command, /Co-Authored-By/);
  assert.match(event.input.command, /^git commit -m 'x\n/);
});

test("checks file tools under their Claude Code names", async () => {
  const emDash = String.fromCharCode(0x2014);
  const result = (await handlers.get("tool_call")!(
    {
      toolName: "write",
      input: { path: "new.txt", content: `dash: ${emDash}` },
    },
    { cwd: repo, hasUI: false },
  )) as { block: boolean; reason: string };
  assert.equal(result.block, true);
  assert.match(result.reason, /smart punctuation/);
});

test("fails closed when guard.sh is missing", async () => {
  await withGuard(undefined, async () => {
    const result = (await bash("git status").result) as {
      block: boolean;
      reason: string;
    };
    assert.equal(result.block, true);
    assert.match(result.reason, /guard\.sh failed/);
  });
});

test("fails closed when guard.sh prints output that is not JSON", async () => {
  await withGuard("#!/bin/sh\necho nope\n", async () => {
    const result = (await bash("git status").result) as {
      block: boolean;
      reason: string;
    };
    assert.equal(result.block, true);
    assert.match(result.reason, /not JSON/);
  });
});

test("adds PostToolUse hook warnings to the tool result", async () => {
  const file = path.join(repo, "comments.ts");
  const text = "code\n// one\n// two\n// three\n// four\n";
  writeFileSync(file, text);
  const result = (await handlers.get("tool_result")!(
    {
      toolName: "write",
      input: { path: "comments.ts", content: text },
      content: [{ type: "text", text: "wrote" }],
    },
    { cwd: repo },
  )) as { content: { text: string }[] };
  assert.equal(result.content.length, 2);
  assert.match(result.content[1].text, /comment block of 4 lines/);
});
