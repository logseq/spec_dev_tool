# spec-dev-tool

`spec-dev-tool` is an OCaml CLI for managing agent decision documents in
`docs/agent-guide/`. It creates, lists, validates, and transitions documents
through their lifecycle.

## Install

Requirements: OCaml 5.1 or newer, Dune 3.23 or newer, opam, and Git.

The following example creates a local OCaml 5.1.1 switch. Any newer OCaml
version is also supported.

```sh
opam switch create . 5.1.1
eval "$(opam env)"
opam install .
```

Verify the installation:

```sh
spec-dev-tool --help
```

Repository commands work from any directory inside a Git worktree. Run the
top-level help and follow its `AGENT WORKFLOW` for command guidance.

## Development

```sh
dune build @all
dune runtest
dune exec -- spec-dev-tool --help
```
