let top_help =
  {|spec-dev-tool manages agent decision documents in docs/agent-guide/.

AGENT WORKFLOW
  Discover active decisions:
    spec-dev-tool list

  Start a decision before implementation:
    spec-dev-tool create <class> <doc-name>

  Validate document edits:
    spec-dev-tool check <doc-path>

  Record a decision outcome:
    spec-dev-tool transition <doc-path> implemented
    spec-dev-tool transition <doc-path> rejected --reason "<sentence>"

  Retire stable historical context:
    spec-dev-tool transition <doc-path> archived

  Before completing repository work:
    spec-dev-tool check --all

COMMANDS
  create      Create a proposed agent document.
  list        List recent agent documents.
  check       Validate one or all agent documents.
  transition  Move a document to its next lifecycle.

Run 'spec-dev-tool <command> --help' for command details.

VALUES
  class:
    simplification | bugfix | feature | testing | architecture | process

  lifecycle:
    proposed | implemented | rejected | archived

EXIT STATUS
  0  Command completed successfully.
  1  Document validation or filesystem operation failed.
  2  Command arguments are invalid.
|}

let create_help =
  {|PURPOSE
  Create a proposed agent document using today's date and the proposed
  document template.

WHEN TO USE
  Use before implementing a decision that should be recorded.

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
|}

let list_help =
  {|PURPOSE
  List recent agent documents, newest first.

WHEN TO USE
  Use before planning or implementing work to discover relevant decisions.

USAGE
  spec-dev-tool list [<lifecycle> [<days>]]

ARGUMENTS
  <lifecycle> defaults to proposed and is one of:
    proposed | implemented | rejected | archived

  <days> defaults to 30 and must be a positive base-10 integer.

OUTPUT
  Prints one canonical project-relative document path per line.
  An empty result produces no output and is successful.

NEXT STEP
  Read relevant documents before changing the repository.
|}

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
  Use after a proposal is implemented or rejected, or after implemented
  documentation becomes stable historical context.

USAGE
  spec-dev-tool transition <doc-path> implemented
  spec-dev-tool transition <doc-path> rejected --reason "<sentence>"
  spec-dev-tool transition <doc-path> archived

CONSTRAINTS
  Supported transitions:
    proposed    -> implemented
    proposed    -> rejected
    implemented -> archived

  <doc-path> must be a canonical project-relative path.
  Rewrite a proposal to implemented format before transitioning it to
  implemented.
  A rejection reason is required, non-empty, and single-line.
  --reason is valid only for proposed -> rejected.

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

let list_with_arguments lifecycle days =
  match
    (Spec_dev_tool.Agent_doc.lifecycle_of_string lifecycle, days_of_string days)
  with
  | Ok lifecycle, Ok days -> list_documents lifecycle days
  | Error message, Ok _ | Ok _, Error message | Error message, Error _ ->
      usage_error (Command "list") message

let target_lifecycle value =
  match Spec_dev_tool.Agent_doc.lifecycle_of_string value with
  | Ok Spec_dev_tool.Agent_doc.Implemented ->
      Ok Spec_dev_tool.Agent_doc.Implemented
  | Ok Spec_dev_tool.Agent_doc.Rejected -> Ok Spec_dev_tool.Agent_doc.Rejected
  | Ok Spec_dev_tool.Agent_doc.Archived -> Ok Spec_dev_tool.Agent_doc.Archived
  | Ok Spec_dev_tool.Agent_doc.Proposed | Error _ ->
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
  | "create" -> Some create_help
  | "list" -> Some list_help
  | "check" -> Some check_help
  | "transition" -> Some transition_help
  | _ -> None

let run = function
  | [ _; "--help" ] | [ _; "-h" ] -> print_help top_help
  | [ _; command; ("--help" | "-h") ] -> (
      match command_help command with
      | Some help -> print_help help
      | None ->
          usage_error Top_level (Printf.sprintf "unknown command: %s" command))
  | [ _; "check"; "--all" ] -> check_all ()
  | [ _; "check"; path ] when not (begins_with_hyphen path) -> check path
  | [ _; "create"; document_class; topic ] -> create document_class topic
  | [ _; "list" ] -> list_documents Spec_dev_tool.Agent_doc.Proposed 30
  | [ _; "list"; lifecycle ] -> list_with_arguments lifecycle "30"
  | [ _; "list"; lifecycle; days ] -> list_with_arguments lifecycle days
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
