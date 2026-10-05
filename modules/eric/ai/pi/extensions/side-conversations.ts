import { randomUUID } from "node:crypto";
import { unlink } from "node:fs/promises";
import type { AssistantMessage, UserMessage } from "@earendil-works/pi-ai";
import {
  SessionManager,
  buildSessionContext,
  convertToLlm,
  getMarkdownTheme,
  type ExtensionAPI,
  type ExtensionContext,
  type Theme,
} from "@earendil-works/pi-coding-agent";
import {
  Input,
  Key,
  Loader,
  Markdown,
  matchesKey,
  truncateToWidth,
  visibleWidth,
  wrapTextWithAnsi,
  type Component,
  type Focusable,
  type KeybindingsManager,
  type OverlayHandle,
  type TUI,
} from "@earendil-works/pi-tui";
import { buildTmuxLaunch, SIDE_SYSTEM_PROMPT } from "../lib/side-session.ts";

const BTW_SYSTEM_PROMPT = [
  "You are having a private side conversation with the user.",
  "Use the supplied main conversation as read-only context.",
  "You have no tools and must not claim to inspect anything outside that context.",
  "Do not continue or steer the main agent's work.",
  "Answer directly and keep the side conversation focused.",
].join(" ");

const MAX_BTW_TURNS = 20;
const IS_MACOS = process.platform === "darwin";
const SIDE_SHORTCUT = IS_MACOS ? Key.super(Key.enter) : Key.ctrl(Key.enter);
const SIDE_SHORTCUT_LABEL = IS_MACOS ? "cmd+enter" : "ctrl+enter";
const FAKE_CURSOR = /\x1b\[7m(.*?)\x1b\[(?:0|27)m/g;

export const renderBtwInput = (inputContent: string) =>
  inputContent.replace(FAKE_CURSOR, "$1");

export const isBtwForkShortcut = (
  data: string,
  draft: string,
  status: "pending" | "complete" | "failed" | undefined,
) => data === "f" && draft.length === 0 && status === "complete";

export const BTW_OVERLAY_OPTIONS = {
  width: "100%" as const,
  minWidth: 50,
  maxHeight: "42%" as const,
  anchor: "bottom-center" as const,
  margin: { bottom: 0 },
  nonCapturing: false,
};

type BtwTurn =
  | { id: string; question: string; status: "pending"; answer: string }
  | {
      id: string;
      question: string;
      status: "complete";
      answer: string;
      message: AssistantMessage;
    }
  | { id: string; question: string; status: "failed"; message: string };

type CompletedBtwTurn = Extract<BtwTurn, { status: "complete" }>;

type BtwCompletion =
  | { kind: "complete"; answer: string; message: AssistantMessage }
  | { kind: "cancelled" }
  | { kind: "failed"; message: string };

type DrawerRuntime = {
  handle?: OverlayHandle;
  refresh?: () => void;
  close?: () => void;
  closed?: boolean;
};

const extractResponseText = (
  content: ReadonlyArray<{ type: string; text?: string }>,
) =>
  content
    .filter((part) => part.type === "text" && typeof part.text === "string")
    .map((part) => part.text ?? "")
    .join("\n")
    .trim();

const completedBtwTurns = (turns: BtwTurn[]) =>
  turns.filter((turn): turn is CompletedBtwTurn => turn.status === "complete");

const formatBtwQuestion = (turns: BtwTurn[], question: string) => {
  const previous = completedBtwTurns(turns)
    .slice(-MAX_BTW_TURNS)
    .map((turn) => `User: ${turn.question}\nAssistant: ${turn.answer}`)
    .join("\n\n");

  return previous
    ? `Earlier side conversation:\n\n${previous}\n\nCurrent question:\n${question}`
    : question;
};

const formatSideContinuation = (turns: BtwTurn[]) => {
  const conversation = completedBtwTurns(turns)
    .map((turn) => `User: ${turn.question}\n\nAssistant: ${turn.answer}`)
    .join("\n\n---\n\n");

  return `Continue this side conversation with full tools.\n\n${conversation}`;
};

const fitLine = (text: string, width: number) => {
  const truncated = truncateToWidth(text, width, "");
  return `${truncated}${" ".repeat(Math.max(0, width - visibleWidth(truncated)))}`;
};

export const renderBtwTurn = (
  turn: BtwTurn | undefined,
  width: number,
  theme: Theme,
  workingIndicator: string,
) => {
  if (!turn)
    return [theme.fg("dim", "Ask without interrupting the main agent.")];

  const command = theme.fg("accent", theme.bold("/btw"));
  const questionLines = wrapTextWithAnsi(turn.question, Math.max(1, width - 5));
  const renderedQuestion = questionLines.map((line, index) =>
    index === 0
      ? `${command} ${theme.fg("muted", line)}`
      : `     ${theme.fg("muted", line)}`,
  );

  if (turn.status === "pending") {
    if (!turn.answer) {
      return [...renderedQuestion, "", `  ${workingIndicator}`];
    }

    const answerLines = new Markdown(
      turn.answer,
      0,
      0,
      getMarkdownTheme(),
    ).render(Math.max(1, width - 4));
    return [...renderedQuestion, "", ...answerLines.map((line) => `  ${line}`)];
  }

  if (turn.status === "failed") {
    const errorLines = wrapTextWithAnsi(turn.message, Math.max(1, width - 4));
    return [
      ...renderedQuestion,
      "",
      ...errorLines.map((line) => `  ${theme.fg("error", line)}`),
    ];
  }

  const answerLines = new Markdown(
    turn.answer,
    0,
    0,
    getMarkdownTheme(),
  ).render(Math.max(1, width - 4));
  return [...renderedQuestion, "", ...answerLines.map((line) => `  ${line}`)];
};

class BtwDrawer implements Component, Focusable {
  private readonly input = new Input();
  private readonly loader: Loader;
  private _focused = false;
  private loaderRunning = false;
  private scrollFromBottom = 0;
  private viewportHeight = 6;

  constructor(
    private readonly tui: TUI,
    private readonly theme: Theme,
    private readonly keybindings: KeybindingsManager,
    private readonly readTurns: () => BtwTurn[],
    private readonly onSubmit: (question: string) => void,
    private readonly onClose: () => void,
    private readonly onFork: () => void,
    private readonly onEscalate: () => void,
  ) {
    this.loader = new Loader(
      tui,
      (spinner) => theme.fg("accent", spinner),
      (message) => theme.fg("muted", message),
      "Answering",
    );
    this.loader.stop();

    this.input.onSubmit = (value) => {
      const question = value.trim();
      if (!question) return;
      this.input.setValue("");
      this.scrollFromBottom = 0;
      this.onSubmit(question);
    };
    this.input.onEscape = this.onClose;
  }

  get focused() {
    return this._focused;
  }

  set focused(value: boolean) {
    this._focused = value;
    this.input.focused = value;
  }

  setDraft(value: string) {
    this.input.setValue(value);
    this.tui.requestRender();
  }

  dispose() {
    this.loader.stop();
    this.loaderRunning = false;
  }

  handleInput(data: string) {
    const selectedTurn = this.readTurns().at(-1);
    if (isBtwForkShortcut(data, this.input.getValue(), selectedTurn?.status)) {
      this.onFork();
      return;
    }
    if (matchesKey(data, SIDE_SHORTCUT)) {
      this.onEscalate();
      return;
    }
    if (matchesKey(data, Key.up) || matchesKey(data, Key.pageUp)) {
      const distance = matchesKey(data, Key.pageUp)
        ? Math.max(1, this.viewportHeight - 1)
        : 1;
      this.scrollFromBottom += distance;
      this.tui.requestRender();
      return;
    }
    if (matchesKey(data, Key.down) || matchesKey(data, Key.pageDown)) {
      const distance = matchesKey(data, Key.pageDown)
        ? Math.max(1, this.viewportHeight - 1)
        : 1;
      this.scrollFromBottom = Math.max(0, this.scrollFromBottom - distance);
      this.tui.requestRender();
      return;
    }
    if (this.keybindings.matches(data, "tui.select.cancel")) {
      this.onClose();
      return;
    }
    this.input.handleInput(data);
  }

  render(width: number) {
    const contentWidth = Math.max(30, width);
    const terminalRows = process.stdout.rows ?? 30;
    this.viewportHeight = Math.max(
      5,
      Math.min(12, Math.floor(terminalRows * 0.3)),
    );

    const selectedTurn = this.readTurns().at(-1);
    const waiting =
      selectedTurn?.status === "pending" && selectedTurn.answer.length === 0;
    if (waiting !== this.loaderRunning) {
      if (waiting) this.loader.start();
      else this.loader.stop();
      this.loaderRunning = waiting;
    }
    const workingIndicator = waiting
      ? (this.loader.render(Math.max(1, contentWidth - 4)).at(-1) ?? "")
      : "";
    const transcript = renderBtwTurn(
      selectedTurn,
      contentWidth,
      this.theme,
      workingIndicator,
    );
    const maxScroll = Math.max(0, transcript.length - this.viewportHeight);
    this.scrollFromBottom = Math.min(this.scrollFromBottom, maxScroll);
    const start = Math.max(
      0,
      transcript.length - this.viewportHeight - this.scrollFromBottom,
    );
    const visibleTranscript = transcript.slice(
      start,
      start + this.viewportHeight,
    );
    const inputWidth = Math.max(1, contentWidth - 6);
    const renderedInput = this.input.render(inputWidth)[0] ?? "";
    const inputContent = renderedInput.startsWith("> ")
      ? renderedInput.slice(2)
      : renderedInput;
    const visibleInput = renderBtwInput(inputContent);
    const composerLabel = this.focused
      ? this.theme.fg("accent", this.theme.bold("btw ›"))
      : this.theme.fg("dim", "btw ›");
    const forkHint = selectedTurn?.status === "complete" ? " · f fork" : "";
    const focusHint = `↑↓ scroll${forkHint} · ${SIDE_SHORTCUT_LABEL} side · esc close`;

    return [
      ...visibleTranscript.map((line) => fitLine(line, contentWidth)),
      fitLine("", contentWidth),
      fitLine(`${composerLabel} ${visibleInput}`, contentWidth),
      fitLine(this.theme.fg("dim", focusHint), contentWidth),
    ];
  }

  invalidate() {}
}

export default function (pi: ExtensionAPI) {
  let btwTurns: BtwTurn[] = [];
  let activeBtwController: AbortController | undefined;
  let drawerRuntime: DrawerRuntime | undefined;

  const seedSideConversation = (
    prompt: string,
    sessionPath: string | undefined,
    seedTurns: CompletedBtwTurn[],
  ) => {
    if (seedTurns.length === 0) return prompt;
    if (!sessionPath) return formatSideContinuation(seedTurns);

    const sideSession = SessionManager.open(sessionPath);
    seedTurns.forEach((turn, index) => {
      const timestamp = Date.now() + index * 2;
      sideSession.appendMessage({
        role: "user",
        content: [{ type: "text", text: turn.question }],
        timestamp,
      });
      sideSession.appendMessage({ ...turn.message, timestamp: timestamp + 1 });
    });
    return "";
  };

  const createSideSession = (
    prompt: string,
    name: string,
    ctx: ExtensionContext,
    seedTurns: CompletedBtwTurn[],
  ) => {
    const leafId = ctx.sessionManager.getLeafId();
    const sessionFile = ctx.sessionManager.getSessionFile();
    const sessionPath =
      leafId && sessionFile
        ? SessionManager.open(sessionFile).createBranchedSession(leafId)
        : undefined;

    if (sessionPath) {
      const sideSession = SessionManager.open(sessionPath);
      sideSession.appendSessionInfo(name);
      sideSession.appendCustomMessageEntry(
        "side-session",
        SIDE_SYSTEM_PROMPT,
        false,
      );
    }

    return {
      effectivePrompt: seedSideConversation(prompt, sessionPath, seedTurns),
      sessionPath,
    };
  };

  const launchTmuxSide = async (
    sessionPath: string | undefined,
    effectivePrompt: string,
    name: string,
    ctx: ExtensionContext,
  ) => {
    if (!process.env.TMUX) {
      throw new Error("/side requires an active tmux session");
    }
    if (!sessionPath) {
      throw new Error(
        "/side needs a saved Pi session before tmux can resume it",
      );
    }

    const launch = buildTmuxLaunch({
      cwd: ctx.cwd,
      sessionPath,
      name,
      prompt: effectivePrompt,
    });
    const result = await pi.exec(launch.command, launch.args, {
      timeout: 10_000,
    });
    if (result.code !== 0) {
      throw new Error(
        result.stderr.trim() ||
          result.stdout.trim() ||
          "tmux could not open the side pane",
      );
    }
    return name;
  };

  const launchSide = async (
    prompt: string,
    ctx: ExtensionContext,
    seedTurns: CompletedBtwTurn[] = [],
  ) => {
    const name = `side-${randomUUID().slice(0, 6)}`;
    let sessionPath: string | undefined;

    ctx.ui.setWidget("side-session-launch", undefined);
    ctx.ui.notify("Opening side session…", "info");

    try {
      const sideSession = createSideSession(prompt, name, ctx, seedTurns);
      sessionPath = sideSession.sessionPath;
      const opened = await launchTmuxSide(
        sessionPath,
        sideSession.effectivePrompt,
        name,
        ctx,
      );

      ctx.ui.notify(`Opened ${opened} in tmux`, "info");
      return true;
    } catch (error) {
      if (sessionPath) await unlink(sessionPath).catch(() => undefined);
      ctx.ui.notify(
        error instanceof Error ? error.message : String(error),
        "error",
      );
      return false;
    }
  };

  const completeBtw = async (
    question: string,
    ctx: ExtensionContext,
    signal: AbortSignal,
    onText: (text: string) => void,
  ): Promise<BtwCompletion> => {
    const model = ctx.model;
    if (!model) return { kind: "failed", message: "No model selected" };

    const context = buildSessionContext(
      ctx.sessionManager.getEntries(),
      ctx.sessionManager.getLeafId(),
    );
    const userMessage: UserMessage = {
      role: "user",
      content: [{ type: "text", text: formatBtwQuestion(btwTurns, question) }],
      timestamp: Date.now(),
    };

    try {
      const auth = await ctx.modelRegistry.getApiKeyAndHeaders(model);
      if (!auth.ok) return { kind: "failed", message: auth.error };

      const provider = ctx.modelRegistry.getProvider(model.provider);
      if (!provider)
        return {
          kind: "failed",
          message: `Provider not found: ${model.provider}`,
        };

      const requestModel = auth.baseUrl
        ? { ...model, baseUrl: auth.baseUrl }
        : model;
      const stream = provider.stream(
        requestModel,
        {
          systemPrompt: BTW_SYSTEM_PROMPT,
          messages: [...convertToLlm(context.messages), userMessage],
        },
        { signal, apiKey: auth.apiKey, headers: auth.headers, env: auth.env },
      );
      let streamedText = "";

      for await (const event of stream) {
        if (event.type !== "text_delta") continue;
        streamedText += event.delta;
        onText(streamedText);
      }

      const response = await stream.result();
      if (response.stopReason === "aborted") return { kind: "cancelled" };
      if (response.stopReason === "error") {
        return {
          kind: "failed",
          message: response.errorMessage ?? "BTW request failed",
        };
      }

      const answer =
        extractResponseText(response.content) ||
        streamedText ||
        "(No text response)";
      return {
        kind: "complete",
        answer,
        message: { ...response, content: [{ type: "text", text: answer }] },
      };
    } catch (error) {
      if (signal.aborted) return { kind: "cancelled" };
      return {
        kind: "failed",
        message: error instanceof Error ? error.message : String(error),
      };
    }
  };

  const refreshDrawer = () => {
    drawerRuntime?.refresh?.();
  };

  const submitBtw = (question: string, ctx: ExtensionContext) => {
    if (activeBtwController) {
      ctx.ui.notify("BTW is still answering", "warning");
      return;
    }

    const id = randomUUID();
    const controller = new AbortController();
    const pendingTurn: BtwTurn = {
      id,
      question,
      status: "pending",
      answer: "",
    };
    activeBtwController = controller;
    btwTurns = [...btwTurns, pendingTurn].slice(-MAX_BTW_TURNS);
    refreshDrawer();

    void completeBtw(question, ctx, controller.signal, (answer) => {
      if (activeBtwController !== controller) return;
      btwTurns = btwTurns.map((turn): BtwTurn =>
        turn.id === id ? { id, question, status: "pending", answer } : turn,
      );
      refreshDrawer();
    }).then((completion) => {
      if (activeBtwController !== controller) return;
      activeBtwController = undefined;

      if (completion.kind === "cancelled") {
        btwTurns = btwTurns.filter((turn) => turn.id !== id);
        refreshDrawer();
        return;
      }

      btwTurns = btwTurns.map((turn): BtwTurn => {
        if (turn.id !== id) return turn;
        if (completion.kind === "failed") {
          return {
            id,
            question,
            status: "failed",
            message: completion.message,
          };
        }
        return {
          id,
          question,
          status: "complete",
          answer: completion.answer,
          message: completion.message,
        };
      });
      refreshDrawer();
    });
  };

  const closeDrawer = () => {
    activeBtwController?.abort();
    activeBtwController = undefined;
    btwTurns = btwTurns.filter((turn) => turn.status !== "pending");
    drawerRuntime?.close?.();
    drawerRuntime = undefined;
  };

  const forkBtw = (ctx: ExtensionContext) => {
    const turn = btwTurns.at(-1);
    if (turn?.status !== "complete") return;

    void launchSide("", ctx, [turn]).then((opened) => {
      if (opened) closeDrawer();
    });
  };

  const escalateBtw = (ctx: ExtensionContext) => {
    const turns = completedBtwTurns(btwTurns);
    if (turns.length === 0) {
      ctx.ui.notify(
        "Finish a BTW answer before opening a side session",
        "warning",
      );
      return;
    }

    void launchSide("", ctx, turns).then((opened) => {
      if (opened) closeDrawer();
    });
  };

  const ensureDrawer = (ctx: ExtensionContext, draft = "") => {
    if (drawerRuntime?.handle) {
      drawerRuntime.handle.setHidden(false);
      drawerRuntime.handle.focus();
      drawerRuntime.refresh?.();
      return;
    }

    const runtime: DrawerRuntime = {};
    drawerRuntime = runtime;

    void ctx.ui
      .custom<void>(
        (tui, theme, keybindings, done) => {
          const drawer = new BtwDrawer(
            tui,
            theme,
            keybindings,
            () => btwTurns,
            (question) => submitBtw(question, ctx),
            closeDrawer,
            () => forkBtw(ctx),
            () => escalateBtw(ctx),
          );
          drawer.setDraft(draft);
          runtime.refresh = () => {
            drawer.focused = runtime.handle?.isFocused() ?? false;
            tui.requestRender();
          };
          runtime.close = () => {
            if (runtime.closed) return;
            runtime.closed = true;
            drawer.dispose();
            runtime.handle?.hide();
            done();
          };
          return drawer;
        },
        {
          overlay: true,
          overlayOptions: BTW_OVERLAY_OPTIONS,
          onHandle: (handle) => {
            runtime.handle = handle;
            handle.focus();
            runtime.refresh?.();
          },
        },
      )
      .catch((error) => {
        if (drawerRuntime === runtime) drawerRuntime = undefined;
        ctx.ui.notify(
          error instanceof Error ? error.message : String(error),
          "error",
        );
      });
  };

  pi.on("session_shutdown", (_event, ctx) => {
    closeDrawer();
    btwTurns = [];
    ctx.ui.setWidget("side-session-launch", undefined);
  });

  pi.registerCommand("side", {
    description: "Open a context-aware Pi side session",
    handler: async (args, ctx) => {
      await launchSide(args.trim(), ctx);
    },
  });

  pi.registerCommand("btw", {
    description:
      "Open a parallel, tool-free conversation using the current context",
    handler: async (args, ctx) => {
      if (ctx.mode !== "tui") {
        ctx.ui.notify("/btw requires interactive mode", "error");
        return;
      }

      const question = args.trim();
      if (question === "--clear") {
        closeDrawer();
        btwTurns = [];
        return;
      }

      ensureDrawer(ctx);
      if (question) submitBtw(question, ctx);
    },
  });
}
