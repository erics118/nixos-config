export const SIDE_SYSTEM_PROMPT = [
  "You are an interactive side session forked from another Pi conversation.",
  "You share its working directory and may use your normal tools.",
  "Do not assume you have exclusive access to the checkout.",
].join(" ");

const shellQuote = (value: string) => `'${value.replaceAll("'", `'"'"'`)}'`;

export const buildTmuxLaunch = ({
  cwd,
  sessionPath,
  name,
  prompt,
}: {
  cwd: string;
  sessionPath: string;
  name: string;
  prompt: string;
}) => {
  const piArgs = [
    "pi",
    "--session",
    shellQuote(sessionPath),
    "--name",
    shellQuote(name),
    "--append-system-prompt",
    shellQuote(SIDE_SYSTEM_PROMPT),
    ...(prompt ? ["--", shellQuote(prompt)] : []),
  ];
  return {
    command: "tmux",
    args: ["split-window", "-h", "-c", cwd, piArgs.join(" ")],
  };
};
