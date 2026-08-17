---
name: ntfy
description: Use when the user wants a push notification to their phone - pinging them when a long task finishes, an unattended run needs attention, or they explicitly ask to be notified/texted/alerted.
---

# ntfy

Push a notification to the user's phone through the self-hosted ntfy server. It reaches the phone whether or not Claude Code is open, so it is the right tool for "ping me when this is done" on a long or backgrounded task.

For a ping that only needs to reach the terminal or the Claude app, the normal `PushNotification` already covers it. Reach for ntfy when the user should get it on their phone.

Publish to the `claude` topic, which the user's phone subscribes to:

```bash
ntfy pub claude "build finished, all tests green"
```

No host or token flags needed. `~/.config/ntfy/client.yml` sets `default-host: https://ntfy.eriz.cc` and the auth token.

## Flags

- `-t "<title>"` bold title above the body
- `-p <1-5>` priority: 1 min, 3 default, 5 max (5 bypasses the phone's do-not-disturb)
- `-T <tags>` comma-separated emoji shortcodes, prepended as icons: `white_check_mark`, `warning`, `rotating_light`, `x`
- `--click <url>` URL to open when the notification is tapped

```bash
ntfy pub -t "deploy failed" -p 5 -T rotating_light claude "3 pods crashlooping on narwhal"
```
