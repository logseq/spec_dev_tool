type lifecycle = Exploring | Proposed | Implemented | Rejected | Archived

type document_class =
  | Simplification
  | Bugfix
  | Feature
  | Testing
  | Architecture
  | Process

type transition_error = Usage_error of string | Operation_error of string list
type transition_kind = Direct | Reject of string
type transition_reason = No_reason | Rejection_reason of string
type heading = { level : int; title : string; line_index : int }
type project_root = Project_root of string

type document_path = {
  lifecycle : lifecycle;
  document_class : document_class;
  filename : string;
}

type transition_request = {
  source_path : string;
  source : document_path;
  target : lifecycle;
  kind : transition_kind;
}

let document_class_of_string = function
  | "simplification" -> Ok Simplification
  | "bugfix" -> Ok Bugfix
  | "feature" -> Ok Feature
  | "testing" -> Ok Testing
  | "architecture" -> Ok Architecture
  | "process" -> Ok Process
  | value -> Error (Printf.sprintf "invalid class: %s" value)

let string_of_document_class = function
  | Simplification -> "simplification"
  | Bugfix -> "bugfix"
  | Feature -> "feature"
  | Testing -> "testing"
  | Architecture -> "architecture"
  | Process -> "process"

let lifecycle_of_string = function
  | "exploring" -> Ok Exploring
  | "proposed" -> Ok Proposed
  | "implemented" -> Ok Implemented
  | "rejected" -> Ok Rejected
  | "archived" -> Ok Archived
  | value -> Error (Printf.sprintf "invalid lifecycle: %s" value)

let string_of_lifecycle = function
  | Exploring -> "exploring"
  | Proposed -> "proposed"
  | Implemented -> "implemented"
  | Rejected -> "rejected"
  | Archived -> "archived"

let canonical_document_path lifecycle document_class filename =
  Printf.sprintf "docs/agent-guide/%s/%s/%s"
    (string_of_lifecycle lifecycle)
    (string_of_document_class document_class)
    filename

let root_path (Project_root path) = path

let absolute_path root relative_path =
  Filename.concat (root_path root) relative_path

let project_root_error =
  "Cannot locate project root: current directory is not inside a Git worktree."

let resolve_project_root () =
  let stdout_reader, stdout_writer = Unix.pipe ~cloexec:true () in
  let null = Unix.openfile "/dev/null" [ Unix.O_WRONLY ] 0 in
  match
    Unix.create_process "git"
      [| "git"; "rev-parse"; "--show-toplevel" |]
      Unix.stdin stdout_writer null
  with
  | process_id -> (
      Unix.close stdout_writer;
      Unix.close null;
      let stdout_channel = Unix.in_channel_of_descr stdout_reader in
      let stdout =
        Fun.protect
          ~finally:(fun () -> close_in_noerr stdout_channel)
          (fun () -> In_channel.input_all stdout_channel)
      in
      let _, status = Unix.waitpid [] process_id in
      let path = String.trim stdout in
      let valid_output =
        path <> ""
        && (not (Filename.is_relative path))
        && not
             (String.exists (function '\n' | '\r' -> true | _ -> false) path)
      in
      match status with
      | Unix.WEXITED 0 when valid_output -> Ok (Project_root path)
      | Unix.WEXITED 0 | Unix.WEXITED _ | Unix.WSIGNALED _ | Unix.WSTOPPED _ ->
          Error project_root_error)
  | exception Unix.Unix_error _ ->
      Unix.close stdout_reader;
      Unix.close stdout_writer;
      Unix.close null;
      Error project_root_error

let is_ascii_lowercase = function 'a' .. 'z' -> true | _ -> false
let is_ascii_digit = function '0' .. '9' -> true | _ -> false

let is_topic_name value =
  let length = String.length value in
  let rec loop index previous_was_hyphen =
    if index = length then not previous_was_hyphen
    else
      match value.[index] with
      | '-' when index > 0 && not previous_was_hyphen -> loop (index + 1) true
      | character when is_ascii_lowercase character || is_ascii_digit character
        ->
          loop (index + 1) false
      | '-' | _ -> false
  in
  length > 0 && loop 0 false

let is_leap_year year = year mod 400 = 0 || (year mod 4 = 0 && year mod 100 <> 0)

let days_in_month year = function
  | 1 | 3 | 5 | 7 | 8 | 10 | 12 -> 31
  | 4 | 6 | 9 | 11 -> 30
  | 2 -> if is_leap_year year then 29 else 28
  | _ -> 0

let integer_at value offset length =
  let rec loop index result =
    if index = offset + length then Some result
    else
      let character = value.[index] in
      if is_ascii_digit character then
        loop (index + 1) ((result * 10) + Char.code character - Char.code '0')
      else None
  in
  loop offset 0

let date_parts value =
  if String.length value <> 10 || value.[4] <> '-' || value.[7] <> '-' then None
  else
    match
      (integer_at value 0 4, integer_at value 5 2, integer_at value 8 2)
    with
    | Some year, Some month, Some day
      when year > 0 && month >= 1 && month <= 12 && day >= 1
           && day <= days_in_month year month ->
        Some (year, month, day)
    | Some _, Some _, Some _
    | None, Some _, Some _
    | Some _, None, Some _
    | Some _, Some _, None
    | None, None, Some _
    | None, Some _, None
    | Some _, None, None
    | None, None, None ->
        None

let is_valid_date value = Option.is_some (date_parts value)

let days_before_month =
  [| 0; 0; 31; 59; 90; 120; 151; 181; 212; 243; 273; 304; 334 |]

let ordinal_of_date year month day =
  let previous_year = year - 1 in
  let leap_day = if month > 2 && is_leap_year year then 1 else 0 in
  (previous_year * 365) + (previous_year / 4) - (previous_year / 100)
  + (previous_year / 400) + days_before_month.(month) + leap_day + day

let date_ordinal value =
  Option.map
    (fun (year, month, day) -> ordinal_of_date year month day)
    (date_parts value)

let split_path path =
  String.split_on_char '/' path
  |> List.filter (fun component -> component <> "")

let agent_guide_components path =
  let components = split_path path in
  if not (Filename.is_relative path) then
    Error "document path must be a canonical project-relative path"
  else
    match components with
    | "docs" :: "agent-guide" :: remaining -> Ok remaining
    | _ -> Error "expected docs/agent-guide path"

let parse_filename filename =
  let suffix = ".md" in
  let length = String.length filename in
  let suffix_length = String.length suffix in
  if
    length < 11 + suffix_length
    || String.sub filename (length - suffix_length) suffix_length <> suffix
  then Error "filename must use YYYY-MM-DD-<topic-title>.md"
  else
    let date = String.sub filename 0 10 in
    let topic = String.sub filename 11 (length - 11 - suffix_length) in
    if filename.[10] <> '-' then
      Error "filename must use YYYY-MM-DD-<topic-title>.md"
    else if not (is_valid_date date) then
      Error (Printf.sprintf "invalid date: %s" date)
    else if not (is_topic_name topic) then
      Error "topic title must be lowercase kebab-case"
    else Ok (date, topic)

let parse_document_path_components path =
  match agent_guide_components path with
  | Error message -> Error message
  | Ok [ lifecycle; document_class; filename ] -> (
      match lifecycle_of_string lifecycle with
      | Error message -> Error message
      | Ok lifecycle -> (
          match document_class_of_string document_class with
          | Error message -> Error message
          | Ok document_class -> (
              match parse_filename filename with
              | Error message -> Error message
              | Ok _ -> Ok { lifecycle; document_class; filename })))
  | Ok _ ->
      Error
        "expected \
         docs/agent-guide/<lifecycle>/<class>/YYYY-MM-DD-<topic-title>.md"

let parse_document_path path =
  match parse_document_path_components path with
  | Error message -> Error message
  | Ok parsed ->
      let canonical =
        canonical_document_path parsed.lifecycle parsed.document_class
          parsed.filename
      in
      if path = canonical then Ok parsed
      else Error "document path must be a canonical project-relative path"

let lines_of_string content = String.split_on_char '\n' content |> Array.of_list

let heading_of_line line_index line =
  let line = String.trim line in
  let length = String.length line in
  let rec count_hashes index =
    if index < length && line.[index] = '#' then count_hashes (index + 1)
    else index
  in
  let level = count_hashes 0 in
  if level = 0 || level > 6 then None
  else if level = length then Some { level; title = ""; line_index }
  else if line.[level] <> ' ' then None
  else
    let title =
      String.sub line (level + 1) (length - level - 1) |> String.trim
    in
    Some { level; title; line_index }

let is_fence line =
  let line = String.trim line in
  String.length line >= 3
  && ((line.[0] = '`' && line.[1] = '`' && line.[2] = '`')
     || (line.[0] = '~' && line.[1] = '~' && line.[2] = '~'))

let headings lines =
  let rec collect index inside_fence result =
    if index = Array.length lines then List.rev result
    else
      let line = lines.(index) in
      if is_fence line then collect (index + 1) (not inside_fence) result
      else if inside_fence then collect (index + 1) inside_fence result
      else
        match heading_of_line index line with
        | Some heading -> collect (index + 1) inside_fence (heading :: result)
        | None -> collect (index + 1) inside_fence result
  in
  collect 0 false []

let required_sections = function
  | Exploring ->
      [
        "Problem";
        "Proposal";
        "Alternatives considered";
        "Acceptance criteria";
        "Risks";
        "Questions";
      ]
  | Proposed ->
      [
        "Problem";
        "Proposal";
        "Alternatives considered";
        "Acceptance criteria";
        "Risks";
      ]
  | Implemented | Archived ->
      [ "Problem"; "Decision"; "Alternatives considered"; "Consequences" ]
  | Rejected ->
      [ "Problem"; "Proposal"; "Alternatives considered"; "Rejection reason" ]

let find_headings level title headings =
  List.filter
    (fun heading -> heading.level = level && heading.title = title)
    headings

let required_heading_positions required headings =
  List.map
    (fun title ->
      match find_headings 2 title headings with
      | [ heading ] -> (title, heading.line_index)
      | [] -> (title, -1)
      | first :: _ -> (title, first.line_index))
    required

let strictly_increasing positions =
  let rec loop = function
    | [] | [ _ ] -> true
    | (_, left) :: ((_, right) :: _ as remaining) ->
        left < right && loop remaining
  in
  loop positions

let next_level_two_line heading all_headings line_count =
  all_headings
  |> List.filter (fun candidate ->
      candidate.level = 2 && candidate.line_index > heading.line_index)
  |> List.map (fun candidate -> candidate.line_index)
  |> List.fold_left min line_count

let line_is_content line =
  let line = String.trim line in
  line <> ""
  &&
  match heading_of_line 0 line with
  | Some _ -> false
  | None -> not (is_fence line)

let section_lines lines all_headings heading =
  let finish = next_level_two_line heading all_headings (Array.length lines) in
  Array.to_list
    (Array.sub lines (heading.line_index + 1) (finish - heading.line_index - 1))

let starts_with prefix value =
  let prefix_length = String.length prefix in
  String.length value >= prefix_length
  && String.sub value 0 prefix_length = prefix

let bullet_line line = starts_with "- " (String.trim line)

let section_content_errors lines all_headings required =
  required
  |> List.concat_map (fun title ->
      match find_headings 2 title all_headings with
      | [ heading ] ->
          let body = section_lines lines all_headings heading in
          let errors =
            if List.exists line_is_content body then []
            else [ Printf.sprintf "section has no content: %s" title ]
          in
          if title = "Alternatives considered" then
            let finish =
              next_level_two_line heading all_headings (Array.length lines)
            in
            let has_alternative =
              List.exists
                (fun candidate ->
                  candidate.level = 3
                  && candidate.line_index > heading.line_index
                  && candidate.line_index < finish
                  && candidate.title <> "")
                all_headings
            in
            if has_alternative then errors
            else
              errors
              @ [ "Alternatives considered must contain a level-three heading" ]
          else if title = "Acceptance criteria" || title = "Risks" then
            if List.exists bullet_line body then errors
            else errors @ [ Printf.sprintf "%s must contain a bullet" title ]
          else errors
      | [] | _ :: _ :: _ -> [])

let validate_content lifecycle content =
  let lines = lines_of_string content in
  let all_headings = headings lines in
  let level_one = List.filter (fun heading -> heading.level = 1) all_headings in
  let title_errors =
    match level_one with
    | [ heading ] when heading.title <> "" -> []
    | [ _ ] | [] -> [ "document must contain one non-empty level-one title" ]
    | _ :: _ :: _ -> [ "document must contain exactly one level-one title" ]
  in
  let required = required_sections lifecycle in
  let missing_errors =
    required
    |> List.filter_map (fun title ->
        match find_headings 2 title all_headings with
        | [] -> Some (Printf.sprintf "missing required section: %s" title)
        | _ :: _ -> None)
  in
  let duplicate_errors =
    required
    |> List.filter_map (fun title ->
        match find_headings 2 title all_headings with
        | _ :: _ :: _ -> Some (Printf.sprintf "duplicate section: %s" title)
        | [] | [ _ ] -> None)
  in
  let positions = required_heading_positions required all_headings in
  let order_errors =
    if
      missing_errors = [] && duplicate_errors = []
      && not (strictly_increasing positions)
    then [ "required sections are out of order" ]
    else []
  in
  let final_section_errors =
    match lifecycle with
    | Exploring -> (
        match find_headings 2 "Questions" all_headings with
        | [ questions ] -> (
            match
              List.rev
                (List.filter (fun heading -> heading.level = 2) all_headings)
            with
            | final :: _ when final.line_index = questions.line_index -> []
            | final :: _ -> [ "Questions must be the final level-two section" ]
            | [] -> [])
        | [] | _ :: _ :: _ -> [])
    | Proposed | Implemented | Rejected | Archived -> []
  in
  let content_errors = section_content_errors lines all_headings required in
  let errors =
    title_errors @ missing_errors @ duplicate_errors @ order_errors
    @ final_section_errors @ content_errors
  in
  if errors = [] then Ok () else Error errors

let check root path =
  match parse_document_path path with
  | Error message -> Error [ message ]
  | Ok parsed -> (
      match
        In_channel.with_open_bin (absolute_path root path) In_channel.input_all
      with
      | content -> validate_content parsed.lifecycle content
      | exception Sys_error message ->
          Error [ "cannot read document: " ^ message ])

let has_markdown_suffix path = Filename.check_suffix path ".md"

let discovery_error operation path message =
  Printf.sprintf "cannot discover agent documents: %s %s: %s" operation path
    message

let rec discover_agent_document absolute relative documents =
  match Unix.lstat absolute with
  | stats -> (
      match stats.st_kind with
      | Unix.S_DIR ->
          discover_agent_document_directory absolute relative documents
      | Unix.S_REG when has_markdown_suffix relative ->
          Ok (relative :: documents)
      | Unix.S_REG | Unix.S_LNK | Unix.S_CHR | Unix.S_BLK | Unix.S_FIFO
      | Unix.S_SOCK ->
          Ok documents)
  | exception Unix.Unix_error (error, operation, error_path) ->
      Error (discovery_error operation error_path (Unix.error_message error))

and discover_agent_document_directory absolute relative documents =
  match Sys.readdir absolute with
  | names ->
      Array.fold_left
        (fun result name ->
          match result with
          | Ok discovered ->
              discover_agent_document
                (Filename.concat absolute name)
                (Filename.concat relative name)
                discovered
          | Error message -> Error message)
        (Ok documents) names
  | exception Sys_error message ->
      Error (discovery_error "read" absolute message)

let check_all project_root =
  let relative_root = Filename.concat "docs" "agent-guide" in
  let absolute_root = absolute_path project_root relative_root in
  match Unix.lstat absolute_root with
  | stats -> (
      match stats.st_kind with
      | Unix.S_DIR -> (
          match
            discover_agent_document_directory absolute_root relative_root []
          with
          | Ok paths ->
              Ok
                (paths |> List.sort String.compare
                |> List.map (fun path -> (path, check project_root path)))
          | Error message -> Error message)
      | Unix.S_LNK -> Ok []
      | Unix.S_REG | Unix.S_CHR | Unix.S_BLK | Unix.S_FIFO | Unix.S_SOCK ->
          Error (discovery_error "read" absolute_root "not a directory"))
  | exception Unix.Unix_error (Unix.ENOENT, _, _) -> Ok []
  | exception Unix.Unix_error (error, operation, error_path) ->
      Error (discovery_error operation error_path (Unix.error_message error))

let rec create_directory path =
  if path = "." || path = "/" || Sys.file_exists path then ()
  else (
    create_directory (Filename.dirname path);
    Unix.mkdir path 0o755)

let transition_path path =
  match parse_document_path path with
  | Error _ when not (Filename.is_relative path) ->
      Error "source path must be a canonical project-relative path"
  | Error message -> Error message
  | Ok parsed -> Ok parsed

let transition_reason target reason =
  match (target, reason) with
  | Rejected, None ->
      Error (Usage_error "transition to rejected requires --reason <sentence>")
  | Rejected, Some value ->
      let trimmed = String.trim value in
      if
        trimmed = ""
        || String.exists (function '\n' | '\r' -> true | _ -> false) trimmed
      then
        Error (Usage_error "rejection reason must be non-empty and single-line")
      else Ok (Rejection_reason trimmed)
  | (Exploring | Proposed | Implemented | Archived), None -> Ok No_reason
  | (Exploring | Proposed | Implemented | Archived), Some _ ->
      Error (Usage_error "--reason is only valid for transitions to rejected")

let transition_kind source target reason =
  match reason with
  | Rejection_reason reason -> (
      match (source, target) with
      | (Exploring | Proposed), Rejected -> Ok (Reject reason)
      | (Implemented | Rejected | Archived), Rejected ->
          Error (Usage_error "unsupported lifecycle transition")
      | ( (Exploring | Proposed | Implemented | Rejected | Archived),
          (Exploring | Proposed | Implemented | Archived) ) ->
          Error
            (Usage_error "--reason is only valid for transitions to rejected"))
  | No_reason -> (
      match (source, target) with
      | Exploring, Proposed | Proposed, Implemented | Implemented, Archived ->
          Ok Direct
      | (Exploring | Proposed), Rejected ->
          Error
            (Usage_error "transition to rejected requires --reason <sentence>")
      | (Implemented | Rejected | Archived), Rejected
      | Exploring, Exploring
      | Exploring, Implemented
      | Exploring, Archived
      | Proposed, Exploring
      | Proposed, Proposed
      | Proposed, Archived
      | Implemented, Exploring
      | Implemented, Proposed
      | Implemented, Implemented
      | Rejected, Exploring
      | Rejected, Proposed
      | Rejected, Implemented
      | Rejected, Archived
      | Archived, Exploring
      | Archived, Proposed
      | Archived, Implemented
      | Archived, Archived ->
          Error (Usage_error "unsupported lifecycle transition"))

let array_slice array start finish =
  Array.sub array start (finish - start) |> Array.to_list

let remove_trailing_blank_lines lines =
  let rec remove = function
    | line :: remaining when String.trim line = "" -> remove remaining
    | remaining -> List.rev remaining
  in
  remove (List.rev lines)

let rejected_content content reason =
  let lines = lines_of_string content in
  let level_two =
    headings lines |> List.filter (fun heading -> heading.level = 2)
  in
  match level_two with
  | [] -> content
  | first :: _ ->
      let rec blocks = function
        | [] -> []
        | [ heading ] ->
            [
              ( heading.title,
                array_slice lines heading.line_index (Array.length lines) );
            ]
        | heading :: (next :: _ as remaining) ->
            (heading.title, array_slice lines heading.line_index next.line_index)
            :: blocks remaining
      in
      let blocks = blocks level_two in
      let is_reordered title =
        title = "Acceptance criteria"
        || title = "Risks"
        || title = "Alternatives considered"
      in
      let ordinary_blocks =
        blocks
        |> List.filter_map (fun (title, lines) ->
            if is_reordered title then None else Some lines)
      in
      let selected title = List.assoc title blocks in
      let reordered =
        ordinary_blocks
        @ [
            selected "Acceptance criteria";
            selected "Risks";
            selected "Alternatives considered";
          ]
      in
      let prepared_lines =
        array_slice lines 0 first.line_index :: reordered
        |> List.concat |> remove_trailing_blank_lines
      in
      String.concat "\n"
        (prepared_lines @ [ ""; "## Rejection reason"; ""; reason; "" ])

let source_content path =
  match Unix.lstat path with
  | stats -> (
      match stats.st_kind with
      | Unix.S_REG -> (
          match In_channel.with_open_bin path In_channel.input_all with
          | content -> Ok content
          | exception Sys_error message ->
              Error [ "cannot read document: " ^ message ])
      | Unix.S_DIR | Unix.S_LNK | Unix.S_CHR | Unix.S_BLK | Unix.S_FIFO
      | Unix.S_SOCK ->
          Error [ "cannot read document: source is not a regular file" ])
  | exception Unix.Unix_error (error, operation, error_path) ->
      Error
        [
          Printf.sprintf "cannot read document: %s %s: %s" operation error_path
            (Unix.error_message error);
        ]

let destination_status path =
  match Unix.lstat path with
  | _ -> Error [ "destination already exists: " ^ path ]
  | exception Unix.Unix_error (Unix.ENOENT, _, _) -> Ok ()
  | exception Unix.Unix_error (error, operation, error_path) ->
      Error
        [
          Printf.sprintf "cannot inspect destination: %s %s: %s" operation
            error_path (Unix.error_message error);
        ]

let move_content source destination content =
  try
    create_directory (Filename.dirname destination);
    match
      open_out_gen
        [ Open_wronly; Open_creat; Open_excl; Open_binary ]
        0o644 destination
    with
    | channel -> (
        try
          output_string channel content;
          close_out channel;
          Unix.unlink source;
          Ok ()
        with
        | Sys_error message ->
            close_out_noerr channel;
            (try Unix.unlink destination with Unix.Unix_error _ -> ());
            Error [ "cannot move document: " ^ message ]
        | Unix.Unix_error (error, operation, error_path) ->
            close_out_noerr channel;
            (try Unix.unlink destination with Unix.Unix_error _ -> ());
            Error
              [
                Printf.sprintf "cannot move document: %s %s: %s" operation
                  error_path (Unix.error_message error);
              ])
    | exception Sys_error message ->
        Error [ "cannot move document: " ^ message ]
    | exception Unix.Unix_error (error, operation, error_path) ->
        Error
          [
            Printf.sprintf "cannot move document: %s %s: %s" operation
              error_path (Unix.error_message error);
          ]
  with
  | Sys_error message -> Error [ "cannot move document: " ^ message ]
  | Unix.Unix_error (error, operation, error_path) ->
      Error
        [
          Printf.sprintf "cannot move document: %s %s: %s" operation error_path
            (Unix.error_message error);
        ]

let prepare_transition source_path target ~reason =
  match transition_reason target reason with
  | Error error -> Error error
  | Ok reason -> (
      match transition_path source_path with
      | Error message -> Error (Operation_error [ message ])
      | Ok source -> (
          match transition_kind source.lifecycle target reason with
          | Error error -> Error error
          | Ok kind -> Ok { source_path; source; target; kind }))

let transition root request =
  let source_absolute = absolute_path root request.source_path in
  match source_content source_absolute with
  | Error errors -> Error (Operation_error errors)
  | Ok content -> (
      let prepared =
        match request.kind with
        | Reject reason -> (
            match validate_content request.source.lifecycle content with
            | Ok () -> Ok (rejected_content content reason)
            | Error errors -> Error errors)
        | Direct -> Ok content
      in
      match prepared with
      | Error errors -> Error (Operation_error errors)
      | Ok prepared_content -> (
          match validate_content request.target prepared_content with
          | Error errors -> Error (Operation_error errors)
          | Ok () -> (
              let destination =
                canonical_document_path request.target
                  request.source.document_class request.source.filename
              in
              let destination_absolute = absolute_path root destination in
              match destination_status destination_absolute with
              | Error errors -> Error (Operation_error errors)
              | Ok () -> (
                  match
                    move_content source_absolute destination_absolute
                      prepared_content
                  with
                  | Ok () -> Ok destination
                  | Error errors -> Error (Operation_error errors)))))

let current_date () =
  let time = Unix.localtime (Unix.time ()) in
  Printf.sprintf "%04d-%02d-%02d" (time.tm_year + 1900) (time.tm_mon + 1)
    time.tm_mday

let title_of_topic topic =
  topic |> String.split_on_char '-'
  |> List.map String.capitalize_ascii
  |> String.concat " "

let exploring_template topic =
  Printf.sprintf
    "# %s\n\n\
     ## Problem\n\n\
     Describe the problem and why it matters without assuming a solution.\n\n\
     ## Proposal\n\n\
     Describe the proposed decision and its scope.\n\n\
     ## Alternatives considered\n\n\
     ### Alternative\n\n\
     Describe the alternative and why it was not selected.\n\n\
     ## Acceptance criteria\n\n\
     - Define an observable condition that must be true for the proposal to be \
     complete.\n\n\
     ## Risks\n\n\
     - Identify a risk, trade-off, or capability intentionally given up.\n\n\
     ## Questions\n\n\
     - Identify a question to answer before proposing.\n"
    (title_of_topic topic)

let create root document_class topic =
  if not (is_topic_name topic) then
    Error "doc-name must be lowercase kebab-case"
  else
    let document_class = string_of_document_class document_class in
    let relative_path =
      Printf.sprintf "docs/agent-guide/exploring/%s/%s-%s.md" document_class
        (current_date ()) topic
    in
    let destination = absolute_path root relative_path in
    try
      create_directory (Filename.dirname destination);
      let channel =
        open_out_gen
          [ Open_wronly; Open_creat; Open_excl; Open_binary ]
          0o644 destination
      in
      Fun.protect
        ~finally:(fun () -> close_out_noerr channel)
        (fun () -> output_string channel (exploring_template topic));
      Ok relative_path
    with
    | Sys_error _ when Sys.file_exists destination ->
        Error ("document already exists: " ^ relative_path)
    | Sys_error message -> Error ("cannot create document: " ^ message)
    | Unix.Unix_error (error, operation, path) ->
        Error
          (Printf.sprintf "cannot create document: %s: %s: %s" operation path
             (Unix.error_message error))

let list_error operation path message =
  Printf.sprintf "cannot list documents: %s %s: %s" operation path message

let candidate_ordinal = function
  | [ document_class; filename ] -> (
      match
        (document_class_of_string document_class, parse_filename filename)
      with
      | Ok _, Ok (date, _) -> date_ordinal date
      | Error _, Ok _ | Ok _, Error _ | Error _, Error _ -> None)
  | [] | [ _ ] | _ :: _ :: _ :: _ -> None

let candidate lifecycle today earliest components entries =
  match candidate_ordinal components with
  | Some ordinal when ordinal >= earliest && ordinal <= today ->
      let relative_path =
        String.concat "/"
          ([ "docs"; "agent-guide"; string_of_lifecycle lifecycle ] @ components)
      in
      Ok ((ordinal, relative_path) :: entries)
  | Some _ | None -> Ok entries

let rec discover_path lifecycle today earliest components path entries =
  match Unix.lstat path with
  | stats -> (
      match stats.st_kind with
      | Unix.S_DIR ->
          discover_directory lifecycle today earliest components path entries
      | Unix.S_REG -> candidate lifecycle today earliest components entries
      | Unix.S_LNK | Unix.S_CHR | Unix.S_BLK | Unix.S_FIFO | Unix.S_SOCK ->
          Ok entries)
  | exception Unix.Unix_error (error, operation, error_path) ->
      Error (list_error operation error_path (Unix.error_message error))

and discover_directory lifecycle today earliest components path entries =
  match Sys.readdir path with
  | names ->
      Array.fold_left
        (fun result name ->
          match result with
          | Error message -> Error message
          | Ok collected ->
              discover_path lifecycle today earliest (components @ [ name ])
                (Filename.concat path name)
                collected)
        (Ok entries) names
  | exception Sys_error message -> Error (list_error "read" path message)

let compare_discovered (left_date, left_path) (right_date, right_path) =
  let date_order = Int.compare right_date left_date in
  if date_order <> 0 then date_order else String.compare left_path right_path

let list_documents project_root lifecycle days =
  if days <= 0 then Error "days must be a positive base-10 integer"
  else
    let relative_root =
      Filename.concat
        (Filename.concat "docs" "agent-guide")
        (string_of_lifecycle lifecycle)
    in
    let root = absolute_path project_root relative_root in
    let local_time = Unix.localtime (Unix.time ()) in
    let today =
      ordinal_of_date
        (local_time.tm_year + 1900)
        (local_time.tm_mon + 1) local_time.tm_mday
    in
    let earliest = today - (days - 1) in
    match Unix.lstat root with
    | stats -> (
        match stats.st_kind with
        | Unix.S_DIR -> (
            match discover_directory lifecycle today earliest [] root [] with
            | Ok entries ->
                Ok
                  (entries
                  |> List.sort compare_discovered
                  |> List.map (fun (_, path) -> path))
            | Error message -> Error message)
        | Unix.S_LNK -> Ok []
        | Unix.S_REG | Unix.S_CHR | Unix.S_BLK | Unix.S_FIFO | Unix.S_SOCK ->
            Error (list_error "read" root "not a directory"))
    | exception Unix.Unix_error (Unix.ENOENT, _, _) -> Ok []
    | exception Unix.Unix_error (error, operation, error_path) ->
        Error (list_error operation error_path (Unix.error_message error))
