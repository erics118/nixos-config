import assert from "node:assert/strict";
import test from "node:test";
import diffRendererExtension, { __testing } from "../src/index.js";

async function registeredTools(): Promise<Array<{ name: string; renderShell?: string; renderResult?: Function }>> {
  const tools: Array<{ name: string; renderShell?: string; renderResult?: Function }> = [];

  await diffRendererExtension({
    registerTool: (tool) => tools.push(tool as { name: string; renderShell?: string; renderResult?: Function }),
  } as never);

  return tools;
}

test("write and edit use Pi's standard tool frame", async () => {
  const tools = await registeredTools();

  assert.notEqual(tools.find((tool) => tool.name === "write")?.renderShell, "self");
  assert.notEqual(tools.find((tool) => tool.name === "edit")?.renderShell, "self");
  assert.equal(__testing.formatToolHeaderName("write"), "write");
  assert.equal(__testing.formatToolHeaderName("edit"), "edit");
  assert.equal(__testing.formatToolHeaderName("apply_patch"), "apply_patch");
});

test("new-file previews do not reset Pi's standard success background", async () => {
  const write = (await registeredTools()).find((tool) => tool.name === "write");
  const successBackground = "\x1b[48;2;12;34;56m";
  const theme = {
    fg: (_name: string, text: string) => text,
    bg: (_name: string, text: string) => `${successBackground}${text}\x1b[0m`,
    bold: (text: string) => text,
  };
  const component = write!.renderResult!(
    { details: { _type: "new", lines: 1, content: "const value = 1;", filePath: "example.ts" } },
    {},
    theme,
    { state: {}, invalidate: () => undefined },
  ) as { __piDiffTask?: { placeholder: string } };

  assert.ok(component.__piDiffTask!.placeholder.includes(`${successBackground}rendering file…`));
});
