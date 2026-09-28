# Plan format

## Header

Every plan starts with this header:

```markdown
# <Feature> Plan

**Goal:** <one sentence>

**Approach:** <2-3 sentences>

## Requirements

<every settled requirement with its exact value, one per line>

## Global Constraints

<rules every task must obey (versions, naming, formats, platforms), one per line, exact values verbatim>

## Files

<every file created or modified, each with its one responsibility>

## Review Focus

<every input or failure mode the tasks' checks did not exercise before self-review whose failure a person using the result would notice, most likely first, each naming the input and the behavior a person would expect; each has its check added to the owning task>

---
```

## Task

````markdown
### Task N: <deliverable>

**Files:**

- Create: `<exact path>`
- Modify: `<exact path>:<line range>`

**Interfaces:**

- Consumes: <exact names this task uses from earlier tasks, or none>
- Produces: <exact names later tasks rely on, or none>

**Check:** `<command that proves the task done>` Expected: <result>

- [ ] **Step 1: <one action>**

```<language>
<the exact code, text, or config>
```

- [ ] **Step 2: <run something>**

Run: `<exact command>`
Expected: <exact or characteristic output>
````

A test-driven task opens with the failing test and a run whose Expected is the failure, then the implementation and a run whose Expected is the pass. Any other task states its Expected before the step that should produce it.

The Interfaces block is how an executor who reads only this task learns the names its neighbors use.
