# Add Repository-Specific Simplification Rules

## Problem

The implemented [`guide find-simplifications`](../../implemented/feature/2026-08-22-find-simplifications-workflow.md) workflow must work across repositories with different source layouts, public contracts, protected architecture, dependency policies, and validation commands. Its built-in guide can define a reliable evidence method, but it cannot safely decide which directories are production, which examples are supported interfaces, which seams are intentionally duplicated, or which generated and vendored surfaces should be excluded in every repository.

Relying only on natural-language instructions in the user request makes recurring audits inconsistent. Copying the complete built-in guide into each repository creates a second source of truth and makes upstream improvements difficult to adopt. A target repository needs a small bootstrap for agents, a stable place for operational audit rules, and durable decision documents for the rationale behind important constraints without mixing those three responsibilities.

## Decision

Use three repository-owned layers to customize `guide find-simplifications`:

1. Applicable `AGENTS.md` files provide the minimal `spec-dev-tool` bootstrap and mandatory agent constraints.
2. A root-level `.spec-dev-tool/guides/find-simplifications.md` overlay provides repository-specific operational audit rules.
3. Implemented process documents under `docs/agent-guide/implemented/process/` preserve the long-term rationale for important policies and protected surfaces.

The built-in guide remains the canonical generic workflow. The repository overlay supplements it instead of copying or replacing it. The overlay may make the evidence bar stricter, classify repository corpora, exclude generated or vendored edit targets, prioritize known complexity patterns, protect intentional architecture, and name validation commands. It cannot change `spec-dev-tool` lifecycle and class semantics, allow implementation during discovery, or classify observable behavior changes as simplifications.

Repositories do not need to create the overlay before first use. When the file is missing, `guide find-simplifications` creates a valid empty template at the fixed path. Every successful invocation validates the fixed schema and inlines the complete overlay after the generic guide. This bootstrap write is a deliberate exception to the currently implemented guide's no-write behavior; implementing this proposal must update the owning implemented workflow document to describe the new behavior rather than retain the obsolete guarantee.

This customization is part of the target repository. Nothing in the `spec-dev-tool` source repository is consulted unless it is the target Git worktree where the guide is invoked.

## `AGENTS.md` bootstrap

The target repository root uses this minimal bootstrap:

```markdown
- Use `spec-dev-tool` to manage agent decision documents. Run `spec-dev-tool --help` and follow its `AGENT WORKFLOW`.
- For simplification audits, run `spec-dev-tool guide find-simplifications` and follow the emitted generic workflow and inlined repository customization.
```

Repository-wide mandatory constraints may remain in the root `AGENTS.md`. Directory-specific constraints remain in nested `AGENTS.md` files so their existing scope semantics apply as the agent surveys files. The CLI does not copy, merge, or reinterpret `AGENTS.md`; the agent follows the applicable instructions through its normal instruction mechanism.

The bootstrap deliberately avoids duplicating the lifecycle, candidate evidence method, or complete audit workflow. Those details remain discoverable from the CLI and can evolve with the installed version.

## Repository guide overlay

The repository overlay has exactly this project-relative path:

```text
.spec-dev-tool/guides/find-simplifications.md
```

It is outside `docs/agent-guide/` because `spec-dev-tool check --all` treats every Markdown file under that tree as a lifecycle document. The overlay is operational guidance rather than a decision and therefore has no lifecycle or class.

The overlay uses ordinary English Markdown with a fixed heading schema. It contains exactly one level-one heading with the title shown below and all eight level-two headings in the shown order. No additional level-one or level-two headings are allowed. Content below each level-two heading is optional, so the generated headings-only template is both semantically empty and schema-valid. Lower-level headings and other Markdown content may be used within a section.

```markdown
# Repository-Specific Simplification Rules

## Production corpus

## Non-production and ambiguous corpus

## Excluded edit targets

## Protected surfaces

## Candidate priorities

## Dependency policy

## Required evidence

## Validation
```

Rules added beneath those headings name exact paths, identifiers, commands, and links when available. Empty sections remain present rather than being removed. The overlay does not restate generic advice such as using repository search before judging consumers.

## Durable rationale

An operational rule that embodies a long-lived engineering decision links to an implemented process document, for example:

```text
docs/agent-guide/implemented/process/YYYY-MM-DD-define-dependency-policy.md
docs/agent-guide/implemented/process/YYYY-MM-DD-protect-storage-backends.md
```

The overlay states the action the audit must take; the implemented document explains why the policy exists, which alternatives were considered, and what consequences the repository accepts. A relative Markdown link from the overlay keeps the two discoverable together.

Not every overlay rule needs a process document. Paths, build commands, generated directories, and other current operational facts can remain directly in the overlay. A process document is appropriate when removing the rationale would make a future agent likely to repeat a rejected architectural or policy decision.

Implemented documents remain the source of truth for their decisions. If an overlay rule conflicts with a current implemented document, the agent reports the conflict instead of silently choosing one or rewriting either file during the audit.

## Rule application

The workflow applies customization in these layers:

```text
spec-dev-tool lifecycle and class invariants
  + applicable AGENTS.md constraints
  + repository guide overlay
  + built-in generic audit guidance
  + user-requested natural-language scope
```

These layers have different responsibilities rather than unrestricted override semantics. The user's scope selects or narrows what to investigate. `AGENTS.md` and the overlay constrain how the investigation is performed. Built-in guidance supplies the evidence method where the repository has no specialization. CLI lifecycle and class invariants remain mandatory.

When instructions conflict, the agent stops and reports the exact conflict to the user. It does not weaken a mandatory repository constraint or a CLI invariant based on a lower-specificity heuristic.

## Command behavior

`spec-dev-tool guide find-simplifications` resolves the Git project root and prepares the fixed overlay path before emitting any workflow text:

- If the overlay is missing, the command creates `.spec-dev-tool/guides/` as needed and exclusively creates the headings-only template. It never overwrites a file created concurrently.
- If the overlay exists, it must be a readable regular file at the root-level fixed path. Symbolic links and other file kinds are rejected.
- The command validates the exact heading schema before producing stdout. Missing, duplicate, additional, or out-of-order level-one or level-two headings are validation errors. Empty section bodies are valid.
- A creation, read, file-kind, or validation failure emits no partial guide, writes specific diagnostics to stderr, and exits with status `1`.
- A successful invocation emits the generic workflow followed by a `REPOSITORY CUSTOMIZATION` section containing the canonical project-relative source path, whether the template was created during this invocation, and the complete overlay content between stable begin and end delimiters.
- Existing valid overlay content is never updated, normalized, or rewritten by the guide command.

The inlined overlay appears before the guide's final next-step instructions, so the agent applies repository rules before classifying corpora or selecting candidates. As the audit enters directories, the agent continues to honor nested `AGENTS.md` files. Only the Git-root overlay is discovered; nested guide overlays are not supported.

Help forms remain read-only and independent of Git and the filesystem. `spec-dev-tool guide find-simplifications --help` describes template generation, validation, and inlining without creating the overlay.

## Maintenance workflow

Operational changes to the overlay are normal repository documentation edits. The agent reviews them against applicable `AGENTS.md` and linked implemented process documents, checks referenced paths and commands, runs `spec-dev-tool guide find-simplifications` to validate the fixed schema, and runs `git diff --check`. The first version does not add a separate overlay-validation command or extend `spec-dev-tool check --all` beyond lifecycle documents.

When an operational change alters a durable policy, the owning process decision is explored and transitioned through the normal lifecycle first. After implementation, the overlay is synchronized to the resulting current rule. Obsolete overlay rules are removed rather than retained as compatibility guidance.

## Alternatives considered

### Put every rule in `AGENTS.md`

The repository could store all simplification rules in its root and nested `AGENTS.md` files. This works without a new convention and remains useful for short mandatory constraints, but a substantial audit policy would make general agent instructions noisy and harder to navigate. The fixed overlay keeps workflow-specific operational detail discoverable without duplicating the generic guide.

### Use only implemented process documents

The workflow could discover customization by scanning implemented process documents. Those documents preserve rationale well, but dated filenames do not provide a stable operational entry point, and many useful rules such as current paths and validation commands do not justify independent decisions. The overlay provides the current operational index and links to implemented documents when rationale is durable.

### Use structured configuration

A TOML or similar configuration file could define production paths, exclusions, protected surfaces, and commands. Structured fields are easier for the CLI to validate but cannot express consumer ambiguity and architectural rationale naturally. Adding glob semantics, path inheritance, identifiers, and command models would create a configuration language when a fixed Markdown heading schema provides enough validation.

### Generate a repository-local skill

The CLI could install `.agents/skills/find-simplifications/SKILL.md` containing both the generic workflow and repository rules. That would couple customization to one agent platform and create a fork of the built-in guide whose ownership and upgrade behavior are unclear. The overlay contains only repository-specific differences and remains usable by any agent that can follow the CLI guide.

### Support nested overlays

Each subtree could provide its own `.spec-dev-tool/guides/find-simplifications.md`. This would allow detailed locality but introduce discovery order, inheritance, conflict, and scope rules that overlap with nested `AGENTS.md`. A single root overlay plus applicable nested `AGENTS.md` files provides locality without a second hierarchical instruction system.

## Verified behavior

- The top-level bootstrap tells agents how to discover both the general `spec-dev-tool` workflow and the simplification guide without duplicating either workflow.
- The first successful guide invocation exclusively creates a schema-valid headings-only overlay when the fixed path is missing and never overwrites an existing or concurrently created file.
- A target repository can add detailed simplification rules at `.spec-dev-tool/guides/find-simplifications.md` without modifying or copying the built-in guide.
- The overlay can classify repository corpora, define exclusions and protected surfaces, set candidate priorities and evidence requirements, state dependency policy, and name exact validation commands.
- Every invocation validates the exact level-one and level-two heading schema before emitting output, while allowing empty section bodies and content below the fixed headings.
- Durable policy rationale is stored in valid implemented process documents and is reachable through links from the operational overlay.
- `guide find-simplifications` identifies the target worktree's overlay and never consults the installed tool's source repository for customization.
- A valid overlay is inlined completely between stable delimiters together with its canonical path and creation status.
- An invalid or unreadable overlay path produces a specific operation failure without partial guide output.
- Repository customization cannot change lifecycle rules, weaken the `simplification` class boundary, authorize implementation during discovery, or create a persistent artifact for weak candidates.
- The guide command never changes repository code or agent-document lifecycle state; its only write is initial creation of the missing overlay and its parent directories.
- Nested invocations use the one Git-root overlay, while directory-specific customization continues to come from applicable nested `AGENTS.md` files.
- End-to-end tests cover template creation, repeated invocation, concurrent-create protection, valid and invalid schemas, unreadable and non-regular paths, exact inlining, nested invocation, help isolation, output, exit statuses, and scoped write behavior.

## Consequences

- `AGENTS.md`, the overlay, implemented process documents, and the built-in guide form several instruction layers that can drift or conflict.
- A fixed heading schema improves predictability but makes harmless heading additions or reordering invalid until the CLI schema changes.
- A root-only overlay may become large in a monorepo, while nested rules must rely on nested `AGENTS.md` files.
- Inlining a large overlay makes every guide invocation longer and duplicates repository content in command output.
- Automatically creating the overlay makes a formerly read-only workflow command modify a clean worktree on first use.
- Directory creation can leave empty parent directories after a later file-creation failure unless the implementation provides explicit cleanup.
- Linked implemented documents can move through lifecycle transitions, requiring the overlay link to be synchronized.
- Repositories must maintain current path classifications and validation commands as their layout and tooling change.
