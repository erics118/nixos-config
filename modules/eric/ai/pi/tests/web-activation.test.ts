import assert from "node:assert/strict";
import test from "node:test";

test("keeps only the web loader active in a fresh session", async () => {
  const module = await import("../lib/web-activation.ts").catch(
    () => undefined,
  );
  assert.ok(module, "web activation state is not implemented");
  assert.deepEqual(
    module.withLazyWebTools(
      [
        "read",
        "web_search",
        "source_check",
        "fetch_content",
        "get_search_content",
      ],
      ["web_search", "source_check", "fetch_content", "get_search_content"],
    ),
    ["read", "web_enable"],
  );
});

test("enables every registered web tool without duplicates", async () => {
  const module = await import("../lib/web-activation.ts").catch(
    () => undefined,
  );
  assert.ok(module, "web activation state is not implemented");
  assert.deepEqual(
    module.withEnabledWebTools(
      ["read", "web_enable", "web_search"],
      ["web_search", "source_check"],
    ),
    ["read", "web_enable", "web_search", "source_check"],
  );
});
