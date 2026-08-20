# Agent Document Format

Agent documents record decisions made while developing and maintaining the
project. Each document should explain one primary decision, why it is needed,
and how its lifecycle affects the way the document is maintained.

## File location and name

Store every agent document at:

```text
docs/agent-guide/<lifecycle>/<class>/YYYY-MM-DD-<topic-title>.md
```

Use a lowercase, kebab-case topic title. The directory is part of the
document's meaning: move the document when its lifecycle changes.

Example:

```text
docs/agent-guide/proposed/feature/2026-08-20-issue-picker.md
```

## Lifecycle

Choose exactly one lifecycle.

| Lifecycle | Meaning | Maintenance policy |
| --- | --- | --- |
| `proposed` | A design is under consideration and has not been implemented. | Update it as the proposal, alternatives, acceptance criteria, or known risks change. |
| `implemented` | The decision has been implemented and describes the current system. | Keep it synchronized with changes to actual paths, names, defaults, behavior, and other implementation facts. |
| `rejected` | The proposal was considered and deliberately declined. | Preserve the proposal and the reason for rejecting it so the same path is not reconsidered without new evidence. |
| `archived` | A formerly implemented decision is stable and no longer valuable in the active knowledge base. | Freeze it as historical context. Do not update it or treat it as authoritative documentation of the current system. |

The normal lifecycle transitions are:

```text
proposed -> implemented -> archived
         \
          -> rejected
```

When moving a document from `proposed` to `implemented`, rewrite it to describe
the decision that was actually implemented, not merely the original intent.
When moving an `implemented` document to `archived`, preserve its final content
as a historical snapshot.

## Class

Choose exactly one class according to the document's primary decision.

| Class | Use for |
| --- | --- |
| `simplification` | Removing accidental complexity without changing observable behavior. |
| `bugfix` | Correcting behavior that does not match the intended behavior. |
| `feature` | Adding or changing user-visible or agent-visible capability. |
| `testing` | Changing the testing strategy, coverage, fixtures, tooling, or validation approach. |
| `architecture` | Decisions whose main subject is source-code or runtime structure, such as package boundaries, built-in graph schemas, or runtime architecture. |
| `process` | Decisions about development and maintenance workflows, tools, conventions, or engineering policy. |

There is intentionally no `refactor` class:

- Use `simplification` when internal code changes preserve observable behavior.
- Use `architecture` when the structural design itself is the primary decision.

Classify by the document's core decision, not by every change needed to
implement it:

- An architecture change made specifically to deliver a feature belongs to
  `feature`.
- A decision primarily about architecture belongs to `architecture`, even if
  it enables later features.
- If a feature decision and an architecture decision are independently
  important, write two documents and link them to each other.

A useful test is: if the feature were removed later, would the architecture
decision still be worth preserving? If so, the architecture decision should
have its own document.

## Writing rules

- Keep one primary decision per document.
- Describe the problem without assuming a particular solution.
- Put design-specific technical sections after `Proposal` or `Decision` and
  before `Alternatives considered`.
- State alternatives concretely and explain why each was not selected.
- Make acceptance criteria observable and verifiable.
- For an implemented document, describe the current implementation as fact.
  Do not leave future-tense proposal language in place.
- Use exact identifiers, paths, commands, defaults, and behavior when they are
  relevant to the decision.
- Split independently useful decisions into separate documents and link them.

## Proposed document

Use this format for a decision that is still under consideration.

```markdown
# <Decision title>

## Problem

<Describe the problem and why it matters without assuming a solution.>

## Proposal

<Describe the proposed decision and its scope.>

## <Technical section>

<Add as many design-specific sections as needed.>

## Alternatives considered

### <Alternative>

<Describe the alternative and why it was not selected.>

## Acceptance criteria

- <Observable condition that must be true for the proposal to be complete.>

## Risks

- <Risk, trade-off, or capability intentionally given up.>
```

## Implemented document

Use this format for a decision that has been implemented. It must describe the
system as it exists now and remain synchronized with the implementation.

```markdown
# <Decision title>

## Problem

<Describe the problem and why the decision was needed.>

## Decision

<Describe the implemented decision and its scope.>

## <Technical section>

<Document relevant implementation details.>

## Alternatives considered

### <Alternative>

<Describe the alternative and why it was not selected.>

## Consequences

<Describe the benefits, costs, constraints, and operational effects of the
decision.>
```

## Rejected document

Use this format for a proposal that was considered but not adopted. Preserve
enough of the original proposal to make the rejection understandable.

```markdown
# <Decision title>

## Problem

<Describe the problem the proposal attempted to solve.>

## Proposal

<Describe the proposal that was considered.>

## <Technical section>

<Preserve the relevant details of the original proposal.>

## Alternatives considered

### <Alternative>

<Describe the alternative and why it was not selected at the time.>

## Rejection reason

<Explain why the proposal was rejected and what evidence or constraints drove
the decision.>
```

## Archived document

An archived document is an implemented document moved to the `archived`
directory. Keep the implemented-document structure and freeze the content at
the point of archival. Archived documents are historical records, not the
source of truth for current behavior.
