# Add a Find Test Simplifications Guide

## Problem

`guide find-simplifications` provides a repository-wide method for finding
behavior-preserving simplifications, but a general audit does not fully address
the evidence needed to decide when tests have stopped protecting useful
behavior. Treating every test as a consumer can retain implementation machinery
used only by tests, while treating tests as disposable can erase unique
behavioral, regression, boundary, compatibility, security, or policy coverage.

Test suites also contain superficially similar artifacts with different roles.
A source-text assertion can pin private implementation shape, while a golden
file can protect a public CLI or serialization contract. Agents need a focused,
repeatable workflow that distinguishes those cases and finds worthwhile net
deletions without making reduced line count the measure of test value.

## Decision

The `guide` namespace provides a test-specific simplification topic:

```text
spec-dev-tool guide find-test-simplifications
spec-dev-tool guide find-test-simplifications --help
```

The command emits a deterministic, agent-oriented workflow for auditing tests
in the current Git worktree. Natural-language user scope selects paths,
subsystems, changes, priorities, and exclusions; the command has no structured
scope option. The OCaml program prepares the guide and repository overlay but
does not scan code, judge candidates, delete tests, modify production code, or
transition agent documents.

Top-level help and `guide --help` expose the topic. Topic help is read-only and
independent of Git. Unsupported arguments are usage errors with exit status 2.
Git and overlay operational failures produce no partial stdout and exit with
status 1.

## Audit method

The emitted guide requires the agent to establish repository contracts before
judging tests. It directs the agent to read applicable `AGENTS.md` files,
`docs/agent_doc_format.md`, relevant lifecycle documents, testing and
architecture policy, compatibility and security promises, build metadata,
supported platforms, production entry points, known regressions, test helpers,
and required validation commands.

Unit, integration, end-to-end, property, snapshot, golden, compile-time,
static-policy, and other tests are classified by their actual repository role.
No test style is assigned universal value or universal permission for removal.

The agent surveys the complete requested scope before selecting candidates.
Discovery prompts include:

- one-time implementation-scaffolding tests without a distinct durable
  behavior or regression;
- source or generated-code text assertions that only pin private declaration,
  naming, ordering, or call shape;
- repeated cases without a distinct boundary, state transition, failure mode,
  platform, integration path, or input equivalence class;
- obsolete or unreachable behavior and its test-only support machinery;
- guarantees owned more directly by type checking, schema validation, compiler
  checks, or a stronger test at the appropriate boundary;
- tests of external dependency implementation that exercise no
  repository-owned adaptation or policy; and
- test-only abstractions whose maintenance cost exceeds the distinct coverage
  they enable.

These patterns are prompts rather than deletion rules. Age, narrow scope,
textual comparison, apparent repetition, or association with a fixed defect is
not sufficient evidence for removal.

For every candidate, the workflow records the exact removable surface; its
current behavior, regression, or policy contract; overlapping retained tests or
static guarantees and their execution paths; unique boundaries and failure
modes; complete net deletion; consumer evidence; and verification commands.
Fixtures, snapshots, helpers, mocks, generated artifacts, and harness code are
included only after production code, retained tests, documentation tooling, and
external consumers are shown not to use them.

Externally visible text, protocol payloads, serialized forms, generated
artifacts, diagnostics, documentation examples, regressions, security
boundaries, compatibility promises, and repository policies remain protected
unless independent evidence proves them obsolete or redundantly covered.
Runtime, flakiness, or implementation difficulty requires its own fix or
testing decision when the affected test owns a real contract.

## Candidate disposition and documents

Every investigated candidate receives one disposition:

- `document` for an evidence-backed durable decision;
- `merge` when an active document already owns the decision;
- `local` for a small mechanical deletion that needs no durable record;
- `reject` when the test protects unique or insufficiently understood value;
  or
- `reclassify` when the idea primarily changes behavior, architecture,
  coverage strategy, validation method, or accepted risk.

Only `document` creates an agent document. A zero-candidate audit succeeds when
representative rejected candidates and their evidence are reported. The
discovery workflow does not implement candidates or transition documents.

Each durable candidate receives one exploring document with exact removable
surfaces, its apparent contract, consumer and overlap evidence, retained
coverage, the behavior-preserving end state, validation commands, and the
strongest reason to retain the current test. The primary decision selects the
class:

- `simplification` removes redundant coverage and exclusively used support
  code while effective guarantees and validation obligations remain unchanged;
- `testing` changes coverage strategy, test level, validation method, or
  accepted risk; and
- another class owns a primary product, architecture, or process decision.

The agent runs `spec-dev-tool check <created-path>` for every created or updated
document, asks the user every question in each final `Questions` section, and
stops before transition or implementation.

## Repository customization

Both simplification topics use the existing root-level overlay:

```text
.spec-dev-tool/guides/find-simplifications.md
```

Normal invocation resolves the Git worktree root, exclusively creates the
headings-only template and parent directories when missing, validates the exact
heading schema, and inlines the complete file exactly once. Existing valid
files are never rewritten. The test-specific guide interprets applicable
corpus, protected-surface, priority, evidence, dependency, and validation rules
through its narrower method without adding another schema or rewriting the
shared overlay.

## Alternatives considered

### Extend only `find-simplifications`

Adding more test examples to the generic guide would avoid another topic but
would give test audits no focused entry point and would make a broad workflow
responsible for the distinct evidence problem of deleting validation.

### Automatically identify deletable tests

Scanning names, source text, coverage, or duplicate assertions cannot establish
behavioral equivalence across languages, indirect registration, dynamic
behavior, and external contracts. An agent interprets repository-appropriate
analysis against semantic evidence instead.

### Delete every implementation-coupled or duplicate-looking test

Exact text can be public behavior, apparently repeated cases can cover distinct
paths, and regression tests remain valuable after a fix. The guide treats these
shapes as prompts rather than automatic deletion categories.

### Report candidates without agent documents

Conversational reporting remains suitable for `local`, `reject`, and
`reclassify` outcomes. Durable coverage decisions use the existing document
lifecycle so their rationale and user checkpoint are preserved.

### Use a dedicated test-simplification overlay

A second file would duplicate schema, bootstrap, validation, and repository
policy. The existing simplification overlay already expresses the relevant
operational rules for both topics.

### Assign every candidate to one document class

Classifying by edited file type would obscure the primary decision. Preserving
effective guarantees is a simplification, while intentionally changing the
coverage model is a testing decision and other primary concerns retain their
own classes.

## Consequences

Agents have a discoverable test-focused workflow that requires contract and
consumer evidence before test deletion, protects unique coverage, and accounts
for removable test-only support code. It integrates with the existing document
lifecycle and repository customization without a compatibility layer or second
overlay schema.

The workflow is deliberately advisory: it does not automate semantic judgment
or implementation. Proving overlap can cost more than retaining a small test,
so `reject`, `local`, and zero-candidate outcomes remain valid. Sharing the
overlay also requires repository rules to state their intended audit scope when
context alone is ambiguous.
