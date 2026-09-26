import { Type } from "@earendil-works/pi-ai";
import type {
  ExtensionAPI,
  ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import {
  DEFAULT_WEB_TOOL_NAMES,
  WEB_LOADER_NAME,
  withEnabledWebTools,
  withLazyWebTools,
} from "../../lib/web-activation.ts";

const FALSE_VERSION_WARNING =
  "[pi-web-access] Dynamic tool activation requires Pi 0.86.1 or newer; web tools remain eagerly available.";

const originalWarn = console.warn.bind(console);
console.warn = (...args: unknown[]) => {
  if (args.length === 1 && args[0] === FALSE_VERSION_WARNING) return;
  originalWarn(...args);
};

const registeredWebTools = (pi: ExtensionAPI) => {
  const registered = new Set(pi.getAllTools().map((tool) => tool.name));
  return DEFAULT_WEB_TOOL_NAMES.filter((name) => registered.has(name));
};

const branchHasMessages = (ctx: ExtensionContext) =>
  ctx.sessionManager.getBranch().some((entry) => entry.type === "message");

export default function registerWebActivationCompat(pi: ExtensionAPI): void {
  const parameters = Type.Object({}, { additionalProperties: false });

  pi.registerTool({
    name: WEB_LOADER_NAME,
    label: "Enable Web Access",
    description:
      "Enable configured web search, source-checking, fetching, and stored-content tools for the next model request.",
    promptSnippet:
      "Call web_enable before web research. The configured web tools become available on the next model request.",
    parameters,
    async execute() {
      const tools = registeredWebTools(pi);
      if (tools.length === 0) {
        return {
          isError: true,
          content: [
            {
              type: "text" as const,
              text: "No pi-web-access tools are registered.",
            },
          ],
          details: { unavailable: DEFAULT_WEB_TOOL_NAMES },
        };
      }
      pi.setActiveTools(withEnabledWebTools(pi.getActiveTools(), tools));
      return {
        content: [
          { type: "text" as const, text: `Enabled: ${tools.join(", ")}.` },
        ],
        details: { enabled: tools },
      };
    },
  });

  const selectForSession = (ctx: ExtensionContext) => {
    const tools = registeredWebTools(pi);
    if (tools.length === 0) return;
    pi.setActiveTools(
      branchHasMessages(ctx)
        ? withEnabledWebTools(pi.getActiveTools(), tools)
        : withLazyWebTools(pi.getActiveTools(), tools),
    );
  };

  pi.on("session_start", (_event, ctx) => selectForSession(ctx));
  pi.on("session_tree", (_event, ctx) => selectForSession(ctx));
  pi.on("before_agent_start", () => {
    if (pi.getActiveTools().includes(WEB_LOADER_NAME)) return;
    pi.setActiveTools([...pi.getActiveTools(), WEB_LOADER_NAME]);
  });
}
