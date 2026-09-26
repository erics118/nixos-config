import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const piRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const packageRoot = path.join(piRoot, "packages", "pi-diff");

test("pi-diff is a local Pi package with its runtime dependencies", () => {
  const settings = JSON.parse(readFileSync(path.join(piRoot, "settings.json"), "utf8"));
  const packageJsonPath = path.join(packageRoot, "package.json");

  const indexPath = path.join(packageRoot, "src", "index.ts");
  const shikiPath = path.join(packageRoot, "src", "shiki.ts");

  assert.ok(existsSync(indexPath));
  assert.ok(existsSync(shikiPath));
  assert.ok(existsSync(packageJsonPath));
  assert.ok(settings.packages.includes("./packages/pi-diff"));
  assert.match(readFileSync(indexPath, "utf8"), /from "\.\/shiki\.js"/);

  const packageJson = JSON.parse(readFileSync(packageJsonPath, "utf8"));
  assert.equal(packageJson.pi.extensions[0], "./src/index.ts");
  assert.equal(packageJson.dependencies["@shikijs/core"], "4.4.3");
  assert.equal(packageJson.dependencies["@shikijs/engine-javascript"], "4.4.3");
  assert.equal(packageJson.dependencies["@shikijs/langs"], "4.4.3");
  assert.equal(packageJson.dependencies["@shikijs/themes"], "4.4.3");
  assert.equal(packageJson.dependencies.diff, "7.0.0");
});
