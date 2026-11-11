---
name: autonomous
description: Turn autonomous mode on or off for this conversation
disable-model-invocation: true
---

The argument is `on` or `off`. Run `~/.agents/bin/agent-mode.sh on` or `~/.agents/bin/agent-mode.sh off` to match it. With no argument, run `~/.agents/bin/agent-mode.sh` alone and report the mode it prints.

After `on`, reply with `Autonomous mode: ON for this conversation` and follow [rules.md](rules.md) from now on. From the next prompt, a hook repeats the mode and those rules with every message. After `off`, reply with `Autonomous mode: OFF`. Manual mode applies from then on.

If the script fails, show its error and stay in manual mode.
