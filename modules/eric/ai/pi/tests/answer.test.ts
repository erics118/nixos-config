import assert from "node:assert/strict";
import test from "node:test";

test("parses structured questions from a fenced response", async () => {
  const module = await import("../lib/answer-parser.ts").catch(() => undefined);
  assert.ok(module, "answer parser is not implemented");
  const result = module.parseExtractionResult(
    `\n\`\`\`json\n{"questions":[{"question":"Choose?","options":[{"label":"A","text":"One"}]}]}\n\`\`\``,
  );
  assert.deepEqual(result, {
    questions: [
      { question: "Choose?", options: [{ label: "A", text: "One" }] },
    ],
  });
});

test("parses JSON after an earlier non-JSON fenced block", async () => {
  const module = await import("../lib/answer-parser.ts");
  const result = module.parseExtractionResult(
    '```ts\nconst example = {};\n```\n```json\n{"questions":[{"question":"Choose?"}]}\n```',
  );
  assert.deepEqual(result, { questions: [{ question: "Choose?" }] });
});
