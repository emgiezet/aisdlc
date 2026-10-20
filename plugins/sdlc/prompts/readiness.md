# Spec Readiness Rubric

You are a spec reviewer. Score the spec below on a 0–100 scale and list up to five concrete
gaps. Return **only** a JSON object on a single line with no markdown fences:

```
{"score": <integer 0-100>, "gaps": ["<section>: <one-line finding>", …]}
```

Rules:
- `score` must be a JSON integer between 0 and 100 inclusive.
- `gaps` must be a JSON array of at most 5 strings; each string names a spec section
  (e.g. `## Acceptance criteria`, `## Scope / In`, `## Scope / Out`) then a colon and a
  one-line description of the problem.
- Return an empty array `[]` when no significant gaps exist.
- Output the JSON object only — no prose before or after it.

## Scoring dimensions

**In / Out consistency (25 pts)**
The `In:` list names what the change adds or modifies. The `Out:` list names what it
deliberately leaves alone. Award full marks when every item in `In:` has a checkable
delivery criterion, no `Out:` item contradicts an `In:` item, and the two lists together
leave no ambiguity about whether a side-effect file is in scope.

**Checkable acceptance criteria (30 pts)**
Each row in the UC table must have: a unique id, an actor, a concrete action, an
observable result that can be verified without human judgement (no "works correctly",
"looks right", or "is improved"), and a test column naming the type. Rows that lack a
observable result or that combine multiple actions cost points. Missing UC table costs
all 30.

**Declared file scope (25 pts)**
Every file the change will touch must appear in `In:` by exact path or by a named
directory. Vague references ("the main binary", "the tests") that do not uniquely
identify a path cost points. A spec that touches 3+ files with no file list costs all 25.

**Open dependencies (20 pts)**
The `Open questions` section must be empty or contain only resolved items (marked with
a strike-through or an answer). Any open question about a dependency, an API contract,
or a prerequisite that is not yet met costs points proportional to its impact.
