import { execFile } from "node:child_process";
import { homedir } from "node:os";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// record on the tmux pane how to resume this session, through the hook claude and codex run
export default function (pi: ExtensionAPI) {
  pi.on("session_start", (_event, ctx) => {
    if (!process.env.TMUX_PANE) return;
    const session =
      ctx.sessionManager.getSessionFile() ?? ctx.sessionManager.getSessionId();
    const hook = execFile(
      `${homedir()}/.agents/hooks/tmux-agent-resume.sh`,
      ["pi"],
      () => {},
    );
    hook.stdin?.end(JSON.stringify({ session_id: session }));
  });
}
