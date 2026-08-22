# Repository-Scoped Find Simplifications Workflow

## Problem

`spec-dev-tool` could create and manage a known simplification decision, but it did not tell an agent how to discover worthwhile simplification candidates in the repository using the tool. A broad request such as "find simplifications" could therefore stop at obvious unused symbols, produce guesses without call-site evidence, or confuse a behavior-changing product decision with a behavior-preserving simplification.

The [`dsh-find-simplifications` skill](https://github.com/deepseek-ai/deepseek-harness/blob/master/.agents/skills/dsh-find-simplifications/SKILL.md) in DeepSeek Harness provides a strong discovery pattern: read repository decisions first, survey broadly, distinguish production from non-production consumers, prove or reject every candidate, and record only durable proposals. Its concrete instructions cannot be copied directly because they assume DeepSeek Harness paths, packages, JavaScript tooling, protected adapters, note conventions, and lifecycle rules. The equivalent mechanism in `spec-dev-tool` must operate on the current target Git worktree and adapt to that repository's instructions, architecture, language, build system, and agent documents. It must not scan the `spec-dev-tool` source repository unless that repository is itself the target worktree where the command is invoked.

## Decision

The CLI provides an agent-facing `find-simplifications` topic under the `guide` command namespace. The guide leads an agent through a semantic audit of the current Git worktree and turns strong, behavior-preserving candidates into repository-owned exploring documents under `docs/agent-guide/exploring/simplification/`.

The OCaml program does not attempt to identify simplifications itself. Cross-language static analysis cannot determine whether an API is intentionally public, whether a defensive boundary is load-bearing, or whether two representations encode distinct product behavior. Instead, the command emits a deterministic operational guide that the calling agent follows with its own repository-reading, search, build, and reasoning capabilities. This keeps `spec-dev-tool` responsible for the decision-document protocol while the agent remains responsible for semantic evidence.

The command shapes are:

```text
spec-dev-tool guide find-simplifications
spec-dev-tool guide find-simplifications --help
```

The `guide` namespace distinguishes agent workflows from commands that directly inspect or mutate repository state and leaves room for additional workflow topics. `guide find-simplifications` resolves the current Git worktree with the existing project-root mechanism, treats that worktree as the target repository, and writes no files. Its output explains the audit stages, evidence bar, candidate dispositions, document-writing protocol, and completion report.

The command has no `--scope` option. Audit scope comes from the user's natural-language request and may name paths, subsystems, symbols, behaviors, Git changes, priorities, or exclusions. The guide requires the agent to restate its interpreted scope before surveying and in the completion report. If the request gives no narrower scope, the current target worktree is the scope.

## Repository boundary and context

The workflow begins at the Git project root resolved for the invocation. It instructs the agent to read, in order:

1. The applicable `AGENTS.md` files and other repository-owned agent instructions.
2. `docs/agent_doc_format.md` when present, or the document rules included in the emitted guide when the target repository does not vendor that file.
3. Relevant exploring, proposed, implemented, and rejected documents discovered through the lifecycle commands.
4. Architecture, testing, dependency, compatibility, and development documentation named by the repository.
5. The production entry points and build or package metadata needed to classify consumers.

Target-repository instructions are authoritative for protected seams, supported platforms, public compatibility, generated code, dependency policy, and required validation. The workflow contains no built-in assumptions about package names, source directories, programming languages, frameworks, or whether tests define the intended behavior.

Implemented documents are evidence of intentional current design, not an unconditional veto. A candidate that conflicts with one must identify the new evidence and explain why the recorded trade-off should be reconsidered. Rejected documents prevent repeatedly proposing an already-rejected path unless the audit finds materially new evidence. Existing exploring or proposed documents own overlapping work; the agent refines the existing document instead of creating a duplicate.

## Audit method

The emitted guide uses four stages.

### Establish the corpus

The agent identifies repository-specific production, non-production, generated, vendored, and ambiguous corpora before judging usage. Tests, examples, scripts, benchmarks, fixtures, documentation, and public interfaces are not assigned a universal category; the agent reads their role in the target repository. Generated and vendored code is normally excluded as an edit target, while its generator or integration layer may remain in scope.

### Survey broadly

The agent partitions the requested scope by real subsystem or ownership boundary and surveys the complete scope before selecting final candidates. It starts with surfaces likely to produce meaningful net deletion, including:

- public or internal APIs, configuration, events, hooks, registries, and extension points with no demonstrated production consumer;
- duplicated sources of truth, mirrored state, parallel lifecycle machinery, and wrappers that preserve no independent policy;
- speculative generality, defensive behavior without a matching trust boundary, and abstractions with only one non-test implementation;
- dedicated packages, helpers, scripts, fixtures, snapshots, or tests whose only purpose is to support unused behavior;
- hand-rolled infrastructure that can be replaced by an already-allowed standard-library facility or well-maintained dependency with less total code and no loss of required semantics;
- features that were added and later removed but left obsolete code, configuration, documentation, tests, or agent-document ownership behind.

Repository search tools and language-specific analyzers are discovery aids, not proof. The agent searches exact identifiers, wire values, configuration keys, constructors, indirect registrations, loaders, reflection sites, generated references, and external/public contract documentation, then reads the relevant call sites.

### Prove or reject each candidate

For each candidate, the agent records enough working evidence to answer:

- What concrete surface would be removed, folded, demoted, or replaced?
- Which production, non-production, ambiguous, generated, or external consumers exist?
- Which current agent documents or repository policies justify the surface?
- What observable behavior and public contract remain unchanged?
- What implementation, tests, documentation, configuration, and generated artifacts would disappear or become simpler?
- Does the change produce net deletion or one clearer source of truth, rather than relocating the same complexity?
- Which repository checks could demonstrate the preserved behavior?

The agent rejects a simplification candidate when a production or supported external consumer requires the behavior, the change is primarily a feature or architecture decision, repository evidence protects the design and no stronger evidence supersedes it, or the change causes broad churn without reducing concepts or obligations. Because the `simplification` class is defined as removing accidental complexity without changing observable behavior, a reasonable but different behavior is not accepted merely because it is easier to explain. Such an idea must be handled under its actual class in a separate user-authorized decision.

### Select a disposition

Every investigated candidate receives one of these dispositions:

- `document`: strong evidence supports a durable simplification decision;
- `merge`: an existing exploring or proposed document already owns the decision;
- `local`: the cleanup is useful but too small or mechanical to justify a durable decision document;
- `reject`: evidence does not support a behavior-preserving simplification;
- `reclassify`: the idea is valuable but its primary decision belongs to another class.

Only `document` creates a new agent document. `merge` updates the owning active document without creating a parallel proposal. `local`, `reject`, and `reclassify` are reported to the user but do not silently modify code or create mislabeled documents. The discovery workflow never implements a candidate.

## Candidate document protocol

For each `document` disposition, the agent runs:

```text
spec-dev-tool create simplification <topic-name>
```

It then replaces the generic template with an evidence-backed exploring document. Each document owns one decision and includes the standard required sections plus design-specific evidence sections when useful. The content identifies exact current surfaces and consumers, distinguishes production evidence from tests and documentation, defines the behavior-preserving end state, includes all related code, test, documentation, configuration, and generated-artifact cleanup, names verification commands, and presents the strongest reason to retain the current design.

`Questions` remains the final level-two section. It contains only decisions or unknowns that require the user, including whether to give up an uncertain contract or whether an ambiguous consumer is supported. The agent runs `spec-dev-tool check <created-path>` for every created document, asks the user to answer every question across the created or updated exploring documents, and stops. It does not transition or implement any candidate as part of the guide workflow.

Small mechanical cleanups are not automatically written as inline TODO comments because comment conventions and urgency tags belong to the target repository. The completion report may recommend a local edit or repository-approved TODO, but creating either requires the surrounding user request to authorize code changes.

## Command output and completion report

`guide find-simplifications` output is stable plain text organized with the same agent-oriented sections used by other command help: `PURPOSE`, `WHEN TO USE`, `WORKFLOW`, `EVIDENCE`, `OUTPUT`, and `NEXT STEP`. Normal output goes to stdout and exits with status `0`. Failure to resolve the Git worktree writes the existing project-root error to stderr and exits with status `1`. Extra arguments, unknown guide topics, or unsupported options are usage errors and exit with status `2`. Guide-specific usage errors direct the agent to `spec-dev-tool guide --help`.

The guide requires the agent's final audit report to state:

- the target repository and user-requested scope;
- the areas surveyed and meaningful exclusions;
- each candidate disposition with a concise evidence summary;
- paths of created or updated exploring documents;
- the checks run and their results;
- every question that the user must answer before any transition or implementation.

An audit that finds no strong candidate is successful. It reports representative rejected candidates and the evidence that prevented weak proposals instead of creating an empty or speculative document. Rejected, local, and reclassified candidates remain in the conversation-level completion report; the workflow creates no persistent audit artifact for them. Only candidates with enough durable value to justify a decision create or update exploring documents.

## Relationship to the existing workflow

The guide is a discovery entry point, not a second document lifecycle. It reuses Git-root resolution, lifecycle discovery, `create simplification`, `check`, and the exploring user checkpoint. The top-level `AGENT WORKFLOW` includes `guide find-simplifications` before `create` as an optional path when no concrete decision is known. The existing `create` command remains the direct path when the user already knows the simplification to document.

The `guide` command itself does not install repository files, invoke an LLM, spawn subagents, run arbitrary repository commands, edit agent documents, or implement code. The agent following the guide may create or refine exploring documents when candidate evidence warrants them. Parallel agent work may be used when the calling environment supports it and the user requests breadth, but concurrency is an execution choice rather than part of the CLI contract.

## Verified behavior

- Top-level help exposes `guide find-simplifications`, and the command runs from the worktree root or a nested directory.
- The resolved invocation worktree is printed as the audit target; the command never substitutes the `spec-dev-tool` source repository.
- The guide requires repository instructions and existing agent documents to be read before candidates are judged.
- Broad discovery is separate from evidence-based selection, with production, non-production, ambiguous, generated, vendored, and external consumers classified from target-repository evidence.
- Behavior-changing ideas are rejected as simplifications and assigned the `reclassify` disposition when they remain valuable.
- Durable candidates use one valid exploring simplification document, while overlapping active documents use the `merge` disposition.
- The workflow performs no implementation or lifecycle transition and ends by presenting all exploring-document questions to the user.
- The command writes no repository files. End-to-end tests compare the worktree before and after successful and failed invocations.
- Structured scope options are rejected. The guide requires the agent to restate the natural-language scope and exclusions.
- A zero-candidate audit succeeds by reporting representative rejected candidates instead of creating a speculative document.
- Rejected, local, and reclassified candidates remain in the conversation report rather than a persistent audit artifact.
- End-to-end tests cover help, nested Git-root resolution, repository-root failure, invalid arguments and options, stdout and stderr behavior, exit statuses, stable output, and the no-write guarantee.

## Alternatives considered

### Use a direct top-level command

The workflow could use `spec-dev-tool find-simplifications`. That form is shorter and matches the user's goal, but it can imply that the OCaml binary performs semantic analysis and would add each future agent workflow as another top-level command. The `guide` namespace makes the read-only instructional behavior explicit and provides one location for future workflow topics.

### Install a repository-local agent skill

`spec-dev-tool` could write `.agents/skills/find-simplifications/SKILL.md` into every target repository. This would closely resemble the DeepSeek Harness mechanism, but it would couple the tool to one agent platform, introduce generated instructions that can drift from the installed CLI version, and mutate the target repository before any simplification decision exists. A command-provided workflow is available wherever the binary is installed and keeps one maintained source of guidance.

### Perform static analysis in OCaml

The CLI could scan files, count references, or integrate language analyzers and directly rank candidates. This would make the result appear objective while missing dynamic consumers, public contracts, repository decisions, and language-specific semantics. Supporting heterogeneous repositories would also turn a document-management tool into a multi-language analysis platform. External analyzers remain useful evidence selected by the agent for the target repository.

### Add only a specialized document template

`create simplification` could emit more candidate-evidence prompts than other classes. This helps document a candidate that is already known but does not guide broad discovery, corpus classification, rejection, or deduplication. It would also make the general exploring template depend on one discovery use case.

### Store one audit report document

The workflow could create a single document containing every candidate and rejection. That conflicts with the one-primary-decision rule, gives unrelated candidates one lifecycle, and turns transient survey evidence into permanent decision history. Durable candidates instead receive independent documents, while the audit summary stays in the agent's completion report.

### Copy the DeepSeek Harness skill verbatim

The source skill could be distributed unchanged. Its protected adapters, package layout, npm dependency policy, JavaScript analyzers, Agent Note paths, inline tags, and PR checks are repository-specific. Copying them would give incorrect instructions in target repositories and would not use the `spec-dev-tool` lifecycle or class definitions.

## Consequences

The CLI gains its first command namespace, initially with one topic. The binary remains responsible only for resolving the target worktree and emitting deterministic guidance; audit quality and breadth still depend on the calling agent's repository reading and reasoning. A generic workflow may omit domain-specific simplification smells that a repository-local skill would know, and reading existing decisions or proving external consumers can make an audit expensive.

Rejected, local, and reclassified evidence remains in the conversation unless it later justifies a durable decision document. Treating observable behavior as a strict class boundary intentionally excludes reductions that require product trade-offs; those decisions use their actual class and require separate user authorization.
