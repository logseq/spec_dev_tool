# Add a Transition Command

## Problem

An agent document's lifecycle is encoded in its directory, but
`spec-dev-tool` originally could not perform a lifecycle transition. Agents
had to edit the document, determine whether the requested transition was
allowed, construct the destination path, and move the file with a system
command.

System file tools can move a document, but they do not understand the agent
document lifecycle. They can therefore create an unsupported transition, move
content that does not satisfy the target lifecycle's structure, or overwrite
an existing destination. These are project-specific invariants and should not
be delegated to generic filesystem commands.

## Decision

The CLI provides a `transition` command that validates and moves an existing
agent document to a target lifecycle:

```text
spec-dev-tool transition <doc-path> implemented
spec-dev-tool transition <doc-path> rejected --reason "<sentence>"
spec-dev-tool transition <doc-path> archived
```

The command does not infer transition prose. The agent is responsible for
changing proposal language into an implemented decision because that work
requires semantic judgment. For a rejection, the caller supplies the semantic
content as a required one-sentence reason, and the command performs only the
deterministic structural conversion. The command otherwise enforces lifecycle
and filesystem invariants.

## Command behavior

`<doc-path>` must be a project-relative agent document path in the form defined
by `docs/agent_doc_format.md`. `<target-lifecycle>` must be `implemented`,
`rejected`, or `archived`.

A `proposed -> rejected` transition requires
`--reason "<sentence>"`. The reason must be one non-empty, single-line command
argument after leading and trailing whitespace is removed. Callers must quote a
reason that contains spaces. The command writes the trimmed reason verbatim as
the body of `## Rejection reason`; it does not generate, complete, or summarize
the reason. The CLI treats the single-line value as one sentence rather than
attempting to validate natural-language grammar.

`--reason` is invalid for every other lifecycle edge. A missing, empty, or
multi-line rejection reason is a usage error.

The command supports exactly these transitions:

```text
proposed -> implemented
proposed -> rejected
implemented -> archived
```

The source lifecycle is derived from `<doc-path>`. The destination retains the
source class, filename date, and topic:

```text
docs/agent-guide/<target-lifecycle>/<class>/YYYY-MM-DD-<topic-title>.md
```

Before changing the filesystem, the command:

1. Parses and validates the source path.
2. Confirms that the requested lifecycle edge is supported.
3. Validates the presence or absence of `--reason` for that edge.
4. Reads the source document and prepares the target content according to the
   selected transition.
5. Validates the prepared content against the target lifecycle.
6. Confirms that the destination does not already exist.

After every check succeeds, the command creates the target class directory if
needed, creates the destination exclusively, writes the prepared content, and
removes the source. Exclusive destination creation prevents overwrite even if
another process creates the destination after the initial conflict check. A
write or source-removal failure removes the destination created by the command
and leaves the source document available at its original path.

On success, the command writes the destination's project-relative path to
standard output and exits with status `0`. Invalid command syntax, an invalid
target lifecycle, an unsupported lifecycle edge, or an invalid `--reason`
usage exits with status `2`. Path, content-validation, destination-conflict,
directory-creation, and move failures write diagnostics to standard error and
exit with status `1`.

## Content preparation workflow

Before a `proposed -> implemented` transition, an agent rewrites the document
in place to replace the proposal with the decision that was actually
implemented and updates the required sections to the implemented-document
format. An `implemented -> archived` transition requires no content rewrite
because both lifecycles use the implemented-document structure.

The source document can temporarily fail validation for its current lifecycle
while this rewrite is in progress. `transition` resolves that temporary state
by validating against the requested target lifecycle and moving the valid
result into the matching directory.

For `proposed -> rejected`, the source must still be a valid proposed document.
The command converts it deterministically by preserving its title and every
section, moving `Acceptance criteria` and `Risks` before
`Alternatives considered`, and appending `Rejection reason` with the supplied
reason. Moving the proposal-only sections preserves their historical content
while placing all optional material before the required rejection sections.
The generated document must pass rejected-document validation before the
filesystem is changed.

## Alternatives considered

### Continue using system move commands

Agents could continue using `mv` after editing a document. This was not
selected because a generic move command cannot enforce allowed lifecycle
edges, validate content against the destination lifecycle, or derive the
destination consistently without overwriting an existing document.

### Automatically infer transition prose

The command could generate an implemented decision, rejection reason, or
consequences from the proposal. This was not selected because those lifecycle
transitions require semantic judgment. The rejection transformation only
reorders known sections and inserts the caller's reason verbatim; it does not
invent or summarize any prose.

### Allow arbitrary lifecycle moves

The command could accept any source and target lifecycle pair. This was not
selected because it would bypass the lifecycle defined in
`docs/agent_doc_format.md`, including by moving rejected or archived history
back into an active state.

## Consequences

Agents have one project-aware operation for every supported lifecycle edge.
The command preserves class, date, and topic; validates target content before
creating destination directories; never overwrites a destination; and prints
only the project-relative destination path on success. Unsupported edges,
invalid reason usage, invalid paths, invalid content, non-regular sources, and
filesystem conflicts fail without removing the source document.

The implemented and archived transitions preserve content byte-for-byte. The
rejected transition preserves the proposal sections, moves `Acceptance
criteria` and `Risks` before `Alternatives considered`, and appends exactly one
`Rejection reason` containing the trimmed caller-provided value. Treating a
single-line value as one sentence avoids unreliable natural-language parsing,
but it cannot detect multiple grammatical sentences on the same line.

Rewriting a proposal into implemented-document form temporarily makes the
source invalid for its current lifecycle until `transition` succeeds. A
filesystem failure can leave empty destination directories, although the
source remains available. End-to-end tests cover every supported edge,
failure categories, output and exit statuses, deterministic rejection
conversion, destination conflicts, and no-mutation guarantees.
