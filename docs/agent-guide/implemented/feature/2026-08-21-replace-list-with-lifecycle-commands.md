# Replace List With Lifecycle Commands

## Problem

The former `list [<lifecycle> [<days>]]` interface made lifecycle selection a
positional parsing concern. Its no-argument default also hid which lifecycle an
agent was discovering, so the command name did not communicate the scope of
its output.

## Decision

The CLI provides one command for each lifecycle:

```text
spec-dev-tool list-exploring [<days>]
spec-dev-tool list-proposed [<days>]
spec-dev-tool list-implemented [<days>]
spec-dev-tool list-rejected [<days>]
spec-dev-tool list-archived [<days>]
```

Each command fixes its lifecycle in the command name. `<days>` is the only
optional argument, defaults to `30`, and must be a positive base-10 integer.
The `list` command and `list --help` no longer exist and are reported as unknown
commands. There is no compatibility alias or lifecycle positional form.

## Discovery behavior

Every lifecycle command searches only
`docs/agent-guide/<command-lifecycle>/`. It includes regular files with a valid
class and `YYYY-MM-DD-<topic-title>.md` filename whose filename date is within
the inclusive window from today back through `<days> - 1` days. Document
content does not need to pass `check` to be discoverable.

Results are sorted by filename date from newest to oldest and then by complete
project-relative path. Missing lifecycle directories and empty results succeed
without output. Malformed paths, future or older dates, directories, and
symlinks are ignored. Traversal errors fail without partial standard output.

## Help and errors

Top-level help lists all five commands and uses `list-exploring` in the agent
workflow. Each command supports `--help` and `-h`, shows its fixed lifecycle in
the purpose and usage, and documents the `30`-day default. Invalid days or extra
arguments point to that exact command's help page.

## Alternatives considered

### Keep list with a required lifecycle

The CLI could remove only the default and require `list <lifecycle> [<days>]`.
This still makes lifecycle selection an argument-parsing branch and makes the
command's scope invisible when commands are scanned without their arguments.

### Keep list as an alias for list-exploring

An alias would preserve the old default behavior, but it would leave two names
for the same operation and retain the ambiguity this decision removes.

### List every lifecycle in one command

A combined command would remove lifecycle selection but mix decisions in
different workflow states. Agents normally need one state at a time, and an
explicit command keeps that intent visible.

## Consequences

Command names now expose discovery scope without inspecting positional
arguments. Help and error recovery are lifecycle-specific, while the underlying
filesystem discovery and ordering behavior remains shared. Callers must replace
every old `list` invocation with the lifecycle command they actually intend.
