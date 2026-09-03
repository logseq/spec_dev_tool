let top_help =
  {|spec-dev-tool manages agent decision documents in docs/agent-guide/.

AGENT WORKFLOW
  Discover decisions by lifecycle:
    spec-dev-tool list-exploring
    spec-dev-tool list-proposed

  Discover repository simplification candidates before a decision is known:
    spec-dev-tool guide find-simplifications
    spec-dev-tool guide find-test-simplifications

  Start a decision before implementation:
    spec-dev-tool create <class> <doc-name>

  Validate document edits:
    spec-dev-tool check <doc-path>

  Wait for required user input:
    Ask the user to answer every question in the document.
    While creating or editing an exploring document, do not modify any other repository file.

  Record a decision outcome:
    spec-dev-tool transition <doc-path> proposed
    spec-dev-tool transition <doc-path> implemented
    spec-dev-tool transition <doc-path> rejected --reason "<sentence>"

  Retire stable historical context:
    spec-dev-tool transition <doc-path> archived

  Before completing repository work:
    spec-dev-tool check --all

COMMANDS
  guide             Print an agent workflow guide.
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
|}

let guide_help =
  {|PURPOSE
  Print operational guides for repository-aware agent workflows.

WHEN TO USE
  Use when the desired decision is not yet concrete and the agent needs a
  repeatable discovery workflow.

USAGE
  spec-dev-tool guide find-simplifications
  spec-dev-tool guide find-test-simplifications

TOPICS
  find-simplifications  Audit the current Git worktree for evidence-backed,
                        behavior-preserving simplification candidates.
  find-test-simplifications
                        Audit tests for evidence-backed simplifications while
                        preserving effective behavioral guarantees.

OUTPUT
  Prints the selected guide. Both topics prepare shared repository rules from
  .spec-dev-tool/guides/find-simplifications.md. It creates only the missing
  headings-only rules template and its parent directories, validates the fixed
  schema, and inlines the complete rules.

NEXT STEP
  Run the topic from the repository to audit, then follow its WORKFLOW.
|}

let find_test_simplifications_help =
  {|PURPOSE
  Print the repository-aware test simplification audit workflow.

WHEN TO USE
  Use before auditing tests and test-only support machinery for redundant or
  implementation-pinning coverage.

USAGE
  spec-dev-tool guide find-test-simplifications

BEHAVIOR
  Resolves the current Git worktree and uses the shared root-level file:
    .spec-dev-tool/guides/find-simplifications.md

  If the file is missing, the command creates its parent directories and a
  headings-only template without overwriting a concurrent file. Every normal
  invocation validates the fixed heading schema and inlines the complete file
  after the test-specific workflow. Existing valid files are never rewritten.

  This help form is read-only: it does not resolve Git, inspect files, or
  create the template.

NEXT STEP
  Run the command from the repository to audit, then follow its WORKFLOW and
  REPOSITORY CUSTOMIZATION sections.
|}

let find_simplifications_help =
  {|PURPOSE
  Print the repository-aware simplification audit workflow.

WHEN TO USE
  Use before a simplification audit to load the generic evidence method and
  the target repository's operational rules.

USAGE
  spec-dev-tool guide find-simplifications

BEHAVIOR
  Resolves the current Git worktree and uses the root-level file:
    .spec-dev-tool/guides/find-simplifications.md

  If the file is missing, the command creates its parent directories and a
  headings-only template without overwriting a concurrent file. Every normal
  invocation validates the fixed heading schema and inlines the complete file
  after the generic workflow. Existing valid files are never rewritten.

  This help form does not resolve Git, inspect files, or create the template.

NEXT STEP
  Run the command from the repository to audit, then follow its WORKFLOW and
  REPOSITORY CUSTOMIZATION sections.
|}

let overlay_newline (overlay : Spec_dev_tool.Simplification_guide_overlay.t) =
  if
    String.length overlay.content > 0
    && overlay.content.[String.length overlay.content - 1] = '\n'
  then ""
  else "\n"

let find_simplifications_guide root
    (overlay : Spec_dev_tool.Simplification_guide_overlay.t) =
  Printf.sprintf
    {|PURPOSE
  Guide an agent through a semantic audit for behavior-preserving
  simplifications in this target Git worktree:
    %s

  The command prepares and prints this guide. It does not scan repository code,
  invoke an LLM, spawn subagents, run repository checks, transition agent
  documents, or implement candidates. Its only repository write is exclusive
  creation of a missing simplification-rules template and its parent
  directories. The agent following the guide performs the audit and may edit
  exploring documents only when the surrounding user request authorizes that
  work.

WHEN TO USE
  Use when the user asks to find simplifications but has not already named a
  concrete decision. A simplification removes accidental complexity while
  preserving observable behavior and every supported public contract. A
  behavior-changing product or architecture decision must be reclassified and
  handled separately with user authorization.

  Interpret scope from the user's natural-language request; there is no
  structured scope option. Restate the user-requested scope, priorities, paths,
  subsystems, symbols, behaviors, Git changes, exclusions, and ambiguities
  before surveying. If the user supplied no narrower scope, audit the complete
  target worktree shown above.

WORKFLOW
  1. Read target-repository context in this order.
     - Read every applicable AGENTS.md and other repository-owned agent
       instruction before judging a candidate.
     - Apply the inlined root-level repository customization in this output.
       It supplements the generic evidence method and may make it stricter, but
       it cannot change spec-dev-tool lifecycle or class invariants, authorize
       implementation during discovery, or turn observable behavior changes
       into simplifications. Continue to honor nested AGENTS.md files while
       entering their directories.
     - Read docs/agent_doc_format.md when present. Otherwise use the document
       rules in this guide: one primary decision per document; use the
       simplification class only for behavior-preserving accidental-complexity
       removal; use the required Problem, Proposal, Alternatives considered,
       Acceptance criteria, Risks, and Questions sections; keep Questions as
       the final level-two section of an exploring document; and never
       implement an exploring decision.
     - Discover and read relevant lifecycle documents with list-exploring,
       list-proposed, list-implemented, list-rejected, and list-archived.
       Existing exploring or proposed documents own overlapping work: refine
       them instead of creating duplicates. Implemented documents are evidence
       of intentional current design; reconsider one only with stronger new
       evidence. Do not repeat a rejected path without materially new evidence.
     - Read repository architecture, testing, dependency, compatibility, and
       development documentation, including protected seams, generated-code
       policy, supported platforms, and public compatibility requirements.
     - Identify production entry points and build or package metadata needed to
       classify real consumers.

  2. Establish the corpus before judging usage.
     Classify relevant code and consumers as production, non-production,
     ambiguous, generated, vendored, or external according to repository
     evidence. Do not universally classify tests, examples, scripts,
     benchmarks, fixtures, documentation, or public interfaces. Generated and
     vendored code are normally excluded as edit targets, but their generator
     or integration layer can remain in scope. Record meaningful exclusions.

  3. Survey the complete scope before selecting final candidates.
     Partition the scope by real subsystem or ownership boundary. Look broadly
     for meaningful net deletion or one clearer source of truth, including:
     - APIs, configuration, events, hooks, registries, or extension points with
       no demonstrated production or supported external consumer;
     - mirrored state, duplicate sources of truth, parallel lifecycle
       machinery, and wrappers that preserve no independent policy;
     - speculative generality, defensive behavior without a matching trust
       boundary, and abstractions with only one non-test implementation;
     - packages, helpers, scripts, fixtures, snapshots, tests, configuration,
       documentation, or generated artifacts that exist only for unused
       behavior;
     - hand-rolled infrastructure replaceable by an already-allowed standard
       facility or maintained dependency with less total code and identical
       required semantics; and
     - obsolete residue from features that were later removed.
     Search tools and language analyzers are discovery aids, not proof. Search
     identifiers, wire values, configuration keys, constructors, indirect
     registrations, loaders, reflection, generated references, and public
     contract documentation, then read the relevant call sites.

  4. Prove or reject every candidate.
     Record the concrete surface to remove, fold, demote, or replace; all
     production, non-production, ambiguous, generated, and external consumers;
     relevant agent documents and repository policies; the observable behavior
     and public contract that remain unchanged; all code, tests, documentation,
     configuration, and generated artifacts that disappear or simplify; why
     the result is net deletion or one source of truth rather than relocated
     complexity; and the repository checks that can prove preservation.

     Reject a candidate when a production or supported external consumer needs
     it, when the change is mainly a feature or architecture decision, when
     repository evidence protects it without stronger contrary evidence, or
     when broad churn does not reduce concepts or obligations. A reasonable but
     different behavior is not a simplification.

  5. Select one disposition for every investigated candidate.
     - document: durable evidence supports one simplification decision.
     - merge: an active exploring or proposed document already owns it.
     - local: useful mechanical cleanup is too small for a durable decision.
     - reject: evidence does not support behavior-preserving simplification.
     - reclassify: the valuable idea primarily belongs to another class.

     Only document creates a new agent document. Merge updates only the owning
     active document. Report local, reject, and reclassify results without
     silently editing code, creating TODO comments, or persisting an audit
     artifact. The discovery workflow never implements a candidate.

  6. Write and validate durable candidate documents.
     For each document disposition, run:
       spec-dev-tool create simplification <topic-name>
     Replace the generic template with an evidence-backed exploring document
     that owns one decision. Include exact surfaces and consumers, the
     behavior-preserving end state, related code/test/documentation/
     configuration/generated-artifact cleanup, verification commands, and the
     strongest reason to retain the current design. Keep only user decisions or
     genuine unknowns in Questions, which must remain the final level-two
     section. For each new document run:
       spec-dev-tool check <created-path>
     Check updated active documents by their canonical paths as well.

EVIDENCE
  Target-repository instructions are authoritative. Call-site reading and
  repository-owned contract evidence outrank unused-symbol reports, reference
  counts, guesses, and generic language conventions. Distinguish production
  evidence from tests and documentation. For a public or dynamically loaded
  surface, explicitly investigate external use, reflection, registration,
  generated references, and compatibility promises before calling it unused.

  A strong candidate preserves observable behavior, reduces total concepts or
  obligations, includes its dependent cleanup, and names checks capable of
  demonstrating the preserved behavior. Unknown support status is a question,
  not permission to discard a contract.

OUTPUT
  Finish with one audit report containing:
  - the target repository and restated user-requested scope;
  - areas surveyed and meaningful exclusions;
  - every candidate disposition with a concise evidence summary;
  - paths of created or updated exploring documents;
  - checks run and their results; and
  - all questions the user must answer before transition or implementation.

  An audit with zero durable candidates succeeds. Include representative rejected candidates
  and the evidence that prevented weak proposals; do not create an empty or
  speculative document. Rejected, local, and reclassified candidates remain
  only in the conversation report.

REPOSITORY CUSTOMIZATION
  Source: %s
  Template created: %s
  The content below supplements the generic workflow. If it conflicts with an
  applicable AGENTS.md constraint, implemented decision document, lifecycle or
  class invariant, or another mandatory instruction, stop and report the exact
  conflict instead of weakening either rule.

BEGIN REPOSITORY-SPECIFIC SIMPLIFICATION RULES
%s%sEND REPOSITORY-SPECIFIC SIMPLIFICATION RULES

NEXT STEP
  Present all Questions from every created or updated exploring document to the
  user, then stop. Do not implement any candidate. Do not transition any
  document as part of this workflow. Wait for the user to answer every question
  before a later proposal, rejection, or implementation workflow begins.
|}
    root Spec_dev_tool.Simplification_guide_overlay.relative_path
    (if overlay.created then "yes" else "no")
    overlay.content (overlay_newline overlay)

let find_test_simplifications_guide root
    (overlay : Spec_dev_tool.Simplification_guide_overlay.t) =
  Printf.sprintf
    {|PURPOSE
  Guide an agent through an evidence-based audit of tests and test-only
  support machinery in this target Git worktree:
    %s

  The command prepares and prints this guide. It does not scan repository code,
  invoke an LLM, delete tests, modify production code, run repository checks,
  transition agent documents, or implement candidates. Its only repository
  write is exclusive creation of a missing shared simplification-rules
  template and its parent directories. The agent following the guide performs
  the audit and may edit exploring documents only when the surrounding user
  request authorizes that work.

WHEN TO USE
  Use when the user asks to find test simplifications but has not already named
  a concrete decision. The audit seeks tests that no longer protect useful
  behavior and test-only support surfaces that become unused, while preserving
  every effective behavioral guarantee and supported public contract.

  Interpret scope from the user's natural-language request; there is no
  structured scope option. Restate requested paths, subsystems, changes,
  priorities, and exclusions before surveying. If the user supplied no
  narrower scope, audit the complete target worktree shown above.

WORKFLOW
  1. Establish the test contract by reading target-repository context.
     - Read every applicable AGENTS.md and other repository-owned agent
       instruction before judging a test.
     - Apply the inlined repository customization in this output. It may make
       the evidence bar stricter, but it cannot change lifecycle or class
       invariants, authorize implementation during discovery, or turn reduced
       validation into behavior preservation.
     - Read docs/agent_doc_format.md when present. Otherwise preserve one
       primary decision per document, use the required exploring sections,
       keep Questions final, and never implement an exploring decision.
     - Discover and read relevant decisions with list-exploring,
       list-proposed, list-implemented, list-rejected, and list-archived.
       Active documents own overlapping work; implemented and rejected
       documents are evidence of intent.
     - Read testing policy, architecture, compatibility and security promises,
       build metadata, supported platforms, production entry points, public
       interfaces, known regressions, trust boundaries, generated or vendored
       policy, test helpers, and required validation commands.
     - Classify unit, integration, end-to-end, property, snapshot, golden,
       compile-time, static-policy, and other tests by their actual repository
       role. No test style has universal value or universal permission for
       removal.

  2. Survey the complete requested scope before selecting final candidates.
     Inspect test cases together with their fixtures, snapshots, helpers,
     mocks, generated artifacts, and harness code. Candidate patterns include,
     but are not limited to:
     - one-time implementation-scaffolding tests that no longer protect a
       distinct supported behavior or regression;
     - tests that read source files or generated code and compare text,
       fragments, regular expressions, declaration order, symbol names, or
       call shape only to pin an implementation detail;
     - repeated cases that use the same path without adding a boundary, state
       transition, failure mode, platform, or integration distinction;
     - parameterized inputs that do not represent distinct equivalence classes
       or failure boundaries;
     - obsolete or unreachable behavior and test-only support machinery used
       only by those tests;
     - guarantees owned more directly by type checking, schema validation,
       compiler checks, or a stronger test at the appropriate boundary;
     - tests of an external dependency's implementation that exercise no
       repository-owned adaptation or policy; and
     - test-only abstractions whose cost exceeds the distinct coverage they
       enable.

     These are discovery prompts, not deletion rules. A test is not removable
     merely because it is old, narrow, textual, repetitive, or associated with
     a defect that has been fixed.

  3. Prove or reject every candidate.
     Record the exact test or supporting surface proposed for removal; the
     supported behavior, regression, policy, or implementation detail it
     protects; every retained test or static guarantee with overlapping
     coverage and the execution path by which it applies; and whether the
     candidate is unique coverage for a boundary, failure mode, platform,
     security property, compatibility promise, externally visible text,
     serialized form, or repository policy.

     Explain why removal preserves product behavior rather than hiding a
     failure or merely reducing validation cost. Record the complete net
     deletion and verification commands. Include fixtures, snapshots, helpers,
     mocks, generated artifacts, and harness code only after evidence proves
     that production code, other retained tests, documentation tooling, and
     external consumers do not use them and that no retained consumer remains.

     Source-text assertions require special scrutiny. Private implementation
     shape without behavioral effect is a strong candidate. A supported CLI
     response, protocol payload, serialization format, generated artifact,
     diagnostic, documentation example, security boundary, compatibility
     promise, regression, or repository policy remains protected unless
     independent evidence proves it obsolete or redundantly covered.

     Reject a candidate when equivalent retained coverage is not demonstrated
     and the asserted behavior is not proven unsupported. Runtime, flakiness,
     or implementation difficulty does not justify deleting a test that owns a
     real contract; those concerns require a separate fix or testing decision.

  4. Select one disposition for every investigated candidate.
     - document: evidence supports one durable test simplification decision.
     - merge: an active exploring or proposed document already owns it.
     - local: deletion is small, mechanical, and needs no durable decision.
     - reject: the test protects unique or insufficiently understood value.
     - reclassify: the idea changes behavior, architecture, coverage strategy,
       validation method, or accepted risk instead of removing redundancy.

     Only document creates an agent document. Report merge, local, reject, and
     reclassify dispositions without silently editing the repository. A zero-
     candidate audit succeeds when the report includes representative rejected
     candidates and the evidence that retained them. Do not implement any
     candidate during discovery.

  5. Write and validate durable candidate documents.
     Create one exploring document per durable decision. Include exact
     removable tests and support surfaces, their apparent contract, consumer
     and overlap evidence, retained coverage, the behavior-preserving end
     state, validation commands, and the strongest reason to keep the current
     test.

     Select the class from the primary decision:
     - Run spec-dev-tool create simplification <topic-name> when redundant
       tests and exclusively used support code disappear while effective
       guarantees and validation obligations remain unchanged.
     - Run spec-dev-tool create testing <topic-name> when the decision changes
       coverage strategy, test level, validation method, or accepted risk.
     - Use another class for a primary product, architecture, or process
       decision. If that class is outside user-authorized scope, reclassify and
       report it instead of creating a document.

     Run spec-dev-tool check <created-path> for every created or updated
     document. Ask the user every question in each final Questions section and
     stop. Do not transition a document or implement a candidate as part of
     discovery.

EVIDENCE
  Repository instructions and supported contracts are authoritative. Call-path
  reading and executable repository evidence outrank names, age, line counts,
  superficial duplication, coverage percentages, and generic testing rules.
  Overlap requires the same behavior through a reliable retained path, not
  merely a second assertion near the same code.

  Supporting assets qualify for removal only after their complete consumer set
  is traced. Unknown support status is a question, not permission to discard a
  contract. Strong evidence proves either equivalent retained protection or
  that the asserted behavior is not supported.

OUTPUT
  Finish with one audit report containing:
  - the target repository and restated user-requested scope;
  - areas and test roles surveyed, plus meaningful exclusions;
  - every investigated candidate and its disposition with evidence;
  - exact net deletion for supported candidates;
  - paths of created or updated exploring documents;
  - checks run and their results; and
  - all questions the user must answer before transition or implementation.

  A well-supported zero-candidate audit is successful. Include representative rejected candidates
  and evidence; never create an empty or speculative document.

REPOSITORY CUSTOMIZATION
  Source: %s
  Template created: %s
  The complete shared content below supplements this test-specific workflow.
  Interpret applicable corpus, protected-surface, priority, evidence, and
  validation rules for tests without inventing test-specific headings. If a
  rule conflicts with AGENTS.md, an implemented decision, or a lifecycle or
  class invariant, stop and report the exact conflict.

BEGIN REPOSITORY-SPECIFIC SIMPLIFICATION RULES
%s%sEND REPOSITORY-SPECIFIC SIMPLIFICATION RULES

NEXT STEP
  Present all Questions from every created or updated exploring document to the
  user, then stop. Do not implement any candidate. Do not transition any
  document. Wait for all answers before later proposal, rejection, or
  implementation work.
|}
    root Spec_dev_tool.Simplification_guide_overlay.relative_path
    (if overlay.created then "yes" else "no")
    overlay.content (overlay_newline overlay)

let create_help =
  {|PURPOSE
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
  While creating or editing an exploring document, do not modify any other repository file.
|}

let list_help lifecycle =
  Printf.sprintf
    {|PURPOSE
  List recent %s agent documents, newest first.

WHEN TO USE
  Use to discover recent decisions in the %s lifecycle.

USAGE
  spec-dev-tool list-%s [<days>]

ARGUMENTS
  <days> defaults to 30 and must be a positive base-10 integer.

OUTPUT
  Prints one canonical project-relative document path per line.
  An empty result produces no output and is successful.

NEXT STEP
  Read relevant documents before changing the repository.
|}
    lifecycle lifecycle lifecycle

let check_help =
  {|PURPOSE
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
|}

let transition_help =
  {|PURPOSE
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
  While creating or editing an exploring document, do not modify any other repository file.
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
|}

type help_topic = Top_level | Command of string

let print_help help =
  print_string help;
  0

let usage_error topic message =
  Printf.eprintf "Error: %s\n" message;
  (match topic with
  | Top_level -> prerr_endline "Try: spec-dev-tool --help"
  | Command command -> Printf.eprintf "Try: spec-dev-tool %s --help\n" command);
  2

let with_project_root operation =
  match Spec_dev_tool.Agent_doc.resolve_project_root () with
  | Ok root -> operation root
  | Error message ->
      prerr_endline message;
      1

let report_check path = function
  | Ok () ->
      Printf.printf "Valid agent document: %s\n" path;
      false
  | Error errors ->
      Printf.eprintf "Invalid agent document: %s\n" path;
      List.iter (Printf.eprintf "- %s\n") errors;
      true

let check path =
  with_project_root (fun root ->
      if report_check path (Spec_dev_tool.Agent_doc.check root path) then 1
      else 0)

let check_all () =
  with_project_root (fun root ->
      match Spec_dev_tool.Agent_doc.check_all root with
      | Error message ->
          prerr_endline message;
          1
      | Ok documents ->
          let failed =
            List.fold_left
              (fun failed (path, result) -> report_check path result || failed)
              false documents
          in
          if failed then 1 else 0)

let create document_class topic =
  match Spec_dev_tool.Agent_doc.document_class_of_string document_class with
  | Error message -> usage_error (Command "create") message
  | Ok document_class ->
      if not (Spec_dev_tool.Agent_doc.is_topic_name topic) then
        usage_error (Command "create") "doc-name must be lowercase kebab-case"
      else
        with_project_root (fun root ->
            match Spec_dev_tool.Agent_doc.create root document_class topic with
            | Ok path ->
                Printf.printf "Created %s\n" path;
                0
            | Error message ->
                prerr_endline message;
                1)

let positive_decimal value =
  String.length value > 0
  && String.for_all (function '0' .. '9' -> true | _ -> false) value

let days_of_string value =
  if positive_decimal value then
    match int_of_string_opt value with
    | Some days when days > 0 -> Ok days
    | Some _ | None -> Error "days must be a positive base-10 integer"
  else Error "days must be a positive base-10 integer"

let list_documents lifecycle days =
  with_project_root (fun root ->
      match Spec_dev_tool.Agent_doc.list_documents root lifecycle days with
      | Ok paths ->
          List.iter print_endline paths;
          0
      | Error message ->
          prerr_endline message;
          1)

let list_with_days command lifecycle days =
  match days_of_string days with
  | Ok days -> list_documents lifecycle days
  | Error message -> usage_error (Command command) message

let target_lifecycle value =
  match Spec_dev_tool.Agent_doc.lifecycle_of_string value with
  | Ok Spec_dev_tool.Agent_doc.Proposed -> Ok Spec_dev_tool.Agent_doc.Proposed
  | Ok Spec_dev_tool.Agent_doc.Implemented ->
      Ok Spec_dev_tool.Agent_doc.Implemented
  | Ok Spec_dev_tool.Agent_doc.Rejected -> Ok Spec_dev_tool.Agent_doc.Rejected
  | Ok Spec_dev_tool.Agent_doc.Archived -> Ok Spec_dev_tool.Agent_doc.Archived
  | Ok Spec_dev_tool.Agent_doc.Exploring | Error _ ->
      Error (Printf.sprintf "invalid target lifecycle: %s" value)

let report_transition_failure path errors =
  Printf.eprintf "Cannot transition agent document: %s\n" path;
  List.iter (Printf.eprintf "- %s\n") errors;
  1

let transition path target reason =
  match target_lifecycle target with
  | Error message -> usage_error (Command "transition") message
  | Ok target -> (
      match Spec_dev_tool.Agent_doc.prepare_transition path target ~reason with
      | Error (Spec_dev_tool.Agent_doc.Usage_error message) ->
          usage_error (Command "transition") message
      | Error (Spec_dev_tool.Agent_doc.Operation_error errors) ->
          report_transition_failure path errors
      | Ok request ->
          with_project_root (fun root ->
              match Spec_dev_tool.Agent_doc.transition root request with
              | Ok destination ->
                  print_endline destination;
                  0
              | Error (Spec_dev_tool.Agent_doc.Usage_error message) ->
                  usage_error (Command "transition") message
              | Error (Spec_dev_tool.Agent_doc.Operation_error errors) ->
                  report_transition_failure path errors))

let begins_with_hyphen value = String.length value > 0 && value.[0] = '-'

let command_help = function
  | "guide" -> Some guide_help
  | "create" -> Some create_help
  | "list-exploring" -> Some (list_help "exploring")
  | "list-proposed" -> Some (list_help "proposed")
  | "list-implemented" -> Some (list_help "implemented")
  | "list-rejected" -> Some (list_help "rejected")
  | "list-archived" -> Some (list_help "archived")
  | "check" -> Some check_help
  | "transition" -> Some transition_help
  | _ -> None

let print_repository_guide render =
  with_project_root (fun root ->
      match Spec_dev_tool.Simplification_guide_overlay.prepare root with
      | Ok overlay ->
          print_help
            (render (Spec_dev_tool.Agent_doc.project_root_path root) overlay)
      | Error message ->
          prerr_endline message;
          1)

let run = function
  | [ _; "--help" ] | [ _; "-h" ] -> print_help top_help
  | [ _; command; ("--help" | "-h") ] -> (
      match command_help command with
      | Some help -> print_help help
      | None ->
          usage_error Top_level (Printf.sprintf "unknown command: %s" command))
  | [ _; "guide"; "find-simplifications"; ("--help" | "-h") ] ->
      print_help find_simplifications_help
  | [ _; "guide"; "find-test-simplifications"; ("--help" | "-h") ] ->
      print_help find_test_simplifications_help
  | [ _; "guide"; "find-simplifications" ] ->
      print_repository_guide find_simplifications_guide
  | [ _; "guide"; "find-test-simplifications" ] ->
      print_repository_guide find_test_simplifications_guide
  | [ _; "check"; "--all" ] -> check_all ()
  | [ _; "check"; path ] when not (begins_with_hyphen path) -> check path
  | [ _; "create"; document_class; topic ] -> create document_class topic
  | [ _; "list-exploring" ] ->
      list_documents Spec_dev_tool.Agent_doc.Exploring 30
  | [ _; "list-exploring"; days ] ->
      list_with_days "list-exploring" Spec_dev_tool.Agent_doc.Exploring days
  | [ _; "list-proposed" ] -> list_documents Spec_dev_tool.Agent_doc.Proposed 30
  | [ _; "list-proposed"; days ] ->
      list_with_days "list-proposed" Spec_dev_tool.Agent_doc.Proposed days
  | [ _; "list-implemented" ] ->
      list_documents Spec_dev_tool.Agent_doc.Implemented 30
  | [ _; "list-implemented"; days ] ->
      list_with_days "list-implemented" Spec_dev_tool.Agent_doc.Implemented days
  | [ _; "list-rejected" ] -> list_documents Spec_dev_tool.Agent_doc.Rejected 30
  | [ _; "list-rejected"; days ] ->
      list_with_days "list-rejected" Spec_dev_tool.Agent_doc.Rejected days
  | [ _; "list-archived" ] -> list_documents Spec_dev_tool.Agent_doc.Archived 30
  | [ _; "list-archived"; days ] ->
      list_with_days "list-archived" Spec_dev_tool.Agent_doc.Archived days
  | [ _; "transition"; path; target ] -> transition path target None
  | [ _; "transition"; path; target; "--reason"; reason ] ->
      transition path target (Some reason)
  | [ _ ] -> usage_error Top_level "missing command"
  | _ :: command :: _ -> (
      match command_help command with
      | Some _ ->
          usage_error (Command command)
            (Printf.sprintf "invalid arguments for %s" command)
      | None ->
          usage_error Top_level (Printf.sprintf "unknown command: %s" command))
  | [] -> usage_error Top_level "missing command"

let () = Array.to_list Sys.argv |> run |> exit
