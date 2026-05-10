# sequel-nodedb-adapter — project rules

Workspace-wide rules (branch/PR workflow, upstream-bug lifecycle,
versioning, release checklist, "what to never do") live in the monorepo
root: `../../CLAUDE.md`. **Read that first.** Anything below adds or
overrides for this gem only.

## Project

Sequel adapter for NodeDB. Registers the `:nodedb` scheme. Delegates
connection / execution to `NodeDB::Connection` and schema introspection
to NodeDB's `DESCRIBE`. Sits on top of `nodedb-ruby`.

**Stub status:** Sequel-native DSL for vector / graph / timeseries is
not yet wired in. New NodeDB features land first in
`activerecord-nodedb-adapter`, then mirror here.

Status: **alpha / stub** (`0.1.0.alpha.N`).

## Tests

This gem has **no test suite yet**. Adding one (Sequel `spec_model` +
integration smoke against live NodeDB) is on the roadmap. Until then,
every PR must include a manual reproduction recipe in the PR body that
demonstrates the change against a running NodeDB.

## Release checklist additions

Standard alpha release flow lives in `../../CLAUDE.md`. The version
file for this gem is `lib/sequel/adapters/nodedb/version.rb`.

## License

BSD 2-Clause. See `LICENSE.md`.
