type t = { content : string; created : bool }

val relative_path : string
val prepare : Agent_doc.project_root -> (t, string) result
