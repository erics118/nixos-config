import { execFile } from "node:child_process";
import { homedir } from "node:os";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// record on the tmux pane how to resume this session, through the hook claude and codex run
export default function (pi: ExtensionAPI) {
  pi.on("session_start", (_event, ctx) => {
    // a --no-session run has no file, so there is nothing to resume
    const session = ctx.sessionManager.getSessionFile();
    if (!process.env.TMUX_PANE || !session) return;
    const hook = execFile(
      `${homedir()}/.agents/hooks/tmux-agent-resume.sh`,
      ["pi"],
      () => {},
    );
    hook.stdin?.end(JSON.stringify({ session_id: session }));
  });
}
