# Prohibit Code Changes During Exploring

## Problem

The current workflow prohibits implementing the decision described by an
`exploring` document, but it does not prohibit every code change while the
document is being prepared. This distinction permits an agent to interpret
unrelated code edits, exploratory implementation, or local cleanup as outside
the documented decision and modify code before the user has answered the
document's questions.

That behavior weakens the user checkpoint. The repository may change before
the decision is sufficiently specified, even though the user expects the
exploring stage to produce only a decision document for review.

## Decision

The top-level `AGENT WORKFLOW` explicitly states that while creating or editing
an `exploring` document, the agent must not modify any other repository file.
The only authorized repository change during that workflow stage is the new or
updated exploring document. After validating the document, the agent asks every
question and stops.

The rule is stage-based rather than decision-based. It therefore prohibits
source, test, documentation, configuration, generated artifact, and other
repository changes even when an agent considers them unrelated to the
exploring document. Other repository files may change only after the user
answers every question and the document transitions out of `exploring`.

The command-specific guidance for `create` and `transition` states the same
restriction so agents entering through any help surface receive consistent
instructions. `docs/agent_doc_format.md` makes the restriction normative and
requires the exploring document to transition before any other repository file
changes.

## Alternatives considered

### Retain the decision-scoped prohibition

Continue to prohibit only implementation of the decision documented under
`exploring`. This preserves flexibility for unrelated edits, but it does not
provide the requested document-only checkpoint and leaves scope judgments to
the agent.

### Rely only on the document-format specification

Strengthen `docs/agent_doc_format.md` without changing CLI help. This would make
the normative specification precise, but `AGENTS.md` directs agents to follow
the CLI's `AGENT WORKFLOW`. Omitting the restriction from that entry point
would make the most visible operational instructions incomplete.

## Consequences

The exploring lifecycle now provides a strict document-only checkpoint. Agents
cannot combine preparation of an exploring document with any other repository
change in the same workflow stage, including an unrelated source, test,
documentation, configuration, or generated-file update. The document must
transition before another repository file changes.

Top-level, `create`, and `transition` help expose the same operational wording.
CLI tests protect that wording, and the agent-document specification records
the complete create, modify, move, and remove prohibition.
