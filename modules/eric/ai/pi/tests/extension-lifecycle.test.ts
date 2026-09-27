import assert from "node:assert/strict";
import test from "node:test";

const noop = () => {};

test("answer does not invoke terminal-only UI in RPC mode", async () => {
  const module = await import("../extensions/answer.ts");
  let command:
    { handler: (args: string, ctx: unknown) => Promise<void> } | undefined;
  module.default({
    registerCommand: (_name, value) => {
      command = value as typeof command;
    },
    registerShortcut: noop,
  } as never);

  await assert.doesNotReject(() =>
    command!.handler("", {
      mode: "rpc",
      hasUI: true,
      model: { id: "test" },
      ui: { notify: noop, custom: () => undefined },
      sessionManager: { getBranch: () => [] },
    }),
  );
});

test("statusline skips non-TUI updates before inspecting session state", async () => {
  const module = await import("../extensions/statusline.ts");
  const handlers: Array<(event: unknown, ctx: unknown) => Promise<void>> = [];
  module.default({
    on: (_event, handler) => handlers.push(handler as never),
  } as never);

  await assert.doesNotReject(() =>
    handlers[0]!(
      {},
      {
        mode: "rpc",
        hasUI: true,
        cwd: process.cwd(),
        getContextUsage: () => {
          throw new Error("statusline must not inspect non-TUI state");
        },
      },
    ),
  );
});

test("fullscreen patch is session-scoped and restored on shutdown", async () => {
  const { TuiAltScreen } = await import("@earendil-works/pi-tui");
  const proto = TuiAltScreen.prototype as Record<PropertyKey, unknown>;
  const method = Object.getOwnPropertyDescriptor(proto, "getWheelScrollLines");
  const patched = Symbol.for("eric.pi.fullscreen-tweaks.patched");
  const patchFlag = proto[patched];

  try {
    const module = await import("../extensions/fullscreen-tweaks.ts?lifecycle");
    assert.deepEqual(
      Object.getOwnPropertyDescriptor(proto, "getWheelScrollLines"),
      method,
    );

    const handlers = new Map<string, (event: unknown, ctx: unknown) => void>();
    module.default({
      on: (event, handler) => handlers.set(event, handler as never),
    } as never);
    handlers.get("session_start")!({}, {});
    assert.equal(typeof proto.getWheelScrollLines, "function");
    handlers.get("session_shutdown")!({}, {});
    assert.deepEqual(
      Object.getOwnPropertyDescriptor(proto, "getWheelScrollLines"),
      method,
    );
  } finally {
    if (method) Object.defineProperty(proto, "getWheelScrollLines", method);
    else delete proto.getWheelScrollLines;
    if (patchFlag === undefined) delete proto[patched];
    else proto[patched] = patchFlag;
  }
});
