(lang dune 3.23)

(name spec_dev_tool)

(generate_opam_files true)

(package
 (name spec_dev_tool)
 (synopsis "CLI tools for agent-assisted software development")
 (maintainers "spec_dev_tool maintainers")
 (authors "spec_dev_tool contributors")
 (depends
  (ocaml (>= 5.1))
  (dune (>= 3.23))))
