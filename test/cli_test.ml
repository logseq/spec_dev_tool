type command_result = { status : int; stdout : string; stderr : string }

let binary =
  let path = Sys.argv.(1) in
  if Filename.is_relative path then Filename.concat (Sys.getcwd ()) path
  else path

let failures = ref 0
let fail message = raise (Failure message)
let check condition message = if not condition then fail message

let contains haystack needle =
  let haystack_length = String.length haystack in
  let needle_length = String.length needle in
  let rec search index =
    if index + needle_length > haystack_length then false
    else if String.sub haystack index needle_length = needle then true
    else search (index + 1)
  in
  needle_length = 0 || search 0

let index_of haystack needle =
  let haystack_length = String.length haystack in
  let needle_length = String.length needle in
  let rec search index =
    if index + needle_length > haystack_length then None
    else if String.sub haystack index needle_length = needle then Some index
    else search (index + 1)
  in
  if needle_length = 0 then Some 0 else search 0

let count_occurrences haystack needle =
  let haystack_length = String.length haystack in
  let needle_length = String.length needle in
  let rec count index result =
    if index + needle_length > haystack_length then result
    else if String.sub haystack index needle_length = needle then
      count (index + needle_length) (result + 1)
    else count (index + 1) result
  in
  if needle_length = 0 then 0 else count 0 0

let read_file path = In_channel.with_open_bin path In_channel.input_all

let write_file path content =
  let rec create_directory directory =
    if directory = "." || directory = "/" || Sys.file_exists directory then ()
    else (
      create_directory (Filename.dirname directory);
      Unix.mkdir directory 0o755)
  in
  create_directory (Filename.dirname path);
  Out_channel.with_open_bin path (fun channel -> output_string channel content)

let rec remove_tree path =
  match (Unix.lstat path).st_kind with
  | Unix.S_DIR ->
      Sys.readdir path
      |> Array.iter (fun name -> remove_tree (Filename.concat path name));
      Unix.rmdir path
  | Unix.S_REG | Unix.S_LNK | Unix.S_CHR | Unix.S_BLK | Unix.S_FIFO
  | Unix.S_SOCK ->
      Unix.unlink path

let with_non_git_temp_directory callback =
  let path = Filename.temp_file "spec-dev-tool-test-" "" in
  Sys.remove path;
  Unix.mkdir path 0o755;
  Fun.protect ~finally:(fun () -> remove_tree path) (fun () -> callback path)

let initialize_git root =
  let child = Unix.fork () in
  if child = 0 then (
    Unix.chdir root;
    Unix.execvp "git" [| "git"; "init"; "--quiet" |])
  else
    let _, status = Unix.waitpid [] child in
    match status with
    | Unix.WEXITED 0 -> ()
    | Unix.WEXITED code ->
        fail (Printf.sprintf "git init exited with status %d" code)
    | Unix.WSIGNALED signal | Unix.WSTOPPED signal ->
        fail (Printf.sprintf "git init was interrupted by signal %d" signal)

let with_temp_directory callback =
  with_non_git_temp_directory (fun root ->
      initialize_git root;
      callback root)

let exit_code = function
  | Unix.WEXITED code -> code
  | Unix.WSIGNALED signal -> 128 + signal
  | Unix.WSTOPPED signal -> 128 + signal

let run ?path ~cwd arguments =
  let stdout_path = Filename.temp_file "spec-dev-tool-stdout-" ".txt" in
  let stderr_path = Filename.temp_file "spec-dev-tool-stderr-" ".txt" in
  let child = Unix.fork () in
  if child = 0 then (
    Unix.chdir cwd;
    Option.iter (Unix.putenv "PATH") path;
    let stdout_channel = open_out_bin stdout_path in
    let stderr_channel = open_out_bin stderr_path in
    Unix.dup2 (Unix.descr_of_out_channel stdout_channel) Unix.stdout;
    Unix.dup2 (Unix.descr_of_out_channel stderr_channel) Unix.stderr;
    Unix.execv binary (Array.of_list (binary :: arguments)))
  else
    let _, process_status = Unix.waitpid [] child in
    let result =
      {
        status = exit_code process_status;
        stdout = read_file stdout_path;
        stderr = read_file stderr_path;
      }
    in
    Sys.remove stdout_path;
    Sys.remove stderr_path;
    result

let test name callback =
  try
    callback ();
    Printf.printf "ok - %s\n%!" name
  with exn ->
    incr failures;
    Printf.eprintf "not ok - %s\n  %s\n%!" name (Printexc.to_string exn)

let proposed_content ?(technical = "") () =
  "# Issue Picker\n\n"
  ^ "## Problem\n\nAgents need a reliable way to pick an issue.\n\n"
  ^ "## Proposal\n\nAdd an issue picker command.\n\n" ^ technical
  ^ "## Alternatives considered\n\n\
     ### Manual selection\n\n\
     Manual selection is not repeatable.\n\n"
  ^ "## Acceptance criteria\n\n- The command returns one eligible issue.\n\n"
  ^ "## Risks\n\n- Repository APIs may rate limit requests.\n"

let exploring_content ?(technical = "") () =
  proposed_content ~technical ()
  ^ "\n## Questions\n\n- Which repository API provides eligible issues?\n"

let implemented_content =
  "# Issue Picker\n\n"
  ^ "## Problem\n\nAgents need a reliable way to pick an issue.\n\n"
  ^ "## Decision\n\nThe CLI provides an issue picker command.\n\n"
  ^ "## Command behavior\n\nThe command returns the oldest eligible issue.\n\n"
  ^ "## Alternatives considered\n\n\
     ### Manual selection\n\n\
     Manual selection is not repeatable.\n\n"
  ^ "## Consequences\n\n\
     Issue selection is repeatable and requires API access.\n"

let rejected_content =
  "# Issue Picker\n\n"
  ^ "## Problem\n\nAgents need a reliable way to pick an issue.\n\n"
  ^ "## Proposal\n\nAdd an issue picker command.\n\n"
  ^ "## Alternatives considered\n\n\
     ### Manual selection\n\n\
     Manual selection is not repeatable.\n\n"
  ^ "## Rejection reason\n\n\
     The repository API cannot provide the required data.\n"

let check_success result =
  check (result.status = 0)
    (Printf.sprintf "expected exit 0, got %d; stderr: %s" result.status
       result.stderr)

let check_failure ?(status = 1) result expected_message =
  check (result.status = status)
    (Printf.sprintf "expected exit %d, got %d" status result.status);
  check
    (contains result.stderr expected_message)
    (Printf.sprintf "expected stderr to contain %S, got %S" expected_message
       result.stderr)

let check_file root relative_path content =
  write_file (Filename.concat root relative_path) content;
  run ~cwd:root [ "check"; relative_path ]

let current_date () =
  let time = Unix.localtime (Unix.time ()) in
  Printf.sprintf "%04d-%02d-%02d" (time.tm_year + 1900) (time.tm_mon + 1)
    time.tm_mday

let date_with_offset offset =
  let today = Unix.localtime (Unix.time ()) in
  let noon =
    {
      today with
      tm_sec = 0;
      tm_min = 0;
      tm_hour = 12;
      tm_mday = today.tm_mday + offset;
    }
  in
  let timestamp, _ = Unix.mktime noon in
  let date = Unix.localtime timestamp in
  Printf.sprintf "%04d-%02d-%02d" (date.tm_year + 1900) (date.tm_mon + 1)
    date.tm_mday

let document_path lifecycle document_class date topic =
  Printf.sprintf "docs/agent-guide/%s/%s/%s-%s.md" lifecycle document_class date
    topic

let write_document root lifecycle document_class date topic content =
  let relative_path = document_path lifecycle document_class date topic in
  write_file (Filename.concat root relative_path) content;
  relative_path

let output_lines output =
  output |> String.split_on_char '\n'
  |> List.filter (fun line -> String.length line > 0)

let check_lines result expected =
  check_success result;
  let actual = output_lines result.stdout in
  check (actual = expected)
    (Printf.sprintf "expected stdout %S, got %S"
       (String.concat "\\n" expected)
       (String.concat "\\n" actual))

let check_before text left right =
  match (index_of text left, index_of text right) with
  | Some left_index, Some right_index ->
      check (left_index < right_index)
        (Printf.sprintf "expected %S before %S in %S" left right text)
  | None, Some _ -> fail (Printf.sprintf "missing %S in %S" left text)
  | Some _, None -> fail (Printf.sprintf "missing %S in %S" right text)
  | None, None ->
      fail (Printf.sprintf "missing %S and %S in %S" left right text)

let check_path_absent root path =
  check
    (not (Sys.file_exists (Filename.concat root path)))
    ("expected path to be absent: " ^ path)

let check_path_content root path expected =
  let absolute_path = Filename.concat root path in
  check (Sys.file_exists absolute_path) ("expected path to exist: " ^ path);
  check
    (read_file absolute_path = expected)
    (Printf.sprintf "unexpected content at %s" path)

let () =
  test "check accepts every lifecycle with its required structure" (fun () ->
      with_temp_directory (fun root ->
          [
            ("exploring", exploring_content ());
            ("proposed", proposed_content ());
            ("implemented", implemented_content);
            ("rejected", rejected_content);
            ("archived", implemented_content);
          ]
          |> List.iter (fun (lifecycle, content) ->
              let path =
                Printf.sprintf
                  "docs/agent-guide/%s/feature/2026-08-20-issue-picker.md"
                  lifecycle
              in
              let result = check_file root path content in
              check_success result;
              check
                (contains result.stdout "Valid agent document")
                "expected check confirmation")));

  test "check requires a non-empty final Questions section for exploring docs"
    (fun () ->
      with_temp_directory (fun root ->
          let without_questions = proposed_content () in
          let questions_before_risks =
            "# Title\n\n## Problem\n\nProblem.\n\n## Proposal\n\nProposal.\n\n"
            ^ "## Alternatives considered\n\n### Other\n\nOther.\n\n"
            ^ "## Acceptance criteria\n\n- Done.\n\n"
            ^ "## Questions\n\n- What remains?\n\n## Risks\n\n- Risk.\n"
          in
          let empty_questions = proposed_content () ^ "\n## Questions\n" in
          [
            ( "missing-questions",
              without_questions,
              "missing required section: Questions" );
            ( "questions-not-final",
              questions_before_risks,
              "Questions must be the final level-two section" );
            ( "empty-questions",
              empty_questions,
              "section has no content: Questions" );
          ]
          |> List.iter (fun (topic, content, message) ->
              let path =
                Printf.sprintf
                  "docs/agent-guide/exploring/feature/2026-08-20-%s.md" topic
              in
              check_file root path content |> fun result ->
              check_failure result message)));

  test "check accepts every document class and rejects absolute paths"
    (fun () ->
      with_temp_directory (fun root ->
          [
            "simplification";
            "bugfix";
            "feature";
            "testing";
            "architecture";
            "process";
          ]
          |> List.iter (fun document_class ->
              let relative_path =
                Printf.sprintf
                  "docs/agent-guide/proposed/%s/2026-08-20-issue-picker.md"
                  document_class
              in
              let absolute_path = Filename.concat root relative_path in
              write_file absolute_path (proposed_content ());
              run ~cwd:root [ "check"; relative_path ] |> check_success;
              run ~cwd:root [ "check"; absolute_path ] |> fun result ->
              check_failure result "canonical project-relative")));

  test "check accepts optional technical sections in the documented position"
    (fun () ->
      with_temp_directory (fun root ->
          let content =
            proposed_content
              ~technical:"## Selection rules\n\nPick the oldest issue.\n\n" ()
          in
          check_file root
            "docs/agent-guide/proposed/feature/2024-02-29-issue-picker.md"
            content
          |> check_success));

  test "check rejects invalid path components and filenames" (fun () ->
      with_temp_directory (fun root ->
          [
            ( "docs/agent-guide/draft/feature/2026-08-20-issue-picker.md",
              "invalid lifecycle" );
            ( "docs/agent-guide/proposed/refactor/2026-08-20-issue-picker.md",
              "invalid class" );
            ( "notes/proposed/feature/2026-08-20-issue-picker.md",
              "expected docs/agent-guide" );
            ( "docs/agent-guide/proposed/feature/2026-02-30-issue-picker.md",
              "invalid date" );
            ( "docs/agent-guide/proposed/feature/2026-08-20-Issue-Picker.md",
              "lowercase kebab-case" );
            ( "docs/agent-guide/proposed/feature/2026-08-20-issue_picker.md",
              "lowercase kebab-case" );
            ( "docs/agent-guide/proposed/feature/2026-08-20-.md",
              "lowercase kebab-case" );
          ]
          |> List.iter (fun (path, message) ->
              check_file root path (proposed_content ()) |> fun result ->
              check_failure result message)));

  test "check rejects missing files" (fun () ->
      with_temp_directory (fun root ->
          run ~cwd:root
            [
              "check"; "docs/agent-guide/proposed/feature/2026-08-20-missing.md";
            ]
          |> fun result -> check_failure result "cannot read document"));

  test
    "check rejects lifecycle-specific missing, reordered, and duplicate \
     sections" (fun () ->
      with_temp_directory (fun root ->
          let cases =
            [
              ( "missing-risks",
                String.concat ""
                  [
                    "# Title\n\n\
                     ## Problem\n\n\
                     Problem.\n\n\
                     ## Proposal\n\n\
                     Proposal.\n\n";
                    "## Alternatives considered\n\n### Other\n\nOther.\n\n";
                    "## Acceptance criteria\n\n- Done.\n";
                  ],
                "missing required section: Risks" );
              ( "wrong-order",
                "# Title\n\n\
                 ## Proposal\n\n\
                 Proposal.\n\n\
                 ## Problem\n\n\
                 Problem.\n\n"
                ^ "## Alternatives considered\n\n### Other\n\nOther.\n\n"
                ^ "## Acceptance criteria\n\n- Done.\n\n## Risks\n\n- Risk.\n",
                "required sections are out of order" );
              ( "duplicate-problem",
                "# Title\n\n## Problem\n\nProblem.\n\n## Problem\n\nAgain.\n\n"
                ^ "## Proposal\n\nProposal.\n\n## Alternatives considered\n\n"
                ^ "### Other\n\nOther.\n\n## Acceptance criteria\n\n- Done.\n\n"
                ^ "## Risks\n\n- Risk.\n",
                "duplicate section: Problem" );
              ( "proposal-in-implemented",
                proposed_content (),
                "missing required section: Decision" );
            ]
          in
          cases
          |> List.iter (fun (topic, content, message) ->
              let lifecycle =
                if topic = "proposal-in-implemented" then "implemented"
                else "proposed"
              in
              let path =
                Printf.sprintf "docs/agent-guide/%s/feature/2026-08-20-%s.md"
                  lifecycle topic
              in
              check_file root path content |> fun result ->
              check_failure result message)));

  test
    "check rejects empty content requirements and headings inside code fences"
    (fun () ->
      with_temp_directory (fun root ->
          let cases =
            [
              ( "empty-title",
                "# \n\n## Problem\n\nProblem.\n\n## Proposal\n\nProposal.\n\n"
                ^ "## Alternatives considered\n\n### Other\n\nOther.\n\n"
                ^ "## Acceptance criteria\n\n- Done.\n\n## Risks\n\n- Risk.\n",
                "non-empty level-one title" );
              ( "empty-problem",
                "# Title\n\n## Problem\n\n## Proposal\n\nProposal.\n\n"
                ^ "## Alternatives considered\n\n### Other\n\nOther.\n\n"
                ^ "## Acceptance criteria\n\n- Done.\n\n## Risks\n\n- Risk.\n",
                "section has no content: Problem" );
              ( "no-alternative",
                "# Title\n\n\
                 ## Problem\n\n\
                 Problem.\n\n\
                 ## Proposal\n\n\
                 Proposal.\n\n"
                ^ "## Alternatives considered\n\nNo named alternative.\n\n"
                ^ "## Acceptance criteria\n\n- Done.\n\n## Risks\n\n- Risk.\n",
                "Alternatives considered must contain a level-three heading" );
              ( "no-acceptance-list",
                "# Title\n\n\
                 ## Problem\n\n\
                 Problem.\n\n\
                 ## Proposal\n\n\
                 Proposal.\n\n"
                ^ "## Alternatives considered\n\n### Other\n\nOther.\n\n"
                ^ "## Acceptance criteria\n\nDone.\n\n## Risks\n\n- Risk.\n",
                "Acceptance criteria must contain a bullet" );
              ( "fenced-risks",
                "# Title\n\n\
                 ## Problem\n\n\
                 Problem.\n\n\
                 ## Proposal\n\n\
                 Proposal.\n\n"
                ^ "## Alternatives considered\n\n### Other\n\nOther.\n\n"
                ^ "## Acceptance criteria\n\n- Done.\n\n```markdown\n## Risks\n"
                ^ "- Not a real section.\n```\n",
                "missing required section: Risks" );
            ]
          in
          cases
          |> List.iter (fun (topic, content, message) ->
              let path =
                Printf.sprintf
                  "docs/agent-guide/proposed/testing/2026-08-20-%s.md" topic
              in
              check_file root path content |> fun result ->
              check_failure result message)));

  test "create builds and validates an exploring document for every class"
    (fun () ->
      with_temp_directory (fun root ->
          [
            "simplification";
            "bugfix";
            "feature";
            "testing";
            "architecture";
            "process";
          ]
          |> List.iter (fun document_class ->
              let topic = document_class ^ "-decision" in
              let result = run ~cwd:root [ "create"; document_class; topic ] in
              check_success result;
              let relative_path =
                Printf.sprintf "docs/agent-guide/exploring/%s/%s-%s.md"
                  document_class (current_date ()) topic
              in
              check
                (Sys.file_exists (Filename.concat root relative_path))
                ("expected created file: " ^ relative_path);
              check
                (contains result.stdout ("Created " ^ relative_path))
                "expected created path on stdout";
              run ~cwd:root [ "check"; relative_path ] |> check_success)));

  test "create writes the documented exploring outline and derives its title"
    (fun () ->
      with_temp_directory (fun root ->
          run ~cwd:root [ "create"; "feature"; "api-client" ] |> check_success;
          let path =
            Filename.concat root
              (Printf.sprintf
                 "docs/agent-guide/exploring/feature/%s-api-client.md"
                 (current_date ()))
          in
          let content = read_file path in
          check
            (contains content "# Api Client\n")
            "expected title derived from topic";
          [
            "## Problem";
            "## Proposal";
            "## Alternatives considered";
            "### Alternative";
            "## Acceptance criteria";
            "## Risks";
            "## Questions";
          ]
          |> List.iter (fun heading ->
              check (contains content heading) ("missing heading: " ^ heading));
          check
            (String.ends_with ~suffix:"answer before proposing.\n" content)
            "expected Questions to be the final section"));

  test "create rejects invalid classes and topic names" (fun () ->
      with_temp_directory (fun root ->
          run ~cwd:root [ "create"; "refactor"; "issue-picker" ]
          |> fun result ->
          check_failure ~status:2 result "invalid class";
          [
            "Issue-picker";
            "issue_picker";
            "issue/picker";
            "-issue";
            "issue-";
            "";
          ]
          |> List.iter (fun topic ->
              run ~cwd:root [ "create"; "feature"; topic ] |> fun result ->
              check_failure ~status:2 result "lowercase kebab-case")));

  test "create never overwrites an existing document" (fun () ->
      with_temp_directory (fun root ->
          let path =
            Printf.sprintf
              "docs/agent-guide/exploring/feature/%s-issue-picker.md"
              (current_date ())
          in
          write_file (Filename.concat root path) "existing content\n";
          run ~cwd:root [ "create"; "feature"; "issue-picker" ] |> fun result ->
          check_failure result "document already exists";
          check
            (read_file (Filename.concat root path) = "existing content\n")
            "existing document was modified"));

  test "lifecycle list commands apply the date-window default" (fun () ->
      with_temp_directory (fun root ->
          let exploring_today =
            write_document root "exploring" "feature" (date_with_offset 0)
              "today" "invalid content is still discoverable\n"
          in
          let exploring_boundary =
            write_document root "exploring" "bugfix" (date_with_offset (-29))
              "boundary" "content\n"
          in
          ignore
            (write_document root "exploring" "feature" (date_with_offset (-30))
               "too-old" "content\n");
          let proposed =
            write_document root "proposed" "feature" (date_with_offset 0)
              "proposed" "content\n"
          in
          let implemented =
            write_document root "implemented" "process" (date_with_offset 0)
              "implemented" "content\n"
          in
          let rejected =
            write_document root "rejected" "testing" (date_with_offset (-6))
              "rejected" "content\n"
          in
          let archived =
            write_document root "archived" "architecture" (date_with_offset 0)
              "archived" "content\n"
          in
          let expected_default = [ exploring_today; exploring_boundary ] in
          run ~cwd:root [ "list-exploring" ] |> fun result ->
          check_lines result expected_default;
          run ~cwd:root [ "list-exploring"; "30" ] |> fun result ->
          check_lines result expected_default;
          run ~cwd:root [ "list-proposed"; "30" ] |> fun result ->
          check_lines result [ proposed ];
          run ~cwd:root [ "list-implemented" ] |> fun result ->
          check_lines result [ implemented ];
          run ~cwd:root [ "list-rejected"; "7" ] |> fun result ->
          check_lines result [ rejected ];
          run ~cwd:root [ "list-archived"; "1" ] |> fun result ->
          check_lines result [ archived ]));

  test "lifecycle list commands sort by date and then complete path" (fun () ->
      with_temp_directory (fun root ->
          let newer_process =
            write_document root "proposed" "process" (date_with_offset 0) "zulu"
              "content\n"
          in
          let newer_bugfix =
            write_document root "proposed" "bugfix" (date_with_offset 0) "alpha"
              "content\n"
          in
          let older =
            write_document root "proposed" "architecture"
              (date_with_offset (-1)) "middle" "content\n"
          in
          run ~cwd:root [ "list-proposed"; "2" ] |> fun result ->
          check_lines result [ newer_bugfix; newer_process; older ]));

  test "lifecycle list commands ignore malformed and out-of-window paths"
    (fun () ->
      with_temp_directory (fun root ->
          let valid =
            write_document root "proposed" "feature" (date_with_offset 0)
              "valid" "not a valid agent document\n"
          in
          ignore
            (write_document root "proposed" "feature" (date_with_offset 1)
               "future" "content\n");
          ignore
            (write_document root "proposed" "feature" (date_with_offset (-30))
               "old" "content\n");
          let today = date_with_offset 0 in
          write_file
            (Filename.concat root
               (Printf.sprintf
                  "docs/agent-guide/proposed/not-a-class/%s-invalid.md" today))
            "content\n";
          write_file
            (Filename.concat root
               (Printf.sprintf
                  "docs/agent-guide/proposed/feature/nested/%s-nested.md" today))
            "content\n";
          write_file
            (Filename.concat root
               "docs/agent-guide/proposed/feature/2026-02-30-invalid.md")
            "content\n";
          write_file
            (Filename.concat root
               (Printf.sprintf
                  "docs/agent-guide/proposed/feature/%s-not-markdown.txt" today))
            "content\n";
          let markdown_directory =
            Filename.concat root
              (Printf.sprintf
                 "docs/agent-guide/proposed/feature/%s-directory.md" today)
          in
          Unix.mkdir markdown_directory 0o755;
          let external_directory = Filename.concat root "external" in
          Unix.mkdir external_directory 0o755;
          write_file
            (Filename.concat external_directory
               (Printf.sprintf "%s-linked.md" today))
            "content\n";
          Unix.symlink external_directory
            (Filename.concat root "docs/agent-guide/proposed/feature/linked");
          Unix.symlink
            (Filename.concat root valid)
            (Filename.concat root
               (Printf.sprintf "docs/agent-guide/proposed/feature/%s-symlink.md"
                  today));
          run ~cwd:root [ "list-proposed" ] |> fun result ->
          check_lines result [ valid ]));

  test "lifecycle list commands use filename dates" (fun () ->
      with_temp_directory (fun root ->
          let boundary =
            write_document root "proposed" "feature" (date_with_offset (-6))
              "boundary" "content\n"
          in
          let today =
            write_document root "proposed" "testing" (date_with_offset 0)
              "today" "content\n"
          in
          Unix.utimes
            (Filename.concat root boundary)
            (Unix.time ()) (Unix.time ());
          Unix.utimes (Filename.concat root today) 0.0 0.0;
          run ~cwd:root [ "list-proposed"; "7" ] |> fun result ->
          check_lines result [ today; boundary ]));

  test "lifecycle list commands accept a missing lifecycle directory" (fun () ->
      with_temp_directory (fun root ->
          let result = run ~cwd:root [ "list-implemented" ] in
          check_success result;
          check (result.stdout = "")
            (Printf.sprintf "expected empty stdout, got %S" result.stdout);
          check (result.stderr = "")
            (Printf.sprintf "expected empty stderr, got %S" result.stderr)));

  test "lifecycle list commands report traversal errors atomically" (fun () ->
      with_temp_directory (fun root ->
          ignore
            (write_document root "proposed" "feature" (date_with_offset 0)
               "valid" "content\n");
          let blocked =
            Filename.concat root "docs/agent-guide/proposed/feature/blocked"
          in
          Unix.mkdir blocked 0o755;
          Unix.chmod blocked 0o000;
          Fun.protect
            ~finally:(fun () -> Unix.chmod blocked 0o755)
            (fun () ->
              let result = run ~cwd:root [ "list-proposed" ] in
              check_failure result "cannot list documents";
              check (result.stdout = "")
                (Printf.sprintf "expected empty stdout, got %S" result.stdout))));

  test "lifecycle list commands reject invalid days and remove list" (fun () ->
      with_temp_directory (fun root ->
          [
            [ "list-proposed"; "0" ];
            [ "list-proposed"; "-1" ];
            [ "list-proposed"; "seven" ];
            [ "list-proposed"; "7"; "extra" ];
          ]
          |> List.iter (fun arguments ->
              run ~cwd:root arguments |> fun result ->
              check_failure ~status:2 result
                "Try: spec-dev-tool list-proposed --help");
          [
            [ "list" ];
            [ "list"; "--help" ];
            [ "list"; "proposed" ];
            [ "list-draft" ];
            [ "list-draft"; "--help" ];
          ]
          |> List.iter (fun arguments ->
              run ~cwd:root arguments |> fun result ->
              check_failure ~status:2 result "Try: spec-dev-tool --help")));

  test
    "check --all checks every Markdown candidate and sorts both output streams"
    (fun () ->
      with_temp_directory (fun root ->
          let valid_paths =
            [
              write_document root "exploring" "feature" "1999-01-01" "exploring"
                (exploring_content ());
              write_document root "proposed" "feature" "1999-01-01" "old"
                (proposed_content ());
              write_document root "implemented" "process" "2026-08-20"
                "implemented" implemented_content;
              write_document root "rejected" "testing" "2026-08-20" "rejected"
                rejected_content;
              write_document root "archived" "architecture" "2026-08-20"
                "archived" implemented_content;
            ]
            |> List.sort String.compare
          in
          let invalid_content =
            write_document root "proposed" "bugfix" "2026-08-20" "broken"
              "# Broken\n"
          in
          let malformed_path =
            "docs/agent-guide/draft/feature/not-a-valid-name.md"
          in
          write_file (Filename.concat root malformed_path) (proposed_content ());
          let result = run ~cwd:root [ "check"; "--all" ] in
          check (result.status = 1)
            (Printf.sprintf "expected exit 1, got %d" result.status);
          let expected_stdout =
            List.map (fun path -> "Valid agent document: " ^ path) valid_paths
          in
          check
            (output_lines result.stdout = expected_stdout)
            (Printf.sprintf "unexpected stdout: %S" result.stdout);
          let invalid_paths =
            [ invalid_content; malformed_path ] |> List.sort String.compare
          in
          check_before result.stderr
            ("Invalid agent document: " ^ List.nth invalid_paths 0)
            ("Invalid agent document: " ^ List.nth invalid_paths 1);
          List.iter
            (fun path ->
              check
                (contains result.stderr ("Invalid agent document: " ^ path))
                ("missing invalid report for " ^ path))
            invalid_paths;
          check
            (contains result.stderr "missing required section: Problem")
            "expected all content errors to be reported"));

  test "check --all ignores non-candidates and accepts missing or empty roots"
    (fun () ->
      with_temp_directory (fun root ->
          let markdown_parent =
            Filename.concat root "docs/agent-guide/proposed/feature"
          in
          write_file (Filename.concat markdown_parent "notes.txt") "ignored\n";
          let markdown_directory =
            Filename.concat markdown_parent "2026-08-20-directory.md"
          in
          Unix.mkdir markdown_directory 0o755;
          let external_file = Filename.concat root "external.md" in
          write_file external_file "invalid\n";
          Unix.symlink external_file
            (Filename.concat markdown_parent "2026-08-20-linked-file.md");
          let external_directory = Filename.concat root "external-directory" in
          Unix.mkdir external_directory 0o755;
          write_file
            (Filename.concat external_directory "2026-08-20-hidden.md")
            "invalid\n";
          Unix.symlink external_directory
            (Filename.concat markdown_parent "linked-directory");
          let result = run ~cwd:root [ "check"; "--all" ] in
          check_success result;
          check (result.stdout = "") "expected ignored candidates to be silent";
          check (result.stderr = "") "expected ignored candidates to be silent");
      with_temp_directory (fun root ->
          let result = run ~cwd:root [ "check"; "--all" ] in
          check_success result;
          check (result.stdout = "") "expected a missing root to be silent";
          check (result.stderr = "") "expected a missing root to be silent");
      with_temp_directory (fun root ->
          let directory = Filename.concat root "docs/agent-guide" in
          let rec make path =
            if path = root || Sys.file_exists path then ()
            else (
              make (Filename.dirname path);
              Unix.mkdir path 0o755)
          in
          make directory;
          let result = run ~cwd:root [ "check"; "--all" ] in
          check_success result;
          check (result.stdout = "") "expected an empty root to be silent";
          check (result.stderr = "") "expected an empty root to be silent"));

  test "check --all reports discovery failures without partial results"
    (fun () ->
      with_temp_directory (fun root ->
          ignore
            (write_document root "proposed" "feature" "2026-08-20" "valid"
               (proposed_content ()));
          let blocked =
            Filename.concat root "docs/agent-guide/proposed/feature/blocked"
          in
          Unix.mkdir blocked 0o755;
          Unix.chmod blocked 0o000;
          Fun.protect
            ~finally:(fun () -> Unix.chmod blocked 0o755)
            (fun () ->
              let result = run ~cwd:root [ "check"; "--all" ] in
              check_failure result "cannot discover agent documents";
              check (result.stdout = "")
                (Printf.sprintf "expected no partial stdout, got %S"
                   result.stdout))));

  test "check --all reports unreadable Markdown candidates" (fun () ->
      with_temp_directory (fun root ->
          let path =
            write_document root "proposed" "feature" "2026-08-20" "unreadable"
              (proposed_content ())
          in
          let absolute_path = Filename.concat root path in
          Unix.chmod absolute_path 0o000;
          Fun.protect
            ~finally:(fun () -> Unix.chmod absolute_path 0o644)
            (fun () ->
              let result = run ~cwd:root [ "check"; "--all" ] in
              check_failure result "cannot read document";
              check (result.stdout = "")
                (Printf.sprintf "expected no valid stdout, got %S" result.stdout);
              check
                (contains result.stderr ("Invalid agent document: " ^ path))
                "expected the unreadable candidate path")));

  test "transition moves target-valid documents across direct lifecycle edges"
    (fun () ->
      with_temp_directory (fun root ->
          let exploring_source =
            write_document root "exploring" "feature" "2026-08-20"
              "proposed-transition" (proposed_content ())
          in
          let proposed_destination =
            document_path "proposed" "feature" "2026-08-20"
              "proposed-transition"
          in
          let proposed_result =
            run ~cwd:root [ "transition"; exploring_source; "proposed" ]
          in
          check_success proposed_result;
          check_path_absent root exploring_source;
          check_path_content root proposed_destination (proposed_content ());
          run ~cwd:root [ "check"; proposed_destination ] |> check_success;
          let source =
            write_document root "proposed" "feature" "2026-08-20"
              "implemented-transition" implemented_content
          in
          let destination =
            document_path "implemented" "feature" "2026-08-20"
              "implemented-transition"
          in
          let result = run ~cwd:root [ "transition"; source; "implemented" ] in
          check_success result;
          check
            (result.stdout = destination ^ "\n")
            (Printf.sprintf "unexpected transition output: %S" result.stdout);
          check (result.stderr = "") "expected no transition error output";
          check_path_absent root source;
          check_path_content root destination implemented_content;
          run ~cwd:root [ "check"; destination ] |> check_success;
          let archived_source =
            write_document root "implemented" "process" "2026-08-20"
              "archived-transition" implemented_content
          in
          let archived_destination =
            document_path "archived" "process" "2026-08-20"
              "archived-transition"
          in
          let archived_result =
            run ~cwd:root [ "transition"; archived_source; "archived" ]
          in
          check_success archived_result;
          check
            (archived_result.stdout = archived_destination ^ "\n")
            "expected only the archived destination path";
          check_path_absent root archived_source;
          check_path_content root archived_destination implemented_content));

  test "transition converts a proposed document to rejected deterministically"
    (fun () ->
      with_temp_directory (fun root ->
          let source =
            write_document root "proposed" "architecture" "2026-08-20"
              "rejected-transition"
              (proposed_content
                 ~technical:
                   "## Selection rules\n\nPick the oldest issue first.\n\n"
                 ())
          in
          let destination =
            document_path "rejected" "architecture" "2026-08-20"
              "rejected-transition"
          in
          let result =
            run ~cwd:root
              [
                "transition";
                source;
                "rejected";
                "--reason";
                "  The required API is unavailable.  ";
              ]
          in
          check_success result;
          check
            (result.stdout = destination ^ "\n")
            "expected only the rejected destination path";
          check_path_absent root source;
          let content = read_file (Filename.concat root destination) in
          [
            "## Problem";
            "## Proposal";
            "## Selection rules";
            "## Acceptance criteria";
            "## Risks";
            "## Alternatives considered";
            "### Manual selection";
            "## Rejection reason";
          ]
          |> List.iter (fun heading ->
              check (contains content heading) ("missing heading: " ^ heading));
          check_before content "## Selection rules" "## Acceptance criteria";
          check_before content "## Acceptance criteria" "## Risks";
          check_before content "## Risks" "## Alternatives considered";
          check_before content "## Alternatives considered"
            "## Rejection reason";
          check
            (count_occurrences content "## Rejection reason" = 1)
            "expected exactly one rejection reason section";
          check
            (contains content
               "## Rejection reason\n\nThe required API is unavailable.\n")
            "expected the trimmed reason verbatim";
          run ~cwd:root [ "check"; destination ] |> check_success));

  test
    "transition converts a valid exploring document to valid rejected content"
    (fun () ->
      with_temp_directory (fun root ->
          let source =
            write_document root "exploring" "feature" "2026-08-20"
              "rejected-exploration" (exploring_content ())
          in
          let destination =
            document_path "rejected" "feature" "2026-08-20"
              "rejected-exploration"
          in
          let result =
            run ~cwd:root
              [
                "transition";
                source;
                "rejected";
                "--reason";
                "The open question cannot be resolved.";
              ]
          in
          check_success result;
          check_path_absent root source;
          let content = read_file (Filename.concat root destination) in
          check (contains content "## Questions") "expected questions preserved";
          check_before content "## Questions" "## Rejection reason";
          run ~cwd:root [ "check"; destination ] |> check_success));

  test "transition rejects invalid reason usage without filesystem changes"
    (fun () ->
      with_temp_directory (fun root ->
          let source =
            write_document root "proposed" "feature" "2026-08-20" "reason"
              (proposed_content ())
          in
          [
            [ "transition"; source; "rejected" ];
            [ "transition"; source; "rejected"; "--reason"; "" ];
            [ "transition"; source; "rejected"; "--reason"; "   " ];
            [
              "transition"; source; "rejected"; "--reason"; "line one\nline two";
            ];
            [ "transition"; source; "implemented"; "--reason"; "Not allowed." ];
          ]
          |> List.iter (fun arguments ->
              let result = run ~cwd:root arguments in
              check_failure ~status:2 result
                "Try: spec-dev-tool transition --help";
              check_path_content root source (proposed_content ());
              check_path_absent root
                (document_path "rejected" "feature" "2026-08-20" "reason"))));

  test "transition rejects unsupported edges and target lifecycle values"
    (fun () ->
      with_temp_directory (fun root ->
          let cases =
            [
              ( "proposed",
                "feature",
                "unsupported-archive",
                proposed_content (),
                "archived" );
              ( "exploring",
                "feature",
                "unsupported-implemented",
                exploring_content (),
                "implemented" );
              ( "implemented",
                "process",
                "unsupported-reject",
                implemented_content,
                "rejected" );
              ( "rejected",
                "testing",
                "unsupported-implemented",
                rejected_content,
                "implemented" );
              ( "archived",
                "architecture",
                "unsupported-archived",
                implemented_content,
                "archived" );
              ( "proposed",
                "feature",
                "invalid-target",
                proposed_content (),
                "draft" );
            ]
          in
          List.iter
            (fun (lifecycle, document_class, topic, content, target) ->
              let source =
                write_document root lifecycle document_class "2026-08-20" topic
                  content
              in
              let result = run ~cwd:root [ "transition"; source; target ] in
              check_failure ~status:2 result
                "Try: spec-dev-tool transition --help";
              check_path_content root source content)
            cases));

  test "transition validates target content before creating directories"
    (fun () ->
      with_temp_directory (fun root ->
          let source =
            write_document root "proposed" "feature" "2026-08-20"
              "invalid-target-content" "# Incomplete\n"
          in
          let result = run ~cwd:root [ "transition"; source; "implemented" ] in
          check_failure result "missing required section: Problem";
          check
            (contains result.stderr "missing required section: Decision")
            "expected every target validation error";
          check_path_content root source "# Incomplete\n";
          check_path_absent root "docs/agent-guide/implemented";
          let rejected_source =
            write_document root "proposed" "bugfix" "2026-08-20"
              "invalid-proposal" "# Incomplete\n"
          in
          let rejected_result =
            run ~cwd:root
              [
                "transition";
                rejected_source;
                "rejected";
                "--reason";
                "It cannot be completed.";
              ]
          in
          check_failure rejected_result "missing required section: Problem";
          check_path_content root rejected_source "# Incomplete\n";
          check_path_absent root "docs/agent-guide/rejected"));

  test "transition rejects invalid, missing, and non-regular source paths"
    (fun () ->
      with_temp_directory (fun root ->
          let relative_source =
            write_document root "proposed" "feature" "2026-08-20"
              "absolute-source" implemented_content
          in
          let absolute_source = Filename.concat root relative_source in
          let absolute_result =
            run ~cwd:root [ "transition"; absolute_source; "implemented" ]
          in
          check_failure absolute_result "project-relative";
          check_path_content root relative_source implemented_content;
          let noncanonical_source =
            "docs//agent-guide/proposed/feature/2026-08-20-absolute-source.md"
          in
          let noncanonical_result =
            run ~cwd:root [ "transition"; noncanonical_source; "implemented" ]
          in
          check_failure noncanonical_result "canonical project-relative";
          check_path_content root relative_source implemented_content;
          let missing =
            document_path "proposed" "feature" "2026-08-20" "missing"
          in
          run ~cwd:root [ "transition"; missing; "implemented" ]
          |> fun result ->
          check_failure result "cannot read document";
          let directory_source =
            document_path "proposed" "feature" "2026-08-20" "directory"
          in
          Unix.mkdir (Filename.concat root directory_source) 0o755;
          run ~cwd:root [ "transition"; directory_source; "implemented" ]
          |> fun result -> check_failure result "not a regular file"));

  test "transition never overwrites a destination and preserves the source"
    (fun () ->
      with_temp_directory (fun root ->
          let source =
            write_document root "proposed" "feature" "2026-08-20" "conflict"
              implemented_content
          in
          let destination =
            write_document root "implemented" "feature" "2026-08-20" "conflict"
              "existing destination\n"
          in
          let result = run ~cwd:root [ "transition"; source; "implemented" ] in
          check_failure result "destination already exists";
          check_path_content root source implemented_content;
          check_path_content root destination "existing destination\n"));

  test "transition leaves the source in place after destination write failures"
    (fun () ->
      with_temp_directory (fun root ->
          let source =
            write_document root "proposed" "feature" "2026-08-20"
              "directory-failure" implemented_content
          in
          let guide_root = Filename.concat root "docs/agent-guide" in
          Unix.chmod guide_root 0o555;
          Fun.protect
            ~finally:(fun () -> Unix.chmod guide_root 0o755)
            (fun () ->
              let result =
                run ~cwd:root [ "transition"; source; "implemented" ]
              in
              check_failure result "cannot move document";
              check_path_content root source implemented_content;
              check_path_absent root "docs/agent-guide/implemented");
          let blocked_source =
            write_document root "proposed" "feature" "2026-08-20"
              "write-failure" implemented_content
          in
          let destination_directory =
            Filename.concat root "docs/agent-guide/implemented/feature"
          in
          let rec create_directory path =
            if path = root || Sys.file_exists path then ()
            else (
              create_directory (Filename.dirname path);
              Unix.mkdir path 0o755)
          in
          create_directory destination_directory;
          Unix.chmod destination_directory 0o555;
          Fun.protect
            ~finally:(fun () -> Unix.chmod destination_directory 0o755)
            (fun () ->
              let result =
                run ~cwd:root [ "transition"; blocked_source; "implemented" ]
              in
              check_failure result "cannot move document";
              check_path_content root blocked_source implemented_content;
              check_path_absent root
                (document_path "implemented" "feature" "2026-08-20"
                   "write-failure"))));

  test "repository commands resolve the Git worktree root from nested paths"
    (fun () ->
      with_temp_directory (fun root ->
          let nested = Filename.concat root "src/nested" in
          let rec make_directory path =
            if path = root || Sys.file_exists path then ()
            else (
              make_directory (Filename.dirname path);
              Unix.mkdir path 0o755)
          in
          make_directory nested;
          let create_result =
            run ~cwd:nested [ "create"; "feature"; "nested-command" ]
          in
          check_success create_result;
          let created =
            Printf.sprintf
              "docs/agent-guide/exploring/feature/%s-nested-command.md"
              (current_date ())
          in
          check_path_content root created
            (read_file (Filename.concat root created));
          check_path_absent nested "docs";
          let nested_list = run ~cwd:nested [ "list-exploring" ] in
          let root_list = run ~cwd:root [ "list-exploring" ] in
          check_success nested_list;
          check
            (nested_list.stdout = root_list.stdout
            && nested_list.stdout = created ^ "\n")
            "nested and root list output differ";
          let nested_check = run ~cwd:nested [ "check"; created ] in
          let root_check = run ~cwd:root [ "check"; created ] in
          check_success nested_check;
          check
            (nested_check.stdout = root_check.stdout)
            "nested and root single-document check output differ";
          let nested_check_all = run ~cwd:nested [ "check"; "--all" ] in
          let root_check_all = run ~cwd:root [ "check"; "--all" ] in
          check_success nested_check_all;
          check
            (nested_check_all.stdout = root_check_all.stdout)
            "nested and root whole-repository check output differ";
          write_file (Filename.concat root created) (proposed_content ());
          let proposed =
            document_path "proposed" "feature" (current_date ())
              "nested-command"
          in
          let propose_result =
            run ~cwd:nested [ "transition"; created; "proposed" ]
          in
          check_success propose_result;
          check_path_absent root created;
          check_path_content root proposed (proposed_content ());
          write_file (Filename.concat root proposed) implemented_content;
          let destination =
            document_path "implemented" "feature" (current_date ())
              "nested-command"
          in
          let transition_result =
            run ~cwd:nested [ "transition"; proposed; "implemented" ]
          in
          check_success transition_result;
          check
            (transition_result.stdout = destination ^ "\n")
            "nested transition did not print the canonical destination";
          check_path_absent root proposed;
          check_path_content root destination implemented_content;
          check_path_absent nested "docs"));

  test "root discovery failures are actionable and never modify documents"
    (fun () ->
      with_non_git_temp_directory (fun root ->
          let source =
            write_document root "proposed" "feature" "2026-08-20" "untouched"
              implemented_content
          in
          let before =
            Sys.readdir root |> Array.to_list |> List.sort String.compare
          in
          [
            [ "create"; "feature"; "must-not-exist" ];
            [ "list-exploring" ];
            [ "check"; source ];
            [ "check"; "--all" ];
            [ "transition"; source; "implemented" ];
          ]
          |> List.iter (fun arguments ->
              let result = run ~cwd:root arguments in
              check_failure result "Cannot locate project root";
              check
                (not (contains result.stderr "Try: spec-dev-tool"))
                "operation failure unexpectedly included help guidance";
              check
                (Sys.readdir root |> Array.to_list |> List.sort String.compare
               = before)
                "root discovery failure changed the filesystem";
              check_path_content root source implemented_content;
              check_path_absent root "docs/agent-guide/implemented"));
      with_temp_directory (fun root ->
          let result =
            run ~path:"" ~cwd:root [ "create"; "feature"; "missing-git" ]
          in
          check_failure result "Cannot locate project root";
          check_path_absent root "docs");
      with_non_git_temp_directory (fun root ->
          let fake_bin = Filename.concat root "bin" in
          Unix.mkdir fake_bin 0o755;
          let fake_git = Filename.concat fake_bin "git" in
          write_file fake_git
            "#!/bin/sh\nprintf '/first-root\\n/second-root\\n'\n";
          Unix.chmod fake_git 0o755;
          let result =
            run ~path:fake_bin ~cwd:root
              [ "create"; "feature"; "invalid-git-output" ]
          in
          check_failure result "Cannot locate project root";
          check_path_absent root "docs"));

  test "all help forms provide ordered agent-oriented guidance without Git"
    (fun () ->
      with_non_git_temp_directory (fun root ->
          let fake_bin = Filename.concat root "bin" in
          Unix.mkdir fake_bin 0o755;
          let fake_git = Filename.concat fake_bin "git" in
          write_file fake_git
            "#!/bin/sh\n: > git-was-run\nprintf '%s\\n' \"$PWD\"\n";
          Unix.chmod fake_git 0o755;
          let top_help flag = run ~path:fake_bin ~cwd:root [ flag ] in
          let long_top = top_help "--help" in
          let short_top = top_help "-h" in
          check_success long_top;
          check
            (long_top.stdout = short_top.stdout && long_top.stderr = "")
            "top-level help aliases differ or wrote to stderr";
          [
            "spec-dev-tool manages agent decision documents";
            "AGENT WORKFLOW";
            "COMMANDS";
            "VALUES";
            "simplification | bugfix | feature | testing | architecture | \
             process";
            "exploring | proposed | implemented | rejected | archived";
            "Ask the user to answer every question in the document.";
            "Do not implement a document while its lifecycle is exploring.";
            "list-exploring";
            "list-proposed";
            "list-implemented";
            "list-rejected";
            "list-archived";
            "EXIT STATUS";
            "0  Command completed successfully.";
            "1  Document validation or filesystem operation failed.";
            "2  Command arguments are invalid.";
          ]
          |> List.iter (fun text ->
              check
                (contains long_top.stdout text)
                ("missing top-level help: " ^ text));
          check_before long_top.stdout "AGENT WORKFLOW" "COMMANDS";
          check_before long_top.stdout "spec-dev-tool create <class> <doc-name>"
            "Ask the user to answer every question in the document.";
          check_before long_top.stdout
            "Do not implement a document while its lifecycle is exploring."
            "spec-dev-tool transition <doc-path> proposed";
          check_before long_top.stdout "COMMANDS" "VALUES";
          check_before long_top.stdout "VALUES" "EXIT STATUS";
          let cases =
            [
              ( "create",
                [
                  "Create an exploring agent document";
                  "spec-dev-tool create <class> <doc-name>";
                  "Ask the user to answer every question in the document.";
                  "Do not implement a document while its lifecycle is \
                   exploring.";
                  "<doc-name> must be lowercase kebab-case.";
                  "spec-dev-tool check <created-path>";
                ] );
              ( "list-exploring",
                [
                  "List recent exploring agent documents, newest first.";
                  "spec-dev-tool list-exploring [<days>]";
                  "<days> defaults to 30";
                  "An empty result produces no output and is successful.";
                ] );
              ( "list-proposed",
                [
                  "List recent proposed agent documents, newest first.";
                  "spec-dev-tool list-proposed [<days>]";
                  "<days> defaults to 30";
                ] );
              ( "list-implemented",
                [
                  "List recent implemented agent documents, newest first.";
                  "spec-dev-tool list-implemented [<days>]";
                  "<days> defaults to 30";
                ] );
              ( "list-rejected",
                [
                  "List recent rejected agent documents, newest first.";
                  "spec-dev-tool list-rejected [<days>]";
                  "<days> defaults to 30";
                ] );
              ( "list-archived",
                [
                  "List recent archived agent documents, newest first.";
                  "spec-dev-tool list-archived [<days>]";
                  "<days> defaults to 30";
                ] );
              ( "check",
                [
                  "Validate agent document paths";
                  "spec-dev-tool check <doc-path>";
                  "spec-dev-tool check --all";
                  "Validation failures are written to stderr and exit with \
                   status 1.";
                ] );
              ( "transition",
                [
                  "Record a decision outcome";
                  "exploring   -> proposed";
                  "exploring   -> rejected";
                  "An exploring document may transition only after the user \
                   has answered every question.";
                  "Do not implement a document while its lifecycle is \
                   exploring.";
                  "proposed    -> implemented";
                  "proposed    -> rejected";
                  "implemented -> archived";
                  "Rewrite a proposal to implemented format";
                  "A rejection reason is required, non-empty, and single-line.";
                  "spec-dev-tool check <destination-path>";
                ] );
            ]
          in
          List.iter
            (fun (command, expected) ->
              let long = run ~path:fake_bin ~cwd:root [ command; "--help" ] in
              let short = run ~path:fake_bin ~cwd:root [ command; "-h" ] in
              check_success long;
              check
                (long.stdout = short.stdout && long.stderr = "")
                (command ^ " help aliases differ or wrote to stderr");
              [ "PURPOSE"; "WHEN TO USE"; "USAGE" ]
              |> List.iter (fun section ->
                  check
                    (contains long.stdout section)
                    (command ^ " help is missing " ^ section));
              check
                (contains long.stdout "ARGUMENTS"
                || contains long.stdout "CONSTRAINTS")
                (command ^ " help is missing arguments or constraints");
              check_before long.stdout "PURPOSE" "WHEN TO USE";
              check_before long.stdout "WHEN TO USE" "USAGE";
              check_before long.stdout "USAGE"
                (if contains long.stdout "ARGUMENTS" then "ARGUMENTS"
                 else "CONSTRAINTS");
              check_before long.stdout
                (if contains long.stdout "ARGUMENTS" then "ARGUMENTS"
                 else "CONSTRAINTS")
                "OUTPUT";
              check_before long.stdout "OUTPUT" "NEXT STEP";
              List.iter
                (fun text ->
                  check
                    (contains long.stdout text)
                    (Printf.sprintf "%s help is missing %S" command text))
                expected)
            cases;
          check_path_absent root "git-was-run";
          check_path_absent root "docs"));

  test "usage errors provide specific targeted recovery guidance" (fun () ->
      with_non_git_temp_directory (fun root ->
          let known_cases =
            [
              ([ "create"; "feature" ], "create");
              ([ "create"; "refactor"; "decision" ], "create");
              ([ "list-proposed"; "0" ], "list-proposed");
              ([ "check" ], "check");
              ([ "check"; "--all"; "extra" ], "check");
              ([ "transition"; "path" ], "transition");
              ([ "transition"; "path"; "rejected" ], "transition");
            ]
          in
          List.iter
            (fun (arguments, command) ->
              let result = run ~cwd:root arguments in
              check_failure ~status:2 result "Error:";
              check
                (contains result.stderr
                   ("Try: spec-dev-tool " ^ command ^ " --help"))
                ("missing targeted guidance for " ^ command);
              check (result.stdout = "") "usage error wrote to stdout";
              check
                (not (contains result.stderr "AGENT WORKFLOW"))
                "usage error appended complete top-level help")
            known_cases;
          [ []; [ "inspect" ]; [ "validate"; "some-path" ] ]
          |> List.iter (fun arguments ->
              let result = run ~cwd:root arguments in
              check_failure ~status:2 result "Try: spec-dev-tool --help";
              check (result.stdout = "") "unknown command wrote to stdout";
              check
                (not (contains result.stderr "AGENT WORKFLOW"))
                "unknown command appended complete top-level help");
          let inspect = run ~cwd:root [ "inspect" ] in
          check
            (contains inspect.stderr "unknown command: inspect")
            "unknown command error omitted the command value"));

  if !failures > 0 then (
    Printf.eprintf "\n%d test(s) failed\n%!" !failures;
    exit 1)
