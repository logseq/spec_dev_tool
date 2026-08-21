# Add Agent-Oriented CLI Help

## Problem

The top-level help contained only command syntax. An agent could see which
arguments existed but could not determine when to use a command, which values
were valid, what defaults applied, what output to expect, or which command
should follow a successful operation.

This forced the agent to inspect source code or retry commands to discover the
CLI contract. Usage errors made recovery harder by printing the complete
top-level usage text instead of directing the agent to the relevant command.
As the CLI grows, adding every detail to one usage block would also make common
help and error output increasingly noisy.

## Decision

Help is an agent-facing operational guide with two levels:

- Top-level help describes the agent document workflow, summarizes commands,
  lists shared values, and defines exit statuses.
- Command-level help describes one command's purpose, usage, constraints,
  output, and next step.

The help output is the authoritative usage guide. A project's `AGENTS.md`
should only need one bootstrap instruction:

```markdown
Use `spec-dev-tool` to manage agent decision documents; run
`spec-dev-tool --help` and follow its `AGENT WORKFLOW`.
```

Starting from that instruction, an agent discovers the complete operational
path without reading CLI source code or duplicating command details in
`AGENTS.md`:

```text
AGENTS.md
  -> spec-dev-tool --help
  -> AGENT WORKFLOW
  -> spec-dev-tool <command> --help
  -> execute the command
  -> follow NEXT STEP
```

This bootstrap assumes that `spec-dev-tool` is installed and available on
`PATH`. Installation and executable discovery are outside this decision.

The CLI supports these help forms:

```text
spec-dev-tool --help
spec-dev-tool -h
spec-dev-tool <command> --help
spec-dev-tool <command> -h
```

All help forms write to stdout and exit with status `0`. They do not access the
filesystem, resolve the Git project root, or require a valid project.

## Top-level help

The top-level help is workflow-first rather than a bare syntax listing:

```text
spec-dev-tool manages agent decision documents in docs/agent-guide/.

AGENT WORKFLOW
  Discover decisions by lifecycle:
    spec-dev-tool list-exploring
    spec-dev-tool list-proposed

  Start a decision before implementation:
    spec-dev-tool create <class> <doc-name>

  Validate document edits:
    spec-dev-tool check <doc-path>

  Wait for required user input:
    Ask the user to answer every question in the document.
    Do not implement a document while its lifecycle is exploring.

  Record a decision outcome:
    spec-dev-tool transition <doc-path> proposed
    spec-dev-tool transition <doc-path> implemented
    spec-dev-tool transition <doc-path> rejected --reason "<sentence>"

  Retire stable historical context:
    spec-dev-tool transition <doc-path> archived

  Before completing repository work:
    spec-dev-tool check --all

COMMANDS
  create            Create an exploring agent document.
  list-exploring    List recent exploring documents.
  list-proposed     List recent proposed documents.
  list-implemented  List recent implemented documents.
  list-rejected     List recent rejected documents.
  list-archived     List recent archived documents.
  check             Validate one or all agent documents.
  transition        Move a document to its next lifecycle.

Run 'spec-dev-tool <command> --help' for command details.

VALUES
  class:
    simplification | bugfix | feature | testing | architecture | process

  lifecycle:
    exploring | proposed | implemented | rejected | archived

EXIT STATUS
  0  Command completed successfully.
  1  Document validation or filesystem operation failed.
  2  Command arguments are invalid.
```

The workflow examples are copyable command shapes. Detailed edge cases remain
in command-level help so that the top-level output stays scannable.

## Command-level help

Every command-level help page uses the same information order:

1. `PURPOSE`
2. `WHEN TO USE`
3. `USAGE`
4. `ARGUMENTS` or `CONSTRAINTS`
5. `OUTPUT`
6. `NEXT STEP`

The stable order lets an agent locate operational information without
interpreting a different layout for every command.

### Create help

```text
PURPOSE
  Create an exploring agent document using today's date and the exploring
  document template.

WHEN TO USE
  Use while open questions still prevent a formal proposal.

USAGE
  spec-dev-tool create <class> <doc-name>

ARGUMENTS
  <class> is one of:
    simplification | bugfix | feature | testing | architecture | process

  <doc-name> must be lowercase kebab-case.

OUTPUT
  Prints the created canonical project-relative path.

NEXT STEP
  Replace the template prompts, then run:
    spec-dev-tool check <created-path>
  Ask the user to answer every question in the document.
  Wait for the answers before any lifecycle transition.
  Do not implement a document while its lifecycle is exploring.
```

### Lifecycle list help

Each lifecycle command has its own help page. For example,
`list-exploring --help` prints:

```text
PURPOSE
  List recent exploring agent documents, newest first.

WHEN TO USE
  Use to discover recent decisions in the exploring lifecycle.

USAGE
  spec-dev-tool list-exploring [<days>]

ARGUMENTS
  <days> defaults to 30 and must be a positive base-10 integer.

OUTPUT
  Prints one canonical project-relative document path per line.
  An empty result produces no output and is successful.

NEXT STEP
  Read relevant documents before changing the repository.
```

`list-proposed`, `list-implemented`, `list-rejected`, and `list-archived`
replace `exploring` with their fixed lifecycle in the purpose, when-to-use, and
usage lines. The obsolete `list` command has no help page.

### Check help

```text
PURPOSE
  Validate agent document paths, lifecycle-specific structure, and content.

WHEN TO USE
  Check a document after editing it. Check all documents before completing
  repository work.

USAGE
  spec-dev-tool check <doc-path>
  spec-dev-tool check --all

ARGUMENTS
  <doc-path> is a canonical project-relative agent document path.
  --all discovers every document below docs/agent-guide/.

OUTPUT
  Prints a validity result for each checked document.
  Validation failures are written to stderr and exit with status 1.

NEXT STEP
  Fix every reported error. After a successful single-document check, continue
  editing or transition the document when its decision outcome is known.
```

### Transition help

```text
PURPOSE
  Record a decision outcome by moving its document to the next lifecycle.

WHEN TO USE
  Use after exploration produces a proposal or rejection, after a proposal is
  implemented or rejected, or after implemented documentation becomes stable
  historical context.

USAGE
  spec-dev-tool transition <doc-path> proposed
  spec-dev-tool transition <doc-path> implemented
  spec-dev-tool transition <doc-path> rejected --reason "<sentence>"
  spec-dev-tool transition <doc-path> archived

CONSTRAINTS
  Supported transitions:
    exploring   -> proposed
    exploring   -> rejected
    proposed    -> implemented
    proposed    -> rejected
    implemented -> archived

  <doc-path> must be a canonical project-relative path.
  An exploring document may transition only after the user has answered every question.
  Do not implement a document while its lifecycle is exploring.
  Rewrite an exploration to proposed format before transitioning it to
  proposed. Rewrite a proposal to implemented format before transitioning it
  to implemented.
  A rejection reason is required, non-empty, and single-line.
  --reason is valid only for transitions to rejected.

OUTPUT
  Prints the destination canonical project-relative path.

NEXT STEP
  Run:
    spec-dev-tool check <destination-path>
```

## Usage error guidance

Invalid arguments write one specific error and one relevant help command to
stderr, then exit with status `2`. Do not append the complete top-level help.

For a known command, direct the agent to that command's help:

```text
Error: transition to rejected requires --reason <sentence>
Try: spec-dev-tool transition --help
```

For an unknown command, direct the agent to top-level help:

```text
Error: unknown command: inspect
Try: spec-dev-tool --help
```

Missing arguments, extra arguments, invalid enum values, invalid `days`, and
invalid option placement are usage errors. Document validation failures and
filesystem failures remain operation errors with status `1`; they do not
include a help suggestion because changing command syntax cannot resolve them.

## Dispatch and maintenance

The implementation keeps explicit OCaml command dispatch. Exhaustive patterns
for top-level and command-level help precede patterns that execute repository
operations, ensuring help never triggers project discovery.

One top-level help string and one help string per command define the output.
Usage-error helpers take a command topic so error paths cannot accidentally
print unrelated help. The dispatch has no deprecated help forms, compatibility
aliases, or fallback parser.

This decision is compatible with
[`2026-08-20-resolve-project-root-with-git.md`](2026-08-20-resolve-project-root-with-git.md):
help is location-independent, while operational commands resolve paths against
the Git project root.

## Alternatives considered

### Put all details in top-level help

A single comprehensive page is simple to implement, but it grows with every
command and repeats irrelevant information after a localized argument error.
It also makes the agent scan past command details to find the workflow.

### Add command-level help without workflow guidance

Traditional command reference explains syntax but still requires an agent to
infer when documents should be discovered, created, checked, or transitioned.
The top-level workflow is necessary because this CLI exists specifically to
guide agent development work.

### Print full help after every usage error

This exposes all available syntax but hides the actionable error among
unrelated content and consumes unnecessary agent context. A specific error and
targeted help command provide a shorter recovery path.

### Add machine-readable JSON help

JSON would help a program generate commands, but the current consumer is an
agent reading terminal output. It would introduce another public output format
without improving the primary workflow. Machine-readable help can be proposed
separately if an orchestrator needs it.

### Replace explicit dispatch with a CLI framework

A framework could generate conventional reference help, but migrating parsing
is not required to deliver the agent workflow. Keeping explicit dispatch makes
the behavior and exit-status mapping visible in the small current command set.

## Consequences

`spec-dev-tool --help` and `spec-dev-tool -h` print workflow-first top-level
help. Both help flags also work for `create`, all five lifecycle list commands,
`check`, and `transition`. Each command page presents purpose, usage, arguments
or constraints, output, and next-step guidance in a stable order. The top-level
page lists every class, lifecycle, and exit status; lifecycle list help pins the
selected lifecycle and the `30`-day default; and transition help documents
exactly the five supported lifecycle edges.
The workflow requires user answers before either transition from `exploring`
and prohibits implementation while a document remains in that lifecycle.

Help succeeds outside Git worktrees without filesystem access. Known-command
usage errors print one specific error and targeted command-help suggestion;
unknown commands point to top-level help. Both exit with status `2` and omit
the complete help page. Validation and filesystem failures retain status `1`
without syntax guidance. End-to-end tests pin all help forms, section order,
key values, output channels, exit statuses, targeted recovery text, and the
absence of filesystem changes.

The help strings are maintained manually, so behavior changes require matching
help and test updates. Supporting both help flags increases explicit dispatch
patterns, and the workflow guidance is intentionally opinionated. The one-line
`AGENTS.md` bootstrap still depends on `spec-dev-tool` being installed and
available on `PATH`. English prose favors agent comprehension over minimal
terminal output size.
