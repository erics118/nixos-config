import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import {
  chmodSync,
  mkdirSync,
  mkdtempSync,
  symlinkSync,
  writeFileSync,
} from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";

// guards.ts reads $HOME once at import, so the fake home must be set first
const home = mkdtempSync(path.join(os.tmpdir(), "pi-guards-home-"));
process.env.HOME = home;
mkdirSync(path.join(home, ".claude"));
mkdirSync(path.join(home, ".agents"));
symlinkSync(
  path.resolve(import.meta.dirname, "../../hooks"),
  path.join(home, ".agents", "hooks"),
);
const repo = mkdtempSync(path.join(os.tmpdir(), "pi-guards-repo-"));
execFileSync("git", ["init", "-q", repo]);

const module = await import("../extensions/guards.ts");
const handlers = new Map<
  string,
  (event: unknown, ctx: unknown) => Promise<unknown>
>();
module.default({
  on: (event, handler) => handlers.set(event, handler as never),
} as never);

function useHooks(event: string, matcher: string, commands: string[]) {
  writeFileSync(
    path.join(home, ".claude", "settings.json"),
    JSON.stringify({
      hooks: {
        [event]: [{ matcher, hooks: commands.map((command) => ({ command })) }],
      },
    }),
  );
}

const bashHooks = [
  '"$HOME/.agents/hooks/block-agent-push.sh"',
  '"$HOME/.agents/hooks/ask-dangerous-git.sh"',
  '"$HOME/.agents/hooks/strip-claude-attribution.sh"',
];

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
  useHooks("PreToolUse", "Bash", bashHooks);
  const result = (await bash("git push").result) as {
    block: boolean;
    reason: string;
  };
  assert.equal(result.block, true);
  assert.match(result.reason, /Agent pushes are off/);
});

test("passes a command every hook allows", async () => {
  useHooks("PreToolUse", "Bash", bashHooks);
  assert.equal(await bash("git status").result, undefined);
});

test("an ask blocks without a UI and follows the user's answer with one", async () => {
  useHooks("PreToolUse", "Bash", bashHooks);
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
  useHooks("PreToolUse", "Bash", bashHooks);
  const { event, result } = bash(
    "git commit -m 'x\nCo-Authored-By: Claude <noreply@anthropic.com>'",
  );
  assert.equal(await result, undefined);
  assert.doesNotMatch(event.input.command, /Co-Authored-By/);
});

test("skips hooks whose matcher does not name the tool", async () => {
  useHooks("PreToolUse", "Write", [
    '"$HOME/.agents/hooks/block-agent-push.sh"',
  ]);
  assert.equal(await bash("git push").result, undefined);
});

test("fails closed when a hook script is missing", async () => {
  useHooks("PreToolUse", "Bash", ['"$HOME/.agents/hooks/missing.sh"']);
  const result = (await bash("git status").result) as {
    block: boolean;
    reason: string;
  };
  assert.equal(result.block, true);
  assert.match(result.reason, /missing\.sh failed/);
});

test("fails closed when a hook prints output that is not JSON", async () => {
  const script = path.join(home, "bad-json.sh");
  writeFileSync(script, "#!/bin/sh\necho nope\n");
  chmodSync(script, 0o755);
  useHooks("PreToolUse", "Bash", [script]);
  const result = (await bash("git status").result) as {
    block: boolean;
    reason: string;
  };
  assert.equal(result.block, true);
  assert.match(result.reason, /not JSON/);
});

test("fails closed when settings.json cannot be read", async () => {
  writeFileSync(path.join(home, ".claude", "settings.json"), "{");
  await assert.rejects(bash("git status").result);
});

test("adds PostToolUse hook warnings to the tool result", async () => {
  useHooks("PostToolUse", "Write|Edit", [
    '"$HOME/.agents/hooks/warn-comment-block.sh"',
  ]);
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
