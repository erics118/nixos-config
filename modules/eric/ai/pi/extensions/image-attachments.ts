import { createHash } from "node:crypto";
import { readFile, stat } from "node:fs/promises";
import { homedir } from "node:os";
import path from "node:path";
import type { ImageContent } from "@earendil-works/pi-ai";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const MAX_IMAGE_BYTES = 5 * 1024 * 1024;
const MAX_REQUEST_IMAGE_BYTES = 32 * 1024 * 1024;
const MAX_PATHS = 20;

type SupportedMimeType =
  "image/png" | "image/jpeg" | "image/gif" | "image/webp";

type PathToken = {
  start: number;
  end: number;
  value: string;
};

const detectMimeType = (bytes: Uint8Array): SupportedMimeType | undefined => {
  if (
    bytes.length >= 8 &&
    bytes[0] === 0x89 &&
    bytes[1] === 0x50 &&
    bytes[2] === 0x4e &&
    bytes[3] === 0x47 &&
    bytes[4] === 0x0d &&
    bytes[5] === 0x0a &&
    bytes[6] === 0x1a &&
    bytes[7] === 0x0a
  )
    return "image/png";
  if (
    bytes.length >= 3 &&
    bytes[0] === 0xff &&
    bytes[1] === 0xd8 &&
    bytes[2] === 0xff
  ) {
    return "image/jpeg";
  }
  if (
    bytes.length >= 6 &&
    bytes[0] === 0x47 &&
    bytes[1] === 0x49 &&
    bytes[2] === 0x46 &&
    bytes[3] === 0x38 &&
    (bytes[4] === 0x37 || bytes[4] === 0x39) &&
    bytes[5] === 0x61
  )
    return "image/gif";
  if (
    bytes.length >= 12 &&
    bytes[0] === 0x52 &&
    bytes[1] === 0x49 &&
    bytes[2] === 0x46 &&
    bytes[3] === 0x46 &&
    bytes[8] === 0x57 &&
    bytes[9] === 0x45 &&
    bytes[10] === 0x42 &&
    bytes[11] === 0x50
  )
    return "image/webp";
  return undefined;
};

const isPathLike = (value: string) =>
  value.startsWith("/") ||
  value.startsWith("~/") ||
  value.startsWith("./") ||
  value.startsWith("../");

const unescapePath = (value: string) => value.replace(/\\(.)/g, "$1");

const tokenizePaths = (text: string): PathToken[] => {
  const tokens: PathToken[] = [];
  let index = 0;
  while (index < text.length && tokens.length < MAX_PATHS) {
    if (/\s/.test(text[index]!)) {
      index++;
      continue;
    }
    const start = index;
    const quote =
      text[index] === "'" || text[index] === '"' ? text[index++] : undefined;
    let value = "";
    while (index < text.length) {
      const current = text[index]!;
      if (quote ? current === quote : /\s/.test(current)) break;
      if (current === "\\" && index + 1 < text.length) {
        value += text[index + 1]!;
        index += 2;
      } else {
        value += current;
        index++;
      }
    }
    if (quote && text[index] === quote) index++;
    if (isPathLike(value))
      tokens.push({ start, end: index, value: unescapePath(value) });
  }
  return tokens;
};

const resolvePath = (value: string, cwd: string) => {
  if (value.startsWith("~/")) return path.resolve(homedir(), value.slice(2));
  return path.resolve(cwd, value);
};

const imageBytes = (image: ImageContent) =>
  Buffer.from(image.data, "base64").byteLength;

export function validateImageSizes(sizes: number[]): void {
  if (sizes.some((size) => size > MAX_IMAGE_BYTES)) {
    throw new Error("Image exceeds the 5 MiB per-image limit");
  }
  if (
    sizes.reduce((total, size) => total + size, 0) > MAX_REQUEST_IMAGE_BYTES
  ) {
    throw new Error("Images exceed the 32 MiB request limit");
  }
}

export async function attachImagePaths(
  text: string,
  cwd: string,
  existing: ImageContent[] = [],
): Promise<{ text: string; images: ImageContent[]; attached: number }> {
  const tokens = tokenizePaths(text);
  if (tokens.length === 0) return { text, images: existing, attached: 0 };

  const images = [...existing];
  const sizes = existing.map(imageBytes);
  const identities = new Map(
    existing.map((image, index) => [
      createHash("sha256")
        .update(Buffer.from(image.data, "base64"))
        .digest("hex"),
      index + 1,
    ]),
  );
  const replacements: Array<PathToken & { placeholder: string }> = [];

  for (const token of tokens) {
    const absolutePath = resolvePath(token.value, cwd);
    let fileStat;
    try {
      fileStat = await stat(absolutePath);
    } catch {
      continue;
    }
    if (!fileStat.isFile()) continue;
    if (fileStat.size > MAX_IMAGE_BYTES) {
      throw new Error("Image exceeds the 5 MiB per-image limit");
    }

    const bytes = await readFile(absolutePath);
    const mimeType = detectMimeType(bytes);
    if (!mimeType) continue;
    const identity = createHash("sha256").update(bytes).digest("hex");
    let imageIndex = identities.get(identity);
    if (imageIndex === undefined) {
      sizes.push(bytes.byteLength);
      validateImageSizes(sizes);
      images.push({ type: "image", mimeType, data: bytes.toString("base64") });
      imageIndex = images.length;
      identities.set(identity, imageIndex);
    }
    replacements.push({ ...token, placeholder: `[image ${imageIndex}]` });
  }

  if (replacements.length === 0) return { text, images: existing, attached: 0 };
  let transformed = "";
  let cursor = 0;
  for (const replacement of replacements) {
    transformed +=
      text.slice(cursor, replacement.start) + replacement.placeholder;
    cursor = replacement.end;
  }
  transformed += text.slice(cursor);
  return { text: transformed, images, attached: replacements.length };
}

export default function registerImageAttachments(pi: ExtensionAPI): void {
  pi.on("input", async (event, ctx) => {
    if (event.source === "extension") return { action: "continue" as const };
    try {
      const result = await attachImagePaths(event.text, ctx.cwd, event.images);
      if (result.attached === 0) return { action: "continue" as const };
      return {
        action: "transform" as const,
        text: result.text,
        images: result.images,
      };
    } catch (error) {
      ctx.ui.setEditorText(event.text);
      ctx.ui.notify(
        error instanceof Error ? error.message : String(error),
        "error",
      );
      return { action: "handled" as const };
    }
  });
}
