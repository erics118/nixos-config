import { spawn } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const home = process.env.HOME ?? "~";

type HookGroup = { matcher?: string; hooks?: { command?: string }[] };

// the hook scripts Claude Code's settings.json runs for this tool, so both agents share one list.
// read on every call so edits apply at once. a failed read throws, and pi then blocks the tool
function hooksFor(
  event: "PreToolUse" | "PostToolUse",
  toolName: string,
): string[] {
  const settings = JSON.parse(
    fs.readFileSync(path.join(home, ".claude", "settings.json"), "utf8"),
  );
  const groups: HookGroup[] = settings.hooks?.[event] ?? [];
  return groups
    .filter(
      (g) =>
        !g.matcher ||
        g.matcher === "*" ||
        new RegExp(`^(?:${g.matcher})$`).test(toolName),
    )
    .flatMap((g) => g.hooks ?? [])
    .map((h) => (h.command ?? "").replace(/^"|"$/g, "").replace("$HOME", home))
    .filter(Boolean);
}

type HookEvent = {
  cwd: string;
  tool_name: string;
  tool_input: Record<string, unknown>;
};
type Run = { status: number | null; stdout: string; stderr: string };
type Outcome = {
  deny?: string;
  ask?: string;
  command?: string;
  context: string[];
};

function runHook(script: string, event: HookEvent): Promise<Run> {
  return new Promise((resolve) => {
    const child = spawn(script, { cwd: event.cwd });
    let stdout = "";
    let stderr = "";
    child.stdout.on("data", (d) => (stdout += d));
    child.stderr.on("data", (d) => (stderr += d));
    child.on("error", (e) =>
      resolve({ status: null, stdout, stderr: String(e) }),
    );
    child.on("close", (status) => resolve({ status, stdout, stderr }));
    // a hook may exit without reading its input, and close still judges it
    child.stdin.on("error", () => {});
    child.stdin.end(JSON.stringify(event));
  });
}

// run hooks in parallel and combine them as Claude Code does: a deny beats an ask.
// before a tool runs, a hook that fails or prints bad output blocks the call
async function runHooks(
  names: string[],
  event: HookEvent,
  pre: boolean,
): Promise<Outcome> {
  const runs = await Promise.all(names.map((n) => runHook(n, event)));
  const out: Outcome = { context: [] };
  runs.forEach((run, i) => {
    const name = path.basename(names[i]);
    const problem = (msg: string) =>
      pre ? (out.deny ??= msg) : out.context.push(msg);
    if (run.status === 2) return problem(run.stderr.trim());
    if (run.status !== 0)
      return problem(`${name} failed, so the call was not checked`);
    if (!run.stdout.trim()) return;
    let d;
    try {
      d = JSON.parse(run.stdout)?.hookSpecificOutput ?? {};
    } catch {
      return problem(`${name} printed output that is not JSON`);
    }
    if (d.permissionDecision === "deny")
      out.deny ??= d.permissionDecisionReason ?? `${name} blocked this`;
    if (d.permissionDecision === "ask") out.ask ??= d.permissionDecisionReason;
    if (typeof d.updatedInput?.command === "string")
      out.command = d.updatedInput.command;
    if (d.additionalContext) out.context.push(d.additionalContext);
  });
  return out;
}

// pi's tool calls in the shape the hooks read (Claude Code's tool names and fields)
function toHookEvent(
  toolName: string,
  input: Record<string, unknown>,
  cwd: string,
): HookEvent | undefined {
  const file = (p: unknown) =>
    typeof p === "string"
      ? path.resolve(cwd, p.replace(/^~(?=$|\/)/, home))
      : undefined;
  switch (toolName) {
    case "bash":
      return { cwd, tool_name: "Bash", tool_input: { command: input.command } };
    case "read":
      return {
        cwd,
        tool_name: "Read",
        tool_input: { file_path: file(input.path) },
      };
    case "write":
      return {
        cwd,
        tool_name: "Write",
        tool_input: { file_path: file(input.path), content: input.content },
      };
    case "edit": {
      const edits = Array.isArray(input.edits) ? input.edits : [];
      return {
        cwd,
        tool_name: "Edit",
        tool_input: {
          file_path: file(input.path),
          edits: edits.map((e: { oldText?: string; newText?: string }) => ({
            old_string: e.oldText,
            new_string: e.newText,
          })),
        },
      };
    }
    default:
      return undefined;
  }
}

export default function guards(pi: ExtensionAPI): void {
  pi.on("tool_call", async (event, ctx) => {
    const hookEvent = toHookEvent(event.toolName, event.input, ctx.cwd);
    if (!hookEvent) return undefined;
    const out = await runHooks(
      hooksFor("PreToolUse", hookEvent.tool_name),
      hookEvent,
      true,
    );
    if (out.deny !== undefined)
      return { block: true, reason: out.deny || "blocked by a guard hook" };
    if (out.ask !== undefined) {
      const reason = out.ask || "a guard hook asks for approval";
      const ok = ctx.hasUI && (await ctx.ui.confirm("Guard hook", reason));
      if (!ok) return { block: true, reason };
    }
    if (out.command !== undefined) event.input.command = out.command;
    return undefined;
  });

  pi.on("tool_result", async (event, ctx) => {
    const hookEvent = toHookEvent(event.toolName, event.input, ctx.cwd);
    if (!hookEvent) return undefined;
    const out = await runHooks(
      hooksFor("PostToolUse", hookEvent.tool_name),
      hookEvent,
      false,
    );
    if (out.context.length === 0) return undefined;
    return {
      content: [
        ...event.content,
        { type: "text", text: out.context.join("\n") },
      ],
    };
  });
}
