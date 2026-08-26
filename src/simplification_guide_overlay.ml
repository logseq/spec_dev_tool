type t = { content : string; created : bool }
type heading = { level : int; title : string }

let relative_path = ".spec-dev-tool/guides/find-simplifications.md"
let required_title = "Repository-Specific Simplification Rules"

let required_sections =
  [
    "Production corpus";
    "Non-production and ambiguous corpus";
    "Excluded edit targets";
    "Protected surfaces";
    "Candidate priorities";
    "Dependency policy";
    "Required evidence";
    "Validation";
  ]

let template =
  "# " ^ required_title ^ "\n\n"
  ^ (required_sections
    |> List.map (fun title -> "## " ^ title ^ "\n")
    |> String.concat "\n")

let heading_of_line line =
  let line = String.trim line in
  let length = String.length line in
  let rec count_hashes index =
    if index < length && line.[index] = '#' then count_hashes (index + 1)
    else index
  in
  let level = count_hashes 0 in
  if level = 0 || level > 6 || level = length || line.[level] <> ' ' then None
  else
    let title =
      String.sub line (level + 1) (length - level - 1) |> String.trim
    in
    Some { level; title }

let fence_marker line =
  let line = String.trim line in
  let length = String.length line in
  if length < 3 then None
  else
    let marker = line.[0] in
    if marker <> '`' && marker <> '~' then None
    else
      let rec count index =
        if index < length && line.[index] = marker then count (index + 1)
        else index
      in
      let width = count 0 in
      if width >= 3 then Some (marker, width) else None

let headings content =
  let rec collect fence result = function
    | [] -> List.rev result
    | line :: remaining -> (
        match (fence, fence_marker line) with
        | None, Some marker -> collect (Some marker) result remaining
        | Some (marker, width), Some (candidate, candidate_width)
          when marker = candidate && candidate_width >= width ->
            collect None result remaining
        | Some _, Some _ | Some _, None -> collect fence result remaining
        | None, None -> (
            match heading_of_line line with
            | Some heading -> collect None (heading :: result) remaining
            | None -> collect None result remaining))
  in
  collect None [] (String.split_on_char '\n' content)

let duplicate_titles titles =
  let rec collect seen duplicates = function
    | [] -> List.rev duplicates
    | title :: remaining ->
        if List.mem title seen && not (List.mem title duplicates) then
          collect seen (title :: duplicates) remaining
        else collect (title :: seen) duplicates remaining
  in
  collect [] [] titles

let validate content =
  let relevant =
    headings content |> List.filter (fun heading -> heading.level <= 2)
  in
  let level_one =
    relevant
    |> List.filter_map (fun heading ->
        if heading.level = 1 then Some heading.title else None)
  in
  let level_two =
    relevant
    |> List.filter_map (fun heading ->
        if heading.level = 2 then Some heading.title else None)
  in
  let title_errors =
    match level_one with
    | [] -> [ "missing heading: # " ^ required_title ]
    | [ title ] when title = required_title -> []
    | [ title ] -> [ "wrong title: # " ^ title ]
    | _ :: _ :: _ -> [ "additional level-one heading" ]
  in
  let missing_errors =
    required_sections
    |> List.filter_map (fun title ->
        if List.mem title level_two then None
        else Some ("missing heading: ## " ^ title))
  in
  let duplicate_errors =
    duplicate_titles level_two
    |> List.map (fun title -> "duplicate heading: ## " ^ title)
  in
  let additional_errors =
    level_two
    |> List.filter (fun title -> not (List.mem title required_sections))
    |> List.sort_uniq String.compare
    |> List.map (fun title -> "additional level-two heading: ## " ^ title)
  in
  let order_errors =
    if
      missing_errors = [] && duplicate_errors = [] && additional_errors = []
      && level_two <> required_sections
    then [ "out-of-order heading" ]
    else []
  in
  match
    title_errors @ missing_errors @ duplicate_errors @ additional_errors
    @ order_errors
  with
  | [] -> Ok ()
  | errors ->
      Error
        ("Invalid repository simplification rules at " ^ relative_path ^ ": "
       ^ String.concat "; " errors)

let operation_error operation error =
  Printf.sprintf "%s at %s: %s" operation relative_path
    (Unix.error_message error)

let lstat path =
  match Unix.lstat path with
  | statistics -> Ok (Some statistics)
  | exception Unix.Unix_error ((Unix.ENOENT | Unix.ENOTDIR), _, _) -> Ok None
  | exception Unix.Unix_error (error, _, _) ->
      Error
        (operation_error "Cannot inspect repository simplification rules" error)

let ensure_directory path =
  let rec ensure created directory =
    match Unix.lstat directory with
    | statistics ->
        if statistics.st_kind = Unix.S_DIR then Ok created
        else
          Error
            (Printf.sprintf
               "Cannot create repository simplification rules: %s is not a \
                directory"
               directory)
    | exception Unix.Unix_error ((Unix.ENOENT | Unix.ENOTDIR), _, _) -> (
        match ensure created (Filename.dirname directory) with
        | Error message -> Error message
        | Ok created -> (
            match Unix.mkdir directory 0o755 with
            | () -> Ok (directory :: created)
            | exception Unix.Unix_error (Unix.EEXIST, _, _) ->
                ensure created directory
            | exception Unix.Unix_error (error, _, _) ->
                Error
                  (Printf.sprintf
                     "Cannot create repository simplification rules directory \
                      %s: %s"
                     directory (Unix.error_message error))))
    | exception Unix.Unix_error (error, _, _) ->
        Error
          (Printf.sprintf
             "Cannot inspect repository simplification rules directory %s: %s"
             directory (Unix.error_message error))
  in
  ensure [] path

let cleanup_directories directories =
  List.iter
    (fun directory -> try Unix.rmdir directory with Unix.Unix_error _ -> ())
    directories

let create_exclusively path =
  let directory = Filename.dirname path in
  match
    Filename.open_temp_file ~temp_dir:directory ".find-simplifications-" ".tmp"
  with
  | temporary_path, channel ->
      let remove_temporary () =
        try Unix.unlink temporary_path with Unix.Unix_error _ -> ()
      in
      Fun.protect ~finally:remove_temporary (fun () ->
          match
            output_string channel template;
            flush channel;
            close_out channel;
            Unix.chmod temporary_path 0o644;
            Unix.link temporary_path path
          with
          | () -> Ok true
          | exception Unix.Unix_error (Unix.EEXIST, _, _) ->
              close_out_noerr channel;
              Ok false
          | exception Unix.Unix_error (error, _, _) ->
              close_out_noerr channel;
              Error
                (operation_error "Cannot create repository simplification rules"
                   error)
          | exception Sys_error message ->
              close_out_noerr channel;
              Error
                (Printf.sprintf
                   "Cannot create repository simplification rules at %s: %s"
                   relative_path message))
  | exception Sys_error message ->
      Error
        (Printf.sprintf
           "Cannot create repository simplification rules at %s: %s"
           relative_path message)
  | exception Unix.Unix_error (error, _, _) ->
      Error
        (operation_error "Cannot create repository simplification rules" error)

let read_regular_file path =
  match Unix.lstat path with
  | { st_kind = Unix.S_REG; _ } -> (
      match In_channel.with_open_bin path In_channel.input_all with
      | content -> Ok content
      | exception Sys_error message ->
          Error
            (Printf.sprintf
               "Cannot read repository simplification rules at %s: %s"
               relative_path message)
      | exception Unix.Unix_error (error, _, _) ->
          Error
            (operation_error "Cannot read repository simplification rules" error)
      )
  | { st_kind = Unix.S_LNK; _ } ->
      Error
        ("Repository simplification rules path is a symbolic link: "
       ^ relative_path)
  | {
   st_kind = Unix.S_DIR | Unix.S_CHR | Unix.S_BLK | Unix.S_FIFO | Unix.S_SOCK;
   _;
  } ->
      Error
        ("Repository simplification rules path must be a readable regular \
          file: " ^ relative_path)
  | exception Unix.Unix_error (error, _, _) ->
      Error
        (operation_error "Cannot inspect repository simplification rules" error)

let read_and_validate path created =
  match read_regular_file path with
  | Error message -> Error message
  | Ok content -> (
      match validate content with
      | Ok () -> Ok { content; created }
      | Error message -> Error message)

let prepare root =
  let root_path = Agent_doc.project_root_path root in
  let path = Filename.concat root_path relative_path in
  match lstat path with
  | Error message -> Error message
  | Ok (Some _) -> read_and_validate path false
  | Ok None -> (
      match ensure_directory (Filename.dirname path) with
      | Error message -> Error message
      | Ok created_directories -> (
          match create_exclusively path with
          | Error message ->
              cleanup_directories created_directories;
              Error message
          | Ok created -> read_and_validate path created))
