import fs from "node:fs";
import path from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

type Resolution =
  | { kind: "regular" | "missing"; path: string }
  | { kind: "redirect" | "blocked"; path: string; target: string };

function approvedRoots(home: string): string[] {
  return [
    path.join(home, "nixos-config"),
    path.join(home, ".flake"),
    path.join(home, ".config"),
    path.join(home, "dev", "nixvim"),
  ];
}

function isApproved(target: string, roots: readonly string[]): boolean {
  return roots.some(
    (root) => target === root || target.startsWith(`${root}${path.sep}`),
  );
}

export function resolveManagedPath(
  input: string,
  home = process.env.HOME ?? "~",
  cwd = process.cwd(),
): Resolution {
  const lexicalRoots = approvedRoots(home);
  const canonicalRoots = [
    ...approvedRoots(fs.realpathSync.native(home)),
    fs.realpathSync.native("/tmp"),
  ];
  const candidate = path.resolve(cwd, input.replace(/^~(?=$|\/)/, home));
  let current = candidate;
  const suffix: string[] = [];

  while (true) {
    let stat: fs.Stats;
    try {
      stat = fs.lstatSync(current);
    } catch (error) {
      if (
        !(error instanceof Error) ||
        !("code" in error) ||
        error.code !== "ENOENT"
      )
        throw error;
      const parent = path.dirname(current);
      if (parent === current) return { kind: "missing", path: candidate };
      suffix.unshift(path.basename(current));
      current = parent;
      continue;
    }

    const canonical = fs.realpathSync.native(current);
    const resolved = path.join(canonical, ...suffix);

    if (stat.isSymbolicLink()) {
      if (!isApproved(resolved, canonicalRoots))
        return { kind: "blocked", path: candidate, target: resolved };
      return { kind: "redirect", path: candidate, target: resolved };
    }

    if (isApproved(candidate, lexicalRoots)) {
      if (!isApproved(resolved, canonicalRoots))
        return { kind: "blocked", path: candidate, target: resolved };
      return { kind: "redirect", path: candidate, target: resolved };
    }

    return { kind: "regular", path: candidate };
  }
}

export default function managedPaths(pi: ExtensionAPI): void {
  pi.on("tool_call", async (event, ctx) => {
    if (event.toolName !== "write" && event.toolName !== "edit")
      return undefined;
    const input = event.input.path;
    if (typeof input !== "string")
      return { block: true, reason: "Pi mutation path is missing or invalid." };

    const resolved = resolveManagedPath(input, process.env.HOME, ctx.cwd);
    if (resolved.kind === "redirect")
      return { input: { ...event.input, path: resolved.target } };
    if (resolved.kind === "blocked") {
      return {
        block: true,
        reason: `Refusing to write through unapproved symlink: ${resolved.path}`,
      };
    }
    return undefined;
  });
}
