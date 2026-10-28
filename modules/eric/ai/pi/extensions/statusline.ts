import { execFile } from "node:child_process";
import { homedir } from "node:os";
import { join } from "node:path";
import {
  type ExtensionAPI,
  type ExtensionContext,
} from "@earendil-works/pi-coding-agent";

// claude's statusline script draws this one too, from pi's values in claude's json shape
const script = join(homedir(), ".claude", "statusline.zsh");

function runStatusline(input: object): Promise<string> {
  return new Promise((resolve) => {
    const child = execFile(
      "zsh",
      ["-f", script, "pi"],
      { timeout: 1000 },
      (error, stdout) => resolve(error ? "" : stdout),
    );
    child.stdin?.end(JSON.stringify(input));
  });
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

  const usage = ctx.getContextUsage();
  const model = ctx.model as
    { id: string; name?: string; reasoning?: boolean } | undefined;
  const text = await runStatusline({
    workspace: { current_dir: ctx.cwd },
    model: model && { display_name: model.name ?? model.id },
    effort: model?.reasoning ? { level: pi.getThinkingLevel() } : undefined,
    context_window:
      usage?.tokens != null && usage.contextWindow > 0
        ? { used_percentage: (usage.tokens / usage.contextWindow) * 100 }
        : undefined,
    cost: { total_cost_usd: getSessionCost(ctx) },
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
