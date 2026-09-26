import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { TuiAltScreen } from "@earendil-works/pi-tui";

const BASE_WHEEL_SCROLL_LINES = 5;
const ALT_WHEEL_SCROLL_LINES = 25;

type PatchedAltScreen = {
  getWheelScrollLines?: (button: number) => number;
};

let previousDescriptor: PropertyDescriptor | undefined;
let installed: ((button: number) => number) | undefined;

function installPatch(): void {
  if (installed) return;
  const proto = TuiAltScreen.prototype as unknown as PatchedAltScreen;
  previousDescriptor = Object.getOwnPropertyDescriptor(
    proto,
    "getWheelScrollLines",
  );
  installed = (button) =>
    (button & 8) !== 0 ? ALT_WHEEL_SCROLL_LINES : BASE_WHEEL_SCROLL_LINES;
  Object.defineProperty(proto, "getWheelScrollLines", {
    configurable: true,
    writable: true,
    value: installed,
  });
}

function removePatch(): void {
  if (!installed) return;
  const proto = TuiAltScreen.prototype as unknown as PatchedAltScreen;
  if (proto.getWheelScrollLines === installed) {
    if (previousDescriptor)
      Object.defineProperty(proto, "getWheelScrollLines", previousDescriptor);
    else delete proto.getWheelScrollLines;
  }
  previousDescriptor = undefined;
  installed = undefined;
}

export default function registerFullscreenTweaks(pi: ExtensionAPI) {
  pi.on("session_start", installPatch);
  pi.on("session_shutdown", removePatch);
}
