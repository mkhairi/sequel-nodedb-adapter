# sequel-nodedb-adapter — project rules

Workspace-wide rules (branch/PR workflow, upstream-bug lifecycle,
versioning, release checklist, "what to never do") live in the monorepo
root: `../../CLAUDE.md`. **Read that first.** Anything below adds or
overrides for this gem only.

## Project

Sequel adapter for NodeDB. Registers the `:nodedb` scheme. Delegates
connection / execution to `NodeDB::Connection` and schema introspection
to NodeDB's `DESCRIBE`. Sits on top of `nodedb-ruby`.

Dataset CRUD, DDL helpers (`create_collection`, `create_vector_index`),
and engine helpers (`search_vector`, `graph_stats`) work at the
`Database` level. Sequel model plugins and TypeMap result casting are
roadmap. New NodeDB features land first in
`activerecord-nodedb-adapter`, then mirror here.

Status: **alpha** (`0.1.0.alpha.N`).

## Tests

```bash
bundle exec rspec
```

Requires a live NodeDB on `localhost:6432` (integration specs skip if
unreachable). 8 examples; must stay 0 failures before any PR merges.
New behaviour requires a spec.

## Release checklist additions

Standard alpha release flow lives in `../../CLAUDE.md`. The version
file for this gem is `lib/sequel/adapters/nodedb/version.rb`.

## License

BSD 2-Clause. See `LICENSE.md`.
