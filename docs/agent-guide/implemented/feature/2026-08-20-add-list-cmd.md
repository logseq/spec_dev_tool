# Discover Recent Agent Documents with a List Command

## Problem

Agents can create and validate a document when they already know its class,
lifecycle, or path, but they cannot discover the documents that already exist
through `spec-dev-tool`. They must inspect the directory tree with external
shell commands and understand the path convention before they can find prior
decisions.

This makes document discovery dependent on the caller's shell and operating
system, produces inconsistent ordering, and encourages agents to start work
without first reviewing relevant project decisions.

## Decision

`spec-dev-tool` provides a `list` command that discovers agent documents under
the current project's
`docs/agent-guide/` directory and writes their project-relative paths to
standard output. The command selects one lifecycle, limits results to a recent
date window, and orders them by the date encoded in each document filename.

The command is intentionally limited to discovery. It does not validate file
content, summarize decisions, or change document lifecycle. Callers use the
existing `validate <doc-path>` command when they need to check a discovered
document.

## Command interface

The supported command forms are:

```text
spec-dev-tool list
spec-dev-tool list <lifecycle>
spec-dev-tool list <lifecycle> <days>
```

`<lifecycle>` must be one of `exploring`, `proposed`, `implemented`, `rejected`,
or `archived`. It defaults to `exploring` when omitted. `<days>` must be a
positive base-10 integer and defaults to `30` when omitted. A caller that wants
to set `<days>` must also provide `<lifecycle>`; there is no days-only
positional form.

An invalid lifecycle, a non-numeric or non-positive days value, or additional
arguments is a usage error and exits with status `2`, consistent with the
existing command-line interface.

The top-level help output includes `list` alongside `create` and `validate`.

## Discovery rules

The command treats the current working directory as the project root and scans
`docs/agent-guide/<lifecycle>/` recursively, where `<lifecycle>` is the selected
or default lifecycle.

- Include regular files whose paths match the agent-document class and filename
  structure `<class>/YYYY-MM-DD-<topic-title>.md`.
- Read the document date from the `YYYY-MM-DD` filename prefix. Do not use file
  creation, modification, or access timestamps.
- For a `<days>` value of `N`, include dates from `today - (N - 1)` through
  `today`, inclusive, using the local calendar date. Exclude future-dated
  documents.
- Do not follow symbolic links to directories.
- Ignore non-Markdown files, malformed paths, filenames without a valid
  calendar date, and directories themselves.
- Return an empty result when the selected lifecycle directory does not exist.
  A repository without matching agent documents is a valid state.
- Report other traversal failures, including permission and I/O errors, rather
  than returning a partial result.

Discovery does not read or validate document content. A document with a valid
path and filename remains discoverable even when its Markdown content would
fail `validate`.

## Output and exit status

Write one project-relative path per line using `/` as the path separator. Sort
documents by their filename date from newest to oldest. When two documents
have the same date, sort their complete relative paths lexicographically in
ascending order so output is deterministic regardless of filesystem
enumeration order. Do not print headers, counts, or explanatory text to
standard output; the path-only format can be consumed directly by agents and
shell pipelines.

Exit with status `0` after a successful scan, including an empty scan. If the
scan fails, write a diagnostic to standard error and exit with status `1`.

## Alternatives considered

### Require callers to use filesystem commands

Agents could continue using commands such as `find` or `rg --files`. This was
not selected because the invocation, filtering, path format, and ordering would
remain the responsibility of every caller and would vary across platforms.

### Use check --all for discovery

`check --all` traverses and checks every Markdown candidate. It is not a
replacement for `list` because discovery and content checking have different
semantics: `list` returns well-formed paths even when their content is invalid,
while `check --all` diagnoses invalid paths and content and does not provide
lifecycle or date-window selection.

### List every lifecycle and document age by default

The command could return the entire agent-document tree without filters. This
was not selected because active proposals are the most common starting point
for agent work, while an unbounded history becomes noisy as a repository grows.
Explicit lifecycle and days arguments still allow callers to widen or redirect
the search when needed.

### Maintain an index document

The project could maintain a generated or hand-written index of agent
documents. This was not selected because the index would duplicate filesystem
state and could become stale whenever documents are created or moved between
lifecycle directories.

## Consequences

Agents and shell pipelines can discover recent documents through one stable,
path-only interface without reproducing the repository's path rules. End-to-end
tests cover command defaults, every lifecycle, custom and inclusive date
windows, ordering, malformed entries, invalid document content, missing
directories, traversal failures, and usage errors.

Every invocation performs a complete recursive scan and sort of the selected
lifecycle tree. Discovery deliberately includes documents with invalid content
and excludes malformed paths, future dates, and symbolic-link directories.
Date-window boundaries depend on the machine's local calendar date, so machines
in different time zones can briefly return different results. The path-only
output does not include titles or other document metadata.
