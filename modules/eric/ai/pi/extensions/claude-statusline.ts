import { execFile } from "node:child_process";
import { promisify } from "node:util";
import {
  CustomEditor,
  type ExtensionAPI,
  type ExtensionContext,
  type KeybindingsManager,
} from "@earendil-works/pi-coding-agent";
import { CURSOR_MARKER, type EditorTheme, type TUI } from "@earendil-works/pi-tui";

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
  const home = process.env.HOME;
  const displayCwd = home && cwd?.startsWith(`${home}/`) ? `~${cwd.slice(home.length)}` : cwd;
  const segments = [
    displayCwd,
    git,
    model && `${model}${thinking ? ` ${thinking}` : ""}`,
    context,
    `${dim}$${cost.toFixed(2)}${reset}`,
  ].filter(Boolean);

  return segments.join(separator);
}

function removeSoftwareCursor(line: string): string {
  const markerIndex = line.indexOf(CURSOR_MARKER);
  if (markerIndex < 0) return line;

  const start = markerIndex + CURSOR_MARKER.length;
  if (!line.startsWith("\x1b[7m", start)) return line;

  const end = line.indexOf("\x1b[0m", start);
  if (end < 0) return line;

  return `${line.slice(0, start)}${line.slice(start + 4, end)}${line.slice(end + 4)}`;
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

async function getGitStatus(cwd: string): Promise<{ branch?: string; status?: string }> {
  try {
    const { stdout } = await execFileAsync("git", ["-C", cwd, "status", "--porcelain=v1", "--branch"], {
      timeout: 1000,
    });
    return gitStatus(stdout);
  } catch {
    return {};
  }
}

function getSessionCost(ctx: ExtensionContext): number {
  return ctx.sessionManager.getEntries().reduce((total, entry) => {
    const usage = entry.type === "message" ? entry.message.usage : entry.usage;
    return total + (usage?.cost.total ?? 0);
  }, 0);
}

async function update(pi: ExtensionAPI, ctx: ExtensionContext): Promise<void> {
  const git = await getGitStatus(ctx.cwd);
  const usage = ctx.getContextUsage();
  const contextPercent =
    usage?.tokens != null && usage.contextWindow > 0 ? Math.round((usage.tokens / usage.contextWindow) * 100) : undefined;
  const model = ctx.model as { id: string; name?: string; reasoning?: boolean } | undefined;
  const home = process.env.HOME;
  const cwd = home && ctx.cwd.startsWith(`${home}/`) ? `~${ctx.cwd.slice(home.length)}` : ctx.cwd;
  const text = formatStatusline({
    cwd: color(cwd, teal),
    git: git.branch ? color(` ${git.branch}${git.status ? ` ${git.status}` : ""}`, pink) : undefined,
    model: model ? color(model.name ?? model.id, blue) : undefined,
    thinking: model?.reasoning ? color(pi.getThinkingLevel(), blue) : undefined,
    context:
      contextPercent === undefined
        ? undefined
        : `${dim}ctx:${colorForPercentage(contextPercent)}${contextPercent}%${reset}`,
    cost: getSessionCost(ctx),
  });

  if (!ctx.hasUI) return;
  ctx.ui.setFooter(() => ({
    render(): string[] {
      return [text];
    },
    invalidate(): void {},
  }));
}

export default function createExtension(pi: ExtensionAPI): void {
  pi.on("session_start", (_event, ctx) => {
    class PromptEditor extends CustomEditor {
      constructor(tui: TUI, theme: EditorTheme, keybindings: KeybindingsManager) {
        super(tui, theme, keybindings, { paddingX: 2 });
      }

      render(width: number): string[] {
        const lines = super.render(width);
        if (lines.length > 2) lines[1] = lines[1].replace(/^ {2}/, "❯ ");
        return lines.map(removeSoftwareCursor);
      }
    }

    ctx.ui.setEditorComponent((tui, theme, keybindings) => new PromptEditor(tui, theme, keybindings));
    ctx.ui.addAutocompleteProvider((current) => ({
      async getSuggestions(lines, cursorLine, cursorCol, options) {
        const suggestions = await current.getSuggestions(lines, cursorLine, cursorCol, options);
        if (!suggestions) return null;
        return {
          ...suggestions,
          items: suggestions.items.filter((item) => !item.value.startsWith("/skill:")),
        };
      },
      applyCompletion(lines, cursorLine, cursorCol, item, prefix) {
        return current.applyCompletion(lines, cursorLine, cursorCol, item, prefix);
      },
      shouldTriggerFileCompletion(lines, cursorLine, cursorCol) {
        return current.shouldTriggerFileCompletion?.(lines, cursorLine, cursorCol) ?? true;
      },
    }));
  });

  for (const event of [
    "session_start",
    "model_select",
    "thinking_level_select",
    "turn_start",
    "turn_end",
    "tool_result",
    "session_compact",
    "session_tree",
  ] as const) {
    pi.on(event, async (_event, ctx) => update(pi, ctx));
  }
}
