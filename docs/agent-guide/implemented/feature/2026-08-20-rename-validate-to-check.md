# Rename Validate to Check and Add Whole-Repository Checking

## Problem

The original `validate` command checked one known agent-document path, but its
name was more formal and less direct than the other CLI verbs. Agents also
could not ask `spec-dev-tool` to check the complete agent-document tree. They
had to discover paths with another command or a shell pipeline and invoke the
command once per path.

That manual workflow can miss documents, stops at inconsistent points when a
document is invalid, and makes every caller implement its own aggregation and
exit-status behavior. It can also omit malformed Markdown paths that belong
under `docs/agent-guide/` but are not returned by path-aware discovery.

## Decision

The CLI uses the `check` command and provides an explicit `--all` mode:

```text
spec-dev-tool check <doc-path>
spec-dev-tool check --all
```

`check <doc-path>` preserves the observable checking behavior of the removed
`validate <doc-path>` command. `check --all` checks every agent-document
candidate in the current project and reports every invalid document in one
run.

`validate` is absent from command dispatch, help output, tests, user-facing
documentation, and the public OCaml interface. Invoking
`spec-dev-tool validate ...` is a usage error; there is no deprecated alias or
compatibility path. The public entry points are `Agent_doc.check` for one path
and `Agent_doc.check_all` for complete-project checking. Internal helpers use
validation terminology where it describes content validation accurately.

## Command interface

The two command forms are mutually exclusive. `<doc-path>` has the same path,
file-reading, lifecycle, and content requirements currently enforced by
`validate <doc-path>`. `--all` is a reserved option and is not interpreted as a
document path.

Missing arguments, extra arguments, unknown options, and any use of the old
`validate` command are usage errors. They write the top-level usage text to
standard error and exit with status `2`. The help output contains both `check`
forms and does not mention `validate`.

## Whole-repository discovery

`check --all` treats the current working directory as the project root and
recursively scans `docs/agent-guide/` before checking any content.

- Include every regular file below that directory whose filename ends in
  `.md`. A Markdown file with a malformed lifecycle, class, nesting depth,
  date, or topic remains a candidate so the normal path checker can report it.
- Ignore non-Markdown files and directories.
- Do not follow symbolic links to directories. A symbolic link to a file is
  not a regular-file candidate and is ignored.
- If `docs/agent-guide/` does not exist, treat the repository as containing no
  agent documents.
- Sort candidate project-relative paths lexicographically before checking them
  so diagnostics and success output are deterministic.
- If discovery fails because of a permission or I/O error, report the error
  and exit without checking a partial candidate set.

This discovery is deliberately different from `list`. `list` selects one
lifecycle and date window and returns only well-formed paths, while
`check --all` must cover every lifecycle, every date, and malformed Markdown
paths that need correction.

## Checking, output, and exit status

For `check <doc-path>`, retain the existing output shape with the new command
terminology. A valid document writes:

```text
Valid agent document: <doc-path>
```

to standard output and exits with status `0`. An invalid or unreadable
document writes its path and every checking error to standard error and exits
with status `1`.

For `check --all`, check every discovered candidate even after one or more
documents fail. For each valid document, write the same `Valid agent document`
line to standard output. For each invalid document, write the same invalid
document header and complete error list used by single-document checking to
standard error. Emit both streams in sorted candidate order within each
stream. Do not print a summary, header, or count.

Exit with status `0` only when discovery succeeds and every candidate is
valid. An empty candidate set is successful and produces no output. Exit with
status `1` after reporting all document failures, or when repository discovery
fails.

## Alternatives considered

### Keep validate as an alias

The CLI could accept both `validate` and `check` during a deprecation period.
This was not selected because it leaves two names for the same operation and
extends an obsolete interface that can be removed directly.

### Make check without a path check everything

`spec-dev-tool check` could imply whole-repository checking. This was not
selected because an explicit `--all` communicates the potentially broad and
noisy scope, while a missing path remains detectable as a usage mistake.

### Accept an arbitrary directory

The command could recursively check any positional directory. This was not
selected because agent documents have one defined project root, and arbitrary
directory traversal introduces path-base and scope ambiguity without serving
the requested repository-wide operation.

### Build check --all from list output

The command could invoke the existing discovery behavior once per lifecycle.
This was not selected because `list` applies a date window and excludes
malformed agent-document paths. Both behaviors would allow `check --all` to
miss files that it is expected to diagnose.

### Stop after the first invalid document

Whole-repository checking could fail fast. This was not selected because the
caller would need repeated runs to discover independent errors, defeating the
purpose of an aggregate check.

## Consequences

Agents can check either one known document or the complete agent-document tree
with one CLI verb. Whole-repository discovery includes malformed Markdown
paths and reports every content failure in one run, while sorting each output
stream deterministically. The obsolete CLI command and public OCaml entry
point no longer exist, so callers must use `check` directly.

`check --all` is explicit and unbounded because it reads every Markdown
regular file under `docs/agent-guide/`; large repositories can therefore
produce substantial output. Filesystem changes after discovery can make a
candidate unreadable or alter its content, in which case the candidate is
reported as a normal check failure. Valid output uses standard output and
invalid output uses standard error, so relative ordering across the two
streams is not defined even though ordering within each stream is stable.

End-to-end tests cover both command forms, removal of `validate`, mixed valid
and invalid trees, malformed paths, every lifecycle, deterministic ordering,
ignored entries, missing and empty roots, traversal errors, and exit statuses.
