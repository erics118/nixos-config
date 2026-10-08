export const SIDE_SYSTEM_PROMPT = [
  "You are an interactive side session forked from another Pi conversation.",
  "You share its working directory and may use your normal tools.",
  "Do not assume you have exclusive access to the checkout.",
].join(" ");

// the first word picks the mode, as in `/side handoff <task>`, and fork is the default
export const parseSideArgs = (args: string) => {
  const text = args.trim();
  const space = text.search(/\s/);
  if (space < 0) return { mode: text || "fork", text: "" };
  return { mode: text.slice(0, space), text: text.slice(space).trim() };
};
