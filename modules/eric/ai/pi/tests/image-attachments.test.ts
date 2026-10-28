import assert from "node:assert/strict";
import { mkdtemp, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";

const png = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00]);

test("converts a submitted image path into an attachment without exposing the path", async () => {
  const module = await import("../extensions/image-attachments.ts").catch(
    () => undefined,
  );
  assert.ok(module, "image attachments are not implemented");
  const dir = await mkdtemp(path.join(tmpdir(), "pi-image-"));
  const imagePath = path.join(dir, "shot.png");
  await writeFile(imagePath, png);
  const result = await module.attachImagePaths(`review ${imagePath}`, dir, []);
  assert.equal(result.text, "review [image 1]");
  assert.equal(result.images.length, 1);
  assert.equal(result.images[0].mimeType, "image/png");
});

test("uses attachment indexes for duplicate and existing images", async () => {
  const module = await import("../extensions/image-attachments.ts");
  const dir = await mkdtemp(path.join(tmpdir(), "pi-image-"));
  const imagePath = path.join(dir, "shot.png");
  await writeFile(imagePath, png);
  const first = await module.attachImagePaths(imagePath, dir, []);
  const duplicate = await module.attachImagePaths(
    `${imagePath} ${imagePath}`,
    dir,
    [],
  );
  const existing = await module.attachImagePaths(imagePath, dir, first.images);

  assert.equal(duplicate.text, "[image 1] [image 1]");
  assert.equal(duplicate.images.length, 1);
  assert.equal(existing.text, "[image 1]");
  assert.equal(existing.images.length, 1);
});

test("rejects per-image and aggregate request sizes", async () => {
  const module = await import("../extensions/image-attachments.ts").catch(
    () => undefined,
  );
  assert.ok(module, "image attachments are not implemented");
  assert.throws(
    () => module.validateImageSizes([5 * 1024 * 1024 + 1]),
    /5 MiB/,
  );
  assert.throws(
    () => module.validateImageSizes(Array(7).fill(5 * 1024 * 1024)),
    /32 MiB/,
  );
});
