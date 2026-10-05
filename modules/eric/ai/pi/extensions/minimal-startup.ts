import { type ExtensionAPI, VERSION } from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";

export default function registerMinimalStartup(pi: ExtensionAPI) {
  pi.on("session_start", (_event, ctx) => {
    if (ctx.mode !== "tui") return;
    ctx.ui.setHeader(
      (_tui, theme) => new Text(theme.fg("muted", `Pi v${VERSION}`), 0, 0),
    );
  });
}
