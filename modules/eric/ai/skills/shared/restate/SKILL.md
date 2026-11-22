---
name: restate
description: Read my request back before doing any of it
disable-model-invocation: true
---

# restate

Give a readback of the request this skill was invoked with, then stop. With no text, read back my
previous message. Change no files. Read whatever you need to settle what my words point at.

The readback has three parts, each item on its own line:

- `Goal:` one sentence naming the end state I want, not the steps to it
- `Constraints:` every limit, example, and named thing in my message, each quoted in my words
- `Readings:` each word or reference that has two readings (a "this", a count, a loosely named file
  or option), with the reading you picked and the source that settled it. If no source settled
  it, say so

The readback is done when every constraint in my message has its own quoted line. End with
`Go?` as the last line, and start the work only after I confirm or correct the readback.
