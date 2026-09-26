# pi-eric-memory

Owned Pi memory package for Eric's agent stack.

It keeps Hermes-compatible runtime behavior while moving storage and governance into an owned package:

- persistent `MEMORY.md` and `USER.md`
- project-scoped memory under `projects-memory/`
- SQLite-backed memory and session search
- procedural skill storage
- correction governance with candidates, proposals, decisions, and proof outcomes
- bounded reflection records that require explicit candidate selection before durable writes
- migration from legacy `~/.pi/agent/pi-hermes-memory`

## Runtime layout

Default owned storage:

```text
~/.pi/agent/pi-eric-memory
```

Legacy migration source:

```text
~/.pi/agent/pi-hermes-memory
```

Project memory remains under:

```text
~/.pi/agent/projects-memory/<project>/
```

## Development

```text
npm install
npm run check
npm test
```

See `docs/hermes-contract.md` for the compatibility contract retained from Hermes.
