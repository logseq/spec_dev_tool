# Add Exploring Lifecycle

## Problem

Agent documents previously started at `proposed`, even when a potential
decision still had unresolved questions. This made an incomplete exploration
look like a formal proposal and provided no lifecycle edge for either refining
or rejecting it before proposal review.

## Decision

The CLI supports `exploring` as the lifecycle immediately before `proposed`.
New documents are created in `docs/agent-guide/exploring/<class>/`, and `list`
uses `exploring` as its default lifecycle.

The agent prepares and checks the exploring document, asks the user to answer
every question, and waits. Until the user has answered every question, the
agent must not transition the document or implement its decision. Answers
invented or inferred by the agent do not satisfy this requirement.

The supported lifecycle transitions are:

```text
exploring -> proposed
exploring -> rejected
proposed -> implemented
proposed -> rejected
implemented -> archived
```

## Document structure

An exploring document uses the proposed-document sections and adds a required
`## Questions` section. `Questions` must contain content and must be the final
level-two section. The `create` command includes this section as the final part
of every generated document.

After the user answers every question, the agent may incorporate those answers
into the proposal and rewrite the source to the proposed-document format. The
`exploring -> proposed` transition validates the rewritten content as
`proposed` before moving it. This follows the same target-first validation
model used when a proposal is rewritten for `proposed -> implemented`.

For `exploring -> rejected`, the user must also have answered every question.
The source must still be a valid exploring document. The command preserves its
questions, relevant answers, and proposal context, adds the required rejection
reason, validates the generated rejected document, and only then moves it.

## Command behavior

`lifecycle_of_string`, path checking, `check --all`, explicit `list` selection,
and help output recognize `exploring`. The transition command accepts
`proposed` as a target only for an exploring source. A non-empty, single-line
`--reason` remains required for both transitions to `rejected`.

## Alternatives considered

### Draft

`draft` is concise and familiar, but it describes document completeness more
than the state of the decision. It can also imply that only prose cleanup is
needed when substantive investigation is still open.

### Discovery

`discovery` emphasizes research, but it is a noun while the existing lifecycle
names describe the decision's state. It also suggests a broader research phase
than the focused questions recorded by the document.

### Shaping

`shaping` communicates that a proposal is taking form, but it is less widely
understood and introduces product-development terminology that the rest of the
format does not use.

## Consequences

Agents can distinguish unresolved exploration from a formal proposal, and the
default creation and discovery workflow now starts in that state. Every valid
exploring document exposes its questions for the user at a predictable
location. The mandatory user checkpoint prevents agents from treating inferred
answers as authorization and prevents implementation from starting during
exploration. The additional lifecycle adds one explicit rewrite step before
proposal review and one more value to every exhaustive lifecycle match.
