---
name: test-driven-development
description: Use when implementing a feature or fixing a bug, before writing the implementation. Write the failing test first, watch it fail, then make it pass.
---

# Test-Driven Development

## Iron law

NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST. If you wrote code before the test, delete it and start from the test. Delete means delete: not kept as reference, not adapted while writing the test.

If you did not watch the test fail, you do not know it tests the right thing. A test written after the code passes on the first run, which proves nothing.

Exceptions, and only with Eric's say-so: throwaway exploration (then throw it away and restart under TDD), generated code, config files.

## Red, green, refactor

### RED: write the failing test

One test, one behavior, a name that states the behavior. Assert on real behavior, not on a mock's behavior. Before writing it, name the production change that would make it fail.

Done when: the test exists and expresses one intended behavior.

### RED: watch it fail

Run it. Confirm it fails, does not error, and fails for the right reason: the feature is missing, not a typo or bad import.

- Passes already: it tests existing behavior. Fix the test.
- Errors instead of failing: fix the error and rerun until it fails cleanly.

Done when: you have seen a clean failure with the expected message.

### GREEN: minimal code to pass

The simplest code that passes this test. No extra options, no features the test does not demand, no refactoring of nearby code.

Run it. Confirm this test passes and nothing else regressed, with clean output.

Done when: this test passes and the rest stay green.

### REFACTOR: clean up on green

Only once green. Remove duplication, improve names, extract helpers. Add no behavior. Stay green throughout.

Done when: the code is clean and every test still passes.

Then the next failing test for the next behavior.

## Bug fixes

Reproduce the bug as a failing test first, then run the cycle. The test proves the fix and guards against regression. Never fix a bug without a test.

## Listen to a hard test

A test that is hard to write is telling you the design is wrong, not that TDD is wrong. Hard to test means hard to use. Must mock everything means too coupled. Simplify the interface, do not skip the test.

## Stop and start over

Any of these means delete the code and restart from a failing test:
- Production code written before its test.
- A new test that passes on the first run.
- You cannot say why the test failed.
- "I'll add tests after," "I already tested it by hand," or "just this once."
