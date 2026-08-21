type lifecycle = Exploring | Proposed | Implemented | Rejected | Archived

type document_class =
  | Simplification
  | Bugfix
  | Feature
  | Testing
  | Architecture
  | Process

type transition_error = Usage_error of string | Operation_error of string list
type project_root
type transition_request

val document_class_of_string : string -> (document_class, string) result
val lifecycle_of_string : string -> (lifecycle, string) result
val is_topic_name : string -> bool
val resolve_project_root : unit -> (project_root, string) result
val check : project_root -> string -> (unit, string list) result

val check_all :
  project_root -> ((string * (unit, string list) result) list, string) result

val create : project_root -> document_class -> string -> (string, string) result

val list_documents :
  project_root -> lifecycle -> int -> (string list, string) result

val prepare_transition :
  string ->
  lifecycle ->
  reason:string option ->
  (transition_request, transition_error) result

val transition :
  project_root -> transition_request -> (string, transition_error) result
