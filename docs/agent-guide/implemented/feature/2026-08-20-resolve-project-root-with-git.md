# Resolve the Project Root with Git

## Problem

Repository operations interpreted `docs/agent-guide/...` relative to the
process working directory. An agent therefore had to run `spec-dev-tool` from
the project root. Running the tool from a nested project directory could make
document discovery return no results, make validation inspect the wrong
location, or create a new `docs/agent-guide` tree below that directory.

Agents commonly retain the working directory of the file or component they
are modifying. Requiring them to change back to the project root before every
document operation added avoidable state to the workflow and made otherwise
valid commands depend on invocation location.

## Decision

The CLI uses Git to resolve the project root before performing any repository
operation. It runs:

```text
git rev-parse --show-toplevel
```

The trimmed stdout value is the absolute project root. Every agent-document
read, write, discovery, validation, and transition resolves against that root.
As a result, an agent can invoke `spec-dev-tool` from any directory inside the
project's Git worktree and receive the same behavior.

Help output does not require project-root discovery. Commands that access
agent documents resolve the root once per invocation before performing any
filesystem operation.

The Git command is executed directly rather than through a shell. A successful
result contains exactly one non-empty absolute output line. Failure to start
Git, a non-zero Git exit status, or invalid stdout is an operation error and
does not modify the filesystem.

When root discovery fails, the CLI reports:

```text
Cannot locate project root: current directory is not inside a Git worktree.
```

This failure exits with status `1`.

## Path semantics

Command-line document paths are canonical project-relative paths beginning
with `docs/agent-guide/`. They are interpreted relative to the discovered
project root, not relative to the process working directory.

For example, this command has identical behavior from the project root and
from any nested directory:

```text
spec-dev-tool check \
  docs/agent-guide/proposed/feature/2026-08-20-example.md
```

Commands continue to print canonical project-relative paths. Stable relative
output is easier for agents to reuse in later commands and does not expose a
machine-specific absolute project path.

All affected operations use the discovered root explicitly:

- `create` writes the new proposal below the root.
- `list` discovers documents below the root.
- `check <doc-path>` reads the root-relative document path.
- `check --all` discovers and validates documents below the root.
- `transition` reads, writes, and removes documents below the root.

The implementation passes the abstract resolved root through the relevant
OCaml APIs instead of changing the process working directory. This keeps path
resolution explicit and avoids hidden global state.

## Git repository behavior

The root reported by Git is authoritative. In a Git worktree, it is the
worktree root. When invoked inside a Git submodule or a nested Git repository,
the submodule or nested repository root is the project root for that
invocation.

Invocations outside a Git worktree fail rather than falling back to the
current directory or searching for marker files. The tool does not maintain a
second project-root discovery strategy.

## Alternatives considered

### Require invocation from the project root

This would have preserved the former implementation but would have left
working-directory state as an undocumented input to every repository
operation. Agents could easily issue a syntactically valid command from the
wrong directory and observe misleading or misplaced results.

### Search parent directories for project marker files

The tool could search for `dune-project`, `docs/agent-guide`, or another marker.
Marker selection introduces a second definition of the project boundary and
can become ambiguous in nested projects. Git already provides the worktree
boundary used by the development workflow.

### Fall back to the current directory when Git discovery fails

A fallback would make the same command mean different things depending on Git
availability and could recreate the accidental nested `docs/agent-guide`
problem. Root discovery therefore fails explicitly when Git cannot identify a
worktree.

## Consequences

Every repository command has identical path semantics at the worktree root and
in nested directories. `create` writes only below the discovered root; `list`
and `check --all` discover the root document tree; `check <doc-path>` reads a
canonical root-relative path; and `transition` moves documents between
lifecycle directories below the root. Successful commands continue to print
canonical project-relative paths.

Commands that access documents fail with status `1` before filesystem access
when Git cannot resolve a worktree root. Help remains independent of Git and
the filesystem. End-to-end tests cover root and nested execution, unavailable
Git, invalid Git output, execution outside a worktree, and the absence of
filesystem changes on discovery failure.

Git is now a runtime dependency for every command that accesses agent
documents, and spawning it adds a small fixed cost to each invocation. A
nested Git repository or submodule intentionally changes the resolved project
boundary, so agents must invoke the command inside the worktree they intend to
operate on. Tests construct Git worktrees instead of relying on arbitrary
temporary directories.
