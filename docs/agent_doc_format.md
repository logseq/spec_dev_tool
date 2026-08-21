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
docs/agent-guide/exploring/feature/2026-08-20-issue-picker.md
```

## Lifecycle

Choose exactly one lifecycle.

| Lifecycle | Meaning | Maintenance policy |
| --- | --- | --- |
| `exploring` | A potential decision is being shaped and requires user answers before it can advance. | Refine the possible proposal, keep its final `Questions` section synchronized with the questions for the user, and do not implement it. |
| `proposed` | A design is under consideration and has not been implemented. | Update it as the proposal, alternatives, acceptance criteria, or known risks change. |
| `implemented` | The decision has been implemented and describes the current system. | Keep it synchronized with changes to actual paths, names, defaults, behavior, and other implementation facts. |
| `rejected` | The proposal was considered and deliberately declined. | Preserve the proposal and the reason for rejecting it so the same path is not reconsidered without new evidence. |
| `archived` | A formerly implemented decision is stable and no longer valuable in the active knowledge base. | Freeze it as historical context. Do not update it or treat it as authoritative documentation of the current system. |

The normal lifecycle transitions are:

```text
exploring -> proposed
exploring -> rejected
proposed -> implemented
proposed -> rejected
implemented -> archived
```

Every new document starts as `exploring`. The agent must ask the user to answer
every question in the document and wait for the answers. The agent must not
invent or infer user answers, transition the document, or implement its
decision while it remains `exploring`.

After the user answers every question, the agent may transition the document to
`proposed` or `rejected`. For `exploring -> proposed`, incorporate the user's
answers into the proposal and rewrite it to the proposed-document format. The
source document can temporarily be invalid for `exploring` while it is being
rewritten; the transition validates the content as `proposed` before moving it.
For `exploring -> rejected`, preserve the questions and relevant user answers
as context and supply the rejection reason.

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
- For an exploring document, keep `Questions` as its final level-two section.
- Do not implement a decision documented under `exploring`.

## Exploring document

Use this format while user answers are still required before a decision can
become a formal proposal or be rejected. `Questions` is required, must contain
content, and must be the final level-two section. After preparing and checking
the document, the agent must ask the user to answer every question and stop.
Implementation and lifecycle transitions are prohibited until the user has
answered them.

```markdown
# <Decision title>

## Problem

<Describe the problem and why it matters without assuming a solution.>

## Proposal

<Describe the possible decision and its current scope.>

## <Technical section>

<Add as many design-specific sections as needed.>

## Alternatives considered

### <Alternative>

<Describe the alternative and why it is not currently preferred.>

## Acceptance criteria

- <Observable condition that must be true for the proposal to be complete.>

## Risks

- <Risk, trade-off, or capability that might be intentionally given up.>

## Questions

- <Question the user must answer before the document can transition.>
```

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
