import { execFile } from "node:child_process";
import { promisify } from "node:util";
import {
  type ExtensionAPI,
  type ExtensionContext,
} from "@earendil-works/pi-coding-agent";

const execFileAsync = promisify(execFile);
const reset = "\x1b[0m";
const separator = "\x1b[38;2;69;71;90m├┤\x1b[0m";
const teal = "\x1b[38;2;148;226;213m";
const pink = "\x1b[38;2;245;194;231m";
const blue = "\x1b[38;2;137;180;250m";
const dim = "\x1b[38;2;153;153;153m";
const green = "\x1b[38;2;166;227;161m";
const yellow = "\x1b[38;2;249;226;175m";
const red = "\x1b[38;2;243;139;168m";

function formatStatusline({
  cwd,
  git,
  model,
  thinking,
  context,
  cost,
}: {
  cwd?: string;
  git?: string;
  model?: string;
  thinking?: string;
  context?: string;
  cost: number;
}): string {
  const segments = [
    cwd,
    git,
    model && `${model}${thinking ? ` ${thinking}` : ""}`,
    context,
    `${dim}$${cost.toFixed(2)}${reset}`,
  ].filter(Boolean);

  return segments.join(separator);
}

function color(value: string, ansi: string): string {
  return `${ansi}${value}${reset}`;
}

function colorForPercentage(percentage: number): string {
  if (percentage >= 90) return red;
  if (percentage >= 70) return yellow;
  return green;
}

function gitStatus(output: string): { branch?: string; status?: string } {
  const [head, ...entries] = output.trimEnd().split("\n");
  if (!head?.startsWith("## ")) return {};

  const branch = head.slice(3).split("...")[0];
  if (!branch || branch === "HEAD (no branch)") return {};

  let status = "";
  if (entries.some((entry) => !entry.startsWith("??"))) status += "~";
  if (entries.some((entry) => entry.startsWith("??"))) status += "+";
  if (head.includes("ahead") && head.includes("behind")) status += "↕";
  else if (head.includes("ahead")) status += "↑";
  else if (head.includes("behind")) status += "↓";

  return { branch, status };
}

async function getGitStatus(
  cwd: string,
): Promise<{ branch?: string; status?: string }> {
  try {
    const { stdout } = await execFileAsync(
      "git",
      ["-C", cwd, "status", "--porcelain=v1", "--branch"],
      {
        timeout: 1000,
      },
    );
    return gitStatus(stdout);
  } catch {
    return {};
  }
}

function getSessionCost(ctx: ExtensionContext): number {
  return ctx.sessionManager.getEntries().reduce((total, entry) => {
    const usage =
      entry.type === "message"
        ? "usage" in entry.message
          ? entry.message.usage
          : undefined
        : "usage" in entry
          ? entry.usage
          : undefined;
    return total + (usage?.cost.total ?? 0);
  }, 0);
}

async function update(pi: ExtensionAPI, ctx: ExtensionContext): Promise<void> {
  if (ctx.mode !== "tui") return;

  const git = await getGitStatus(ctx.cwd);
  const usage = ctx.getContextUsage();
  const contextPercent =
    usage?.tokens != null && usage.contextWindow > 0
      ? Math.round((usage.tokens / usage.contextWindow) * 100)
      : undefined;
  const model = ctx.model as
    { id: string; name?: string; reasoning?: boolean } | undefined;
  const home = process.env.HOME;
  const cwd =
    home && ctx.cwd.startsWith(`${home}/`)
      ? `~${ctx.cwd.slice(home.length)}`
      : ctx.cwd;
  const text = formatStatusline({
    cwd: color(cwd, teal),
    git: git.branch
      ? color(` ${git.branch}${git.status ? ` ${git.status}` : ""}`, pink)
      : undefined,
    model: model ? color(model.name ?? model.id, blue) : undefined,
    thinking: model?.reasoning ? color(pi.getThinkingLevel(), blue) : undefined,
    context:
      contextPercent === undefined
        ? undefined
        : `${dim}ctx:${colorForPercentage(contextPercent)}${contextPercent}%${reset}`,
    cost: getSessionCost(ctx),
  });

  ctx.ui.setFooter(() => ({
    render(): string[] {
      return [text];
    },
    invalidate(): void {},
  }));
}

export default function createExtension(pi: ExtensionAPI): void {
  let activeUpdate: Promise<void> | undefined;
  let pendingContext: ExtensionContext | undefined;

  const refresh = async (ctx: ExtensionContext): Promise<void> => {
    pendingContext = ctx;
    if (activeUpdate) return activeUpdate;

    activeUpdate = (async () => {
      while (pendingContext) {
        const nextContext = pendingContext;
        pendingContext = undefined;
        await update(pi, nextContext);
      }
    })();
    try {
      await activeUpdate;
    } finally {
      activeUpdate = undefined;
    }
  };

  pi.on("session_start", async (_event, ctx) => refresh(ctx));
  pi.on("model_select", async (_event, ctx) => refresh(ctx));
  pi.on("thinking_level_select", async (_event, ctx) => refresh(ctx));
  pi.on("turn_start", async (_event, ctx) => refresh(ctx));
  pi.on("turn_end", async (_event, ctx) => refresh(ctx));
  pi.on("tool_result", async (_event, ctx) => refresh(ctx));
  pi.on("session_compact", async (_event, ctx) => refresh(ctx));
  pi.on("session_tree", async (_event, ctx) => refresh(ctx));
}
