import assert from "node:assert/strict";
import test from "node:test";

test("formats local time and elapsed session seconds", async () => {
  const module = await import("../lib/time-context.ts").catch(() => undefined);
  assert.ok(module, "time context is not implemented");
  const started = new Date("2025-01-01T00:00:00Z");
  const now = new Date("2025-01-01T01:02:03Z");
  const result = module.createTimeContext(now, started);
  assert.match(
    result.localDateTime,
    /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+-]\d{2}:\d{2}$/,
  );
  assert.equal(result.sessionElapsedSeconds, 3723);
  assert.ok(result.timeZone);
  assert.ok(result.weekday);
});
