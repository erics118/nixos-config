import assert from "node:assert/strict";
import {
  mkdtempSync,
  mkdirSync,
  realpathSync,
  symlinkSync,
  writeFileSync,
} from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { resolveManagedPath } from "../extensions/managed-paths.ts";

test("regular paths pass through", () => {
  const root = mkdtempSync(path.join(os.tmpdir(), "pi-paths-"));
  const file = path.join(root, "file.txt");
  writeFileSync(file, "");
  assert.deepEqual(resolveManagedPath(file, root), {
    kind: "regular",
    path: file,
  });
});

test(
  "allows a new file below the macOS /tmp symlink",
  { skip: process.platform !== "darwin" },
  () => {
    const target = path.join("/tmp", `pi-paths-${process.pid}`, "file.txt");
    const tempRoot = realpathSync.native("/tmp");

    assert.deepEqual(
      resolveManagedPath(
        target,
        mkdtempSync(path.join(os.tmpdir(), "pi-home-")),
      ),
      {
        kind: "redirect",
        path: target,
        target: path.join(tempRoot, `pi-paths-${process.pid}`, "file.txt"),
      },
    );
  },
);

test("approved managed symlink redirects", () => {
  const home = mkdtempSync(path.join(os.tmpdir(), "pi-home-"));
  const source = path.join(home, "nixos-config", "file.txt");
  mkdirSync(path.dirname(source), { recursive: true });
  writeFileSync(source, "");
  const link = path.join(home, "managed.txt");
  symlinkSync(source, link);
  assert.deepEqual(resolveManagedPath(link, home), {
    kind: "redirect",
    path: link,
    target: realpathSync.native(source),
  });
});

test("unapproved symlink blocks", () => {
  const home = mkdtempSync(path.join(os.tmpdir(), "pi-home-"));
  const outside = mkdtempSync(path.join(os.tmpdir(), "pi-outside-"));
  const source = path.join(outside, "file.txt");
  writeFileSync(source, "");
  const link = path.join(home, "managed.txt");
  symlinkSync(source, link);
  assert.equal(resolveManagedPath(link, home).kind, "blocked");
});

test("resolves relative paths from the session working directory", () => {
  const home = mkdtempSync(path.join(os.tmpdir(), "pi-home-"));
  const cwd = path.join(home, "nixos-config");
  mkdirSync(cwd, { recursive: true });
  assert.deepEqual(resolveManagedPath("new.ts", home, cwd), {
    kind: "redirect",
    path: path.join(cwd, "new.ts"),
    target: path.join(realpathSync.native(cwd), "new.ts"),
  });
});

test("allows a new regular file outside managed roots", () => {
  const home = mkdtempSync(path.join(os.tmpdir(), "pi-home-"));
  const cwd = mkdtempSync(path.join(os.tmpdir(), "pi-project-"));
  assert.deepEqual(resolveManagedPath("new.ts", home, cwd), {
    kind: "regular",
    path: path.join(cwd, "new.ts"),
  });
});

test("blocks a nested managed symlink that escapes approved roots", () => {
  const home = mkdtempSync(path.join(os.tmpdir(), "pi-home-"));
  const outside = mkdtempSync(path.join(os.tmpdir(), "pi-outside-"));
  const config = path.join(home, ".config");
  mkdirSync(config, { recursive: true });
  symlinkSync(outside, path.join(config, "link"));
  assert.equal(
    resolveManagedPath(path.join(config, "link", "file.txt"), home).kind,
    "blocked",
  );
});
