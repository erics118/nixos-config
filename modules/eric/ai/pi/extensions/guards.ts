import { spawn } from "node:child_process";
import path from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const home = process.env.HOME ?? "~";
const hooks = path.join(home, ".agents", "hooks");

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

function runScript(
  script: string,
  args: string[],
  event: HookEvent,
): Promise<Run> {
  return new Promise((resolve) => {
    const child = spawn(script, args, { cwd: event.cwd });
    let stdout = "";
    let stderr = "";
    child.stdout.on("data", (d) => (stdout += d));
    child.stderr.on("data", (d) => (stderr += d));
    child.on("error", (e) =>
      resolve({ status: null, stdout, stderr: String(e) }),
    );
    child.on("close", (status) => resolve({ status, stdout, stderr }));
    // a script may exit without reading its input, and close still judges it
    child.stdin.on("error", () => {});
    child.stdin.end(JSON.stringify(event));
  });
}

// guard.sh picks the checks for the tool and combines their decisions.
// before a tool runs, a guard that fails or prints bad output blocks the call
async function guard(when: "pre" | "post", event: HookEvent): Promise<Outcome> {
  const run = await runScript(
    path.join(hooks, "guard.sh"),
    [when, "pi"],
    event,
  );
  const out: Outcome = { context: [] };
  const problem = (msg: string) => {
    if (when === "pre") out.deny = msg;
    else out.context.push(msg);
    return out;
  };
  if (run.status === 2) return problem(run.stderr.trim());
  if (run.status !== 0)
    return problem("guard.sh failed, so the call was not checked");
  if (!run.stdout.trim()) return out;
  let d;
  try {
    d = JSON.parse(run.stdout)?.hookSpecificOutput ?? {};
  } catch {
    return problem("guard.sh printed output that is not JSON");
  }
  if (d.permissionDecision === "deny")
    out.deny = d.permissionDecisionReason ?? "guard.sh blocked this";
  if (d.permissionDecision === "ask") out.ask = d.permissionDecisionReason;
  if (typeof d.updatedInput?.command === "string")
    out.command = d.updatedInput.command;
  return out;
}

// pi's tool calls in the shape guard.sh reads (Claude Code's tool names and fields)
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
    const out = await guard("pre", hookEvent);
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
    const out = await guard("post", hookEvent);
    if (out.context.length === 0) return undefined;
    return {
      content: [
        ...event.content,
        { type: "text", text: out.context.join("\n") },
      ],
    };
  });

  pi.on("agent_settled", async (_event, ctx) => {
    const event = { cwd: ctx.cwd, tool_name: "", tool_input: {} };
    await runScript(path.join(hooks, "tmux-bell.sh"), [], event);
  });
}
